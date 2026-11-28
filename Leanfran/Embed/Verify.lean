import Leanfran.Embed.Sync

open Lean System

namespace Leanfran.Embed.Verify

def lockName := "leanfran.lock"

private def obligationJson (o : LockObligation) : Doc :=
  .obj <| [("label", .json (toJson o.label)), ("status", .json (toJson o.status))] ++
    (if o.detail.isEmpty then [] else [("detail", .json (toJson o.detail))]) ++
    (if o.axioms.isEmpty then [] else [("axioms", .json (toJson o.axioms))]) ++
    (if o.file.isEmpty then [] else [("file", .json (toJson o.file)), ("line", .json (toJson o.line))])

private def obligationOf (j : Json) : Except String LockObligation := do
  return {
    label := ← j.getObjValAs? String "label", status := ← j.getObjValAs? String "status"
    detail := (j.getObjValAs? String "detail").toOption.getD ""
    axioms := (j.getObjValAs? (Array String) "axioms").toOption.getD #[]
    file := (j.getObjValAs? String "file").toOption.getD ""
    line := (j.getObjValAs? Nat "line").toOption.getD 0}

private def sectionDoc (s : LockSection) : Doc :=
  .obj [
    ("inputs", .obj [("compiler", .json (toJson s.inputs.compiler)), ("library", .json (toJson s.inputs.library)),
      ("host", .json (toJson s.inputs.host)), ("proofs", .json (toJson s.inputs.proofs))]),
    ("functions", .arr (s.functions.map fun f => .obj [("id", .json (toJson f.id)), ("hash", .json (toJson f.hash)),
      ("model", .json (toJson f.model)), ("dependencies", .json (toJson f.dependencies)),
      ("obligations", .arr (f.obligations.map obligationJson)), ("data", .json f.data)]))]

private def sectionOf (j : Json) : Except String LockSection := do
  let inputs ← j.getObjVal? "inputs"
  let functions ← (← j.getObjValAs? (Array Json) "functions").mapM fun f => do
    return ({
      id := ← f.getObjValAs? String "id", hash := ← f.getObjValAs? String "hash"
      model := ← f.getObjValAs? String "model"
      dependencies := (f.getObjValAs? (Array String) "dependencies").toOption.getD #[]
      obligations := ← (← f.getObjValAs? (Array Json) "obligations").mapM obligationOf
      data := (f.getObjVal? "data").toOption.getD (Json.mkObj [])} : LockFunction)
  return {
    inputs := {
      compiler := ← inputs.getObjValAs? String "compiler", library := ← inputs.getObjValAs? String "library"
      host := ← inputs.getObjValAs? String "host", proofs := ← inputs.getObjValAs? String "proofs"}
    functions}

structure Lock where
  languages : Array (String × Json) := #[]
  deriving Inhabited

def Lock.section? (lock : Lock) (lang : String) : Option LockSection :=
  (lock.languages.find? (·.1 == lang)).bind fun (_, j) => (sectionOf j).toOption

def readLock (root : FilePath) (lang : String) : IO (Except Failure Lock) := do
  let .ok text ← (IO.FS.readFile (root / lockName)).toBaseIO | return .ok {}
  let .ok json := Json.parse text
    | return .error (.content s!"{lockName} is not a lock of leanfran --lang {lang}")
  unless (json.getObjValAs? String "format").toOption == some "leanfran-lock" do return .ok {}
  let .ok languages := json.getObjVal? "languages" | return .ok {}
  return .ok {languages := objFields languages}

def writeLock (root : FilePath) (lock : Lock) (lang : String) (s : Option LockSection) : IO Unit := do
  let others := lock.languages.filter (·.1 != lang) |>.map fun (k, v) => (k, Doc.ofJson v)
  let mine := match s with
    | some s => #[(lang, sectionDoc s)]
    | none => #[]
  let languages := (others ++ mine).qsort (·.1 < ·.1)
  IO.FS.writeFile (root / lockName) (Doc.render (.obj [("format", .json (toJson "leanfran-lock")),
    ("version", .json (toJson (2 : Nat))), ("languages", .obj languages.toList)]) ++ "\n")

def proofSources (root : FilePath) : IO (Except Failure (Array (String × String × String))) := do
  let dir := root / "lean" / "Proofs"
  unless ← dir.isDir do return .ok #[]
  let mut result := #[]
  for path in (← dir.walkDir).qsort (·.toString < ·.toString) do
    unless path.extension == some "lean" && !(← path.isDir) do continue
    let some rel := relativeTo dir path | continue
    let parts := (rel.dropEnd ".lean".length).toString.splitOn "/"
    unless parts.all fun p => !p.isEmpty && p.toList.all fun c => c.isAlphanum || c == '_' do
      return .error (.content s!"lean/Proofs/{rel}: invalid proof module name")
    result := result.push ("Proofs." ++ ".".intercalate parts, s!"lean/Proofs/{rel}", ← IO.FS.readFile path)
  return .ok result

def inputs (backend : Backend) (scan : Scan) (proofs : Array (String × String × String)) : IO LockInputs := do
  return {
    compiler := backend.compiler, library := ← Sync.filesHash backend.supportFiles, host := scan.proofInputs
    proofs := ← sha256 (Json.compress (toJson (proofs.map fun (_, path, text) => (path, text))))}

def row (id label status : String) : String := s!"{id} [{label}]: {status}"

structure FunctionStatus where
  rows : Array String := #[]
  stale : Bool := false
  proved : Bool := true

def functionStatus (backend : Backend) (root : FilePath) (scan : Scan) (lock : Lock) :
    IO (Except Failure FunctionStatus) := do
  let s := lock.section? backend.lang
  let saved := (s.map (·.functions)).getD #[]
  if let some error := scan.functionsError then
    let place ← display root error.file
    IO.eprintln (if error.file.isEmpty then error.message
      else s!"{place}:{error.line}:{error.column}: {error.message}")
    let rows := saved.flatMap fun f => f.obligations.map fun o => row f.id o.label "stale"
    return .ok {rows, stale := true, proved := false}
  if scan.functions.isEmpty && s.isNone then return .ok {}
  let proofs ← match ← proofSources root with
    | .ok proofs => pure proofs
    | .error failure => return .error failure
  let current ← inputs backend scan proofs
  let byId : Std.HashMap String LockFunction := .ofList (saved.toList.map fun f => (f.id, f))
  let functions : Std.HashMap String Function := .ofList (scan.functions.toList.map fun f => (f.id, f))
  let sameInputs := s.any (·.inputs == current)
  let rec fresh (fuel : Nat) (id : String) : Bool :=
    match fuel with
    | 0 => false
    | fuel + 1 => Id.run do
      let some f := functions[id]? | return false
      let some l := byId[id]? | return false
      return l.hash == f.hash && (l.obligations.map (·.label)).qsort (· < ·) == f.labels.qsort (· < ·) &&
        l.dependencies.all (fresh fuel)
  let mut result : FunctionStatus := {}
  for f in scan.functions.qsort (·.id < ·.id) do
    let ok := sameInputs && fresh (scan.functions.size + 1) f.id
    for label in f.labels.qsort (· < ·) do
      let status := if ok then
          ((byId[f.id]?.bind fun l => l.obligations.find? (·.label == label)).map (·.status)).getD "stale"
        else "stale"
      if status == "stale" then result := {result with stale := true}
      if status != "proved" then result := {result with proved := false}
      result := {result with rows := result.rows.push (row f.id label status)}
  for f in saved.qsort (·.id < ·.id) do
    unless functions.contains f.id do
      result := {result with rows := result.rows.push s!"{f.id}: removed", stale := true}
  return .ok result

private def imports (text : String) : Array String :=
  (text.splitOn "\n").toArray.filterMap fun line =>
    if line.startsWith "import " then some (line.drop "import ".length).trimAscii.toString else none

private def removeTree (path : FilePath) : IO Unit := do
  if ← path.pathExists then IO.FS.removeDirAll path

private def lakeIn (ctx : Context) (dir : FilePath) (args : Array String) : IO (UInt32 × String) := do
  let result ← IO.Process.output {cmd := ctx.lake, cwd := some dir, args := #["--no-ansi"] ++ args}
  return (result.exitCode, result.stdout ++ result.stderr)

private def proofOutput (dir : FilePath) (relative : String) (output : String) : String :=
  let output := output.replace s!"{dir}/Proofs/" "lean/Proofs/"
  let output := if relative == "." then output else output.replace s!"{relative}/Proofs/" "lean/Proofs/"
  (output.replace "Proofs/" "lean/Proofs/").replace "lean/lean/Proofs/" "lean/Proofs/"

structure Outcome where
  code : UInt32
  section? : Option LockSection

def obligations (backend : Backend) (ctx : Context) (state : backend.State) (scan : Scan) (synced : Sync.Result)
    (require : Bool) : ExceptT Failure IO Outcome := do
  if scan.functions.isEmpty then
    return {code := 0, section? := none}
  let blocks := synced.generated.filterMap fun g => do
    let block ← scan.blocks.find? (·.name == g.block)
    let files := ((synced.blockFiles.find? (·.1 == g.block)).map (·.2)).getD #[]
    return (g.block, ({module := block.module, files, summary := g.summary} : TranslateBlock))
  let translation ← Sync.ofIO (backend.translate ctx state {workspace := ctx.workspace, scan, blocks})
  let proofs ← Sync.ofIO (proofSources ctx.root)
  let dir := ctx.workspace / backend.verificationDir
  let vd := backend.verificationDir.toString
  let tops := (translation.modules ++ translation.aggregates).filterMap fun m =>
    let relative := if vd == "." then m.path else (relativeTo ⟨vd⟩ ⟨m.path⟩).getD m.path
    (relative.splitOn "/").head?
  for top in tops.toList.eraseDups ++ ["Proofs"] do
    let build := ctx.workspace / ".lake" / "build"
    for path in [dir / top, build / "lib" / "lean" / top, build / "ir" / top] do
      removeTree path
  for (mod, _, text) in proofs do
    discard <| writeChanged (dir / FilePath.mk ("/".intercalate (mod.splitOn ".") ++ ".lean")) text
  for m in translation.modules do
    discard <| writeChanged (ctx.workspace / m.path) m.text
  let mut built : Std.HashSet String := {}
  let mut failed : Std.HashSet String := {}
  if !translation.modules.isEmpty then
    let (code, _) ← lakeIn ctx ctx.workspace (#["build"] ++ translation.modules.map (s!"+{·.module}"))
    if code == 0 then
      built := .ofList (translation.modules.toList.map (·.module))
    else
      for m in translation.modules do
        if (imports m.text).any failed.contains then
          failed := failed.insert m.module
          continue
        let (code, output) ← lakeIn ctx ctx.workspace #["build", s!"+{m.module}"]
        if code == 0 then built := built.insert m.module
        else
          IO.eprint output
          failed := failed.insert m.module
  let functions : Std.HashMap String Function := .ofList (scan.functions.toList.map fun f => (f.id, f))
  let translated : Std.HashMap String TranslatedFunction :=
    .ofList (translation.functions.toList.map fun f => (f.id, f))
  let mut errors : Std.HashMap String SourceError := {}
  for f in scan.functions do
    match translated[f.id]? with
    | none => errors := errors.insert f.id {f.origin with message := "not translated"}
    | some t =>
      if let some error := t.error then errors := errors.insert f.id error
  for m in translation.modules do
    unless failed.contains m.module do continue
    for id in m.functions do
      unless errors.contains id do
        if let some f := functions[id]? then
          errors := errors.insert id {f.origin with message := "could not elaborate the translated definition or its obligations"}
  let mut grew := true
  while grew do
    grew := false
    for t in translation.functions do
      if errors.contains t.id then continue
      if t.dependencies.any errors.contains then
        if let some f := functions[t.id]? then
          errors := errors.insert t.id {f.origin with message := "could not elaborate the translated definition or its obligations"}
          grew := true
  let mut verified := #[]
  for a in translation.aggregates do
    let lines := (a.text.splitOn "\n").filter fun line =>
      !line.startsWith "import " || built.contains (line.drop "import ".length).trimAscii.toString
    unless lines.any (·.startsWith "import ") do continue
    discard <| writeChanged (ctx.workspace / a.path) ("\n".intercalate lines)
    let (code, output) ← lakeIn ctx ctx.workspace #["build", s!"+{a.module}"]
    if code != 0 then
      IO.eprint output
      throw (.content s!"could not build {a.module}")
    built := built.insert a.module
    verified := verified.push a.module
  let outputs : Std.HashSet String := .ofList ((translation.modules ++ translation.aggregates).toList.map (·.module))
  let proofImports : Std.HashMap String (Array String) := .ofList (proofs.toList.map fun (m, _, t) => (m, imports t))
  let reaches := fun (mod : String) => Id.run do
    let mut pending := #[mod]
    let mut seen : Std.HashSet String := {}
    let mut found := #[]
    while let some next := pending.back? do
      pending := pending.pop
      if seen.contains next then continue
      seen := seen.insert next
      if outputs.contains next then found := found.push next
      pending := pending ++ (proofImports[next]?.getD #[])
    return found
  let mut failedSources := #[]
  for (mod, _, text) in proofs do
    let targets := reaches mod
    if !targets.isEmpty && !targets.any built.contains then
      failedSources := failedSources.push text
      continue
    let (code, output) ← lakeIn ctx ctx.workspace #["build", s!"+{mod}"]
    if code != 0 then
      IO.eprint (proofOutput dir vd output)
      failedSources := failedSources.push text
    else verified := verified.push mod
  let mut results : Std.HashMap (String × String) LockObligation := {}
  let refs := scan.functions.filter (!errors.contains ·.id) |>.flatMap fun f =>
    let model := (translated[f.id]?.map (·.model)).getD ""
    f.labels.map fun label => (f.id, model, label)
  if !refs.isEmpty then
    let request := ctx.workspace / "obligations.json"
    IO.FS.writeFile request (Json.compress (Json.arr (refs.map fun (_, model, label) =>
      Json.mkObj [("model", toJson model), ("label", toJson label)])))
    let args := #["env", ctx.app.toString, "--lang", ctx.lang, "obligations", "check", "--modules"] ++ verified ++
      #["--obligations", request.toString]
    let output ← IO.Process.output {cmd := ctx.lake, cwd := some ctx.workspace, args}
    unless output.exitCode == 0 do
      throw (.environment s!"{output.stderr}leanfran --lang {ctx.lang} obligations check exited with {output.exitCode}")
    let checked ← match Json.parse output.stdout >>= (·.getArr?) with
      | .ok checked => pure checked
      | .error _ => throw (.environment s!"invalid obligations check response: {output.stdout}")
    unless checked.size == refs.size do throw (.environment s!"invalid obligations check response: {output.stdout}")
    for ((id, model, _), j) in refs.zip checked do
      let o ← Sync.ofExcept (obligationOf j |>.mapError Failure.environment)
      let o := if o.file.startsWith "Proofs/" then {o with file := "lean/" ++ o.file} else o
      if ["failed", "unextracted", "mismatch"].contains o.status && !o.detail.isEmpty then
        IO.eprintln s!"error: {o.file}{if o.line == 0 then "" else s!":{o.line}"}: {o.detail}"
      let fn := (model.splitOn ".").getLast!
      let proof := s!"{fn}.proof.{o.label}"
      let isFailed := o.status == "missing" &&
        failedSources.any fun s => ((s.replace "«" "").replace "»" "").contains proof
      results := results.insert (id, o.label) (if isFailed then {o with status := "failed"} else o)
  let mut entries := #[]
  let mut code : UInt32 := 0
  let mut rows := #[]
  for f in scan.functions.qsort (·.id < ·.id) do
    let t := translated[f.id]?
    let error := errors[f.id]?
    if let some e := error then
      IO.eprintln s!"{← display ctx.root e.file}:{e.line}:{e.column}: unextracted {f.id}: {e.message}"
    let mut obligations := #[]
    for label in f.labels.qsort (· < ·) do
      let o : LockObligation := match error with
        | some e => {label, status := "unextracted", detail := s!"{e.file}:{e.line}:{e.column}: {e.message}"}
        | none => (results[(f.id, label)]?).getD {label, status := "missing"}
      if o.status == "unextracted" || o.status == "failed" || (require && o.status != "proved") then code := 1
      rows := rows.push (row f.id label o.status)
      obligations := obligations.push o
    entries := entries.push ({
      id := f.id, hash := f.hash, model := (t.map (·.model)).getD ""
      dependencies := (t.map (·.dependencies)).getD #[], obligations
      data := (t.map (·.data)).getD (Json.mkObj [])} : LockFunction)
  for line in rows do IO.println line
  if code != 0 then IO.eprintln "obligations did not pass check"
  return {code, section? := some {inputs := ← inputs backend scan proofs, functions := entries}}

end Leanfran.Embed.Verify
