import LeanC.Verify.Translate
import LeanC.Embed.Scan

open Lean System
open LeanC.ClangAst
open LeanC.Verify (leanIdent)

namespace LeanC.Embed

def lockName := "leanfran.lock"
def cLibSource : String := include_str "../../lean/LeanCLib/C.lean"
private def supportHeader := include_str "../../support/leanfran.h"

def releaseVersion : String :=
  ((supportHeader.splitOn "#define LEANFRAN_VERSION \"")[1]!.splitOn "\"").head!

def sha256 (text : String) : IO String := do
  let args : IO.Process.SpawnArgs := if Platform.isOSX then
    {cmd := "shasum", args := #["-a", "256"]}
  else {cmd := "sha256sum"}
  let output ← IO.Process.run args (some text)
  return (output.splitOn " ").head!

structure ModelCheck where
  label : String
  predicate : String

structure ModelFunction where
  name : String
  block : String
  file : FilePath
  line : Nat
  column : Nat
  requires : Option String := none
  checks : Array ModelCheck := #[]
  hash : String := ""
  error : Option String := none
  closure : Array Verify.Function := #[]
  callees : Std.HashMap String (Array String) := {}
  declaration : Bool := false
  isStatic : Bool := false
  scope : String := ""
  fileScoped : Array String := #[]

def fileIdent (path : FilePath) : String :=
  "File_" ++ String.join (path.toString.toList.map fun c =>
    if c.isAlphanum then c.toString
    else match c with
      | '_' => "__"
      | '/' => "_s"
      | '.' => "_d"
      | '-' => "_h"
      | c => s!"_x{String.ofList (Nat.toDigits 16 c.toNat)}_")

def ModelFunction.model (m : ModelFunction) : String :=
  if m.block.isEmpty then s!"LeanCModel.{m.name}"
  else if m.scope.isEmpty then s!"LeanCModel.{m.block}.{m.name}"
  else s!"LeanCModel.{m.block}.{m.scope}.{m.name}"

def ModelFunction.labels (m : ModelFunction) : Array String :=
  if m.checks.isEmpty then #["model"] else m.checks.map (·.label)

structure Obligation where
  model : String
  label : String
  status : String
  detail : String := ""
  axioms : Array String := #[]
  file : String := ""
  line : Nat := 0

private def Obligation.toJson (o : Obligation) : Json :=
  Json.mkObj <| [("model", Lean.toJson o.model), ("label", Lean.toJson o.label), ("status", Lean.toJson o.status)] ++
    (if o.detail.isEmpty then [] else [("detail", Lean.toJson o.detail)]) ++
    (if o.axioms.isEmpty then [] else [("axioms", Lean.toJson o.axioms)]) ++
    (if o.file.isEmpty then [] else [("file", Lean.toJson o.file), ("line", Lean.toJson o.line)])

private def Obligation.fromJson (j : Json) : Except String Obligation := do
  let model ← j.getObjValAs? String "model"
  let label ← j.getObjValAs? String "label"
  let status ← j.getObjValAs? String "status"
  return {
    model, label, status
    detail := (j.getObjValAs? String "detail").toOption.getD ""
    axioms := (j.getObjValAs? (Array String) "axioms").toOption.getD #[]
    file := (j.getObjValAs? String "file").toOption.getD ""
    line := (j.getObjValAs? Nat "line").toOption.getD 0 }

private def displayName (model : String) : String :=
  (model.drop "LeanCModel.".length).toString

def Obligation.report (o : Obligation) : String :=
  s!"{displayName o.model} [{o.label}]: {o.status}"

private def annotation (attr : Node) : Option (Array String) := do
  guard (attr.kind == "AnnotateAttr")
  attr.children.mapM fun expr => do
    let literal ← expr.walk.find? (·.kind == "StringLiteral")
    let .ok (.str value) := Json.parse (literal.string "value") | none
    return value

private def annotations (node : Node) (kind : String) : Array (Array String) :=
  node.children.filterMap fun attr => do
    let args ← annotation attr
    guard (args[0]? == some kind)
    return args.extract 1 args.size

private partial def normalize : Json → Json
  | .obj fields => .obj <| fields.foldl (init := {}) fun acc key value =>
    if ["loc", "range", "isUsed", "isReferenced"].contains key then acc
    else match value with
      | .str text => if text.startsWith "0x" then acc else acc.insert key value
      | value => acc.insert key (normalize value)
  | .arr items => .arr (items.map normalize)
  | json => json

private def lineOf (source : ByteArray) (offset : Nat) : Nat :=
  1 + (source.extract 0 offset).data.countP (· == 10)

private def validLabel (label : String) : Bool :=
  cIdentifier label && label.toList.all (fun c => c.toNat < 128)

private def validName (name : String) : Bool :=
  !name.isEmpty && (name.splitOn ".").all validLabel

private def parseModel (args : Array String) : Except String (Option String × Option String × Array ModelCheck) := do
  let mut spec := none
  let mut requires := none
  let mut checks : Array ModelCheck := #[]
  for arg in args do
    let key :: rest := arg.splitOn "=" | throw s!"expected LF_MODEL(\"key=value\"), got '{arg}'"
    let value := "=".intercalate rest
    if rest.isEmpty || value.isEmpty then throw s!"expected LF_MODEL(\"key=value\"), got '{arg}'"
    match key with
    | "spec" =>
      if spec.isSome then throw "duplicate spec= in LF_MODEL"
      spec := some value
    | "requires" =>
      if requires.isSome then throw "duplicate requires= in LF_MODEL"
      unless validName value do throw s!"invalid Lean name '{value}' in requires="
      requires := some value
    | "refines" =>
      unless validName value do throw s!"invalid Lean name '{value}' in refines="
      checks := checks.push {label := "refines", predicate := value}
    | "ensures" =>
      let [label, predicate] := value.splitOn ":" | throw s!"expected ensures=<label>:<name>, got '{arg}'"
      unless validLabel label do throw s!"invalid ensures label '{label}'"
      unless validName predicate do throw s!"invalid Lean name '{predicate}' in ensures="
      checks := checks.push {label, predicate}
    | _ => throw s!"unknown LF_MODEL key '{key}'"
  if checks.isEmpty then throw "LF_MODEL requires refines= or ensures="
  for (check, i) in checks.zipIdx do
    if checks.extract 0 i |>.any (·.label == check.label) then
      throw s!"duplicate LF_MODEL obligation '{check.label}'"
  return (spec, requires, checks)

private def commandFor (db : Array CompileCommand) (config : Config) (root path : FilePath)
    (extra : Array String) : IO CompileCommand := do
  if let some command := db.find? (·.file == path) then return command
  if path.extension == some "h" then
    for candidate in db do
      if (← dependencies candidate extra).contains path then
        return {candidate with file := path}
  return {directory := root, file := path, flags := config.cflags}

private def blockClosure (blocks : Array Block) (name : String) : Array Block := Id.run do
  let mut pending := #[name]
  let mut seen : Std.HashSet String := {}
  let mut result := #[]
  while let some next := pending.back? do
    pending := pending.pop
    if seen.contains next then continue
    seen := seen.insert next
    let some block := blocks.find? (·.name == next) | continue
    result := result.push block
    pending := pending ++ block.imports
  return result.qsort (·.name < ·.name)

private partial def calleeClosure (byName : Std.HashMap String Node) (name : String)
    (seen : Std.HashSet String) : Std.HashSet String :=
  if seen.contains name then seen
  else
    let seen := seen.insert name
    match byName[name]? with
    | none => seen
    | some node => (Verify.callees node).foldl (init := seen) fun seen callee =>
      if byName.contains callee then calleeClosure byName callee seen else seen

private def discoverFile (root : FilePath) (command : CompileCommand) (extra : Array String)
    (blocks : Array Block) (modelSource : String) : IO (Array ModelFunction) := do
  let file := command.file
  let ast ← dump command extra
  let source ← IO.FS.readBinFile file
  let relative := FilePath.mk ((file.toString.drop (root.toString.length + 1)).toString)
  let defs := ast.children.filter fun n =>
    n.kind == "FunctionDecl" && n.children.any (·.kind == "CompoundStmt") &&
      absolute command.directory n.location.file == file
  let byName : Std.HashMap String Node := defs.foldl (init := {}) fun m n => m.insert (n.string "name") n
  let output := Verify.translate ast file command.directory
  let translated : Std.HashMap String Verify.Function :=
    output.functions.foldl (init := {}) fun m fn => m.insert fn.name fn
  let records := ast.walk.filter fun n =>
    (n.kind == "RecordDecl" || n.kind == "EnumDecl") &&
      (!(annotations n "lean").isEmpty || !(annotations n "struct").isEmpty)
  let recordJson := records.map (normalize ·.json)
  let relativeTo := fun (path : FilePath) =>
    FilePath.mk ((path.toString.drop (root.toString.length + 1)).toString)
  let localBlocks := blocks.filter (·.file == relative)
  let mut result := #[]
  for node in defs do
    let attrs := annotations node "model"
    if attrs.isEmpty then continue
    let written := (node.children.find? fun attr => (annotation attr).any (·[0]? == some "model")).map
      fun attr => relativeTo (absolute command.directory attr.location.file)
    let localBlocks := blocks.filter (·.file == written.getD relative)
    let name := node.string "name"
    let line := lineOf source node.location.offset
    let column := node.location.column
    let place := s!"{relative}:{line}:{column}"
    let base : ModelFunction := {
      name, block := "", file := relative, line, column, isStatic := node.string "storageClass" == "static"}
    let parsed : Except String _ := do
      if attrs.size != 1 then throw "expected one LF_MODEL on the function definition"
      let (spec, requires, checks) ← parseModel attrs[0]!
      let block ← match spec with
        | some spec =>
          unless blocks.any (·.name == spec) do throw s!"LF_MODEL refers to unknown Lean block '{spec}'"
          pure spec
        | none =>
          let #[block] := localBlocks | throw "LF_MODEL needs spec=<block> unless the file has exactly one Lean block"
          pure block.name
      return (block, requires, checks)
    let model ← match parsed with
      | .error message => pure {base with error := some s!"{place}: unextracted {name}: {message}"}
      | .ok (block, requires, checks) =>
        let model := {base with block, requires, checks}
        match translated[name]? with
        | some _ =>
          let names := calleeClosure byName name {}
          let closure := output.functions.filter (names.contains ·.name)
          let callees := closure.foldl (init := {}) fun m fn =>
            m.insert fn.name ((byName[fn.name]?.map Verify.callees).getD #[] |>.filter (names.contains ·))
          pure {model with closure, callees}
        | none =>
          let reason := (output.unextracted.find? (·.1 == name)).map fun (_, problem) =>
            s!"{relative}:{lineOf source problem.location.offset}:{problem.location.column}: unextracted {name}: {problem.reason}"
          pure {model with error := some (reason.getD s!"{place}: unextracted {name}: not translated")}
    let names := calleeClosure byName name {}
    let asts := defs.filter (names.contains <| ·.string "name") |>.map (normalize ·.json)
    let specBlocks := if model.block.isEmpty then #[] else blockClosure blocks model.block
    let hash ← sha256 (Json.compress (Lean.toJson #[
      Json.str (Json.compress (Lean.toJson (attrs.map Lean.toJson))), Json.arr asts, Json.arr recordJson,
      Lean.toJson (specBlocks.map fun b => (b.name, b.imports, b.source)), Json.str modelSource]))
    result := result.push {model with hash}
  for node in ast.children do
    unless node.kind == "FunctionDecl" && !node.children.any (·.kind == "CompoundStmt") &&
        absolute command.directory node.location.file == file do continue
    let attrs := node.children.filterMap fun attr =>
      if (attr.get? "inherited") == some (.bool true) then none else annotation attr
    let attrs := attrs.filter (·[0]? == some "model")
    if attrs.isEmpty then continue
    let name := node.string "name"
    let line := lineOf source node.location.offset
    let place := s!"{relative}:{line}:{node.location.column}"
    let checks := match parseModel (attrs[0]!.extract 1 attrs[0]!.size) with
      | .ok (_, _, checks) => checks
      | .error _ => #[]
    let block := match parseModel (attrs[0]!.extract 1 attrs[0]!.size) with
      | .ok (some spec, _, _) => spec
      | _ => (localBlocks[0]?.map (·.name)).getD ""
    let hash ← sha256 (Json.compress (Lean.toJson #[Lean.toJson name, Lean.toJson attrs]))
    result := result.push {
      name, block, file := relative, line, column := node.location.column, checks, hash, declaration := true
      error := some s!"{place}: unextracted {name}: LF_MODEL function has no definition in the configured sources" }
  return result

def discoverModels (root : FilePath) (config : Config) (blocks : Array Block) (sources : Array FilePath)
    (modelSource : String) (headers : FilePath) : IO (Array ModelFunction) := do
  if sources.isEmpty then return #[]
  let clang ← (IO.Process.output {cmd := "clang", args := #["--version"]}).toBaseIO
  unless clang.toOption.any (·.exitCode == 0) do
    throw <| IO.userError s!"LF_MODEL requires clang on PATH"
  let db ← readDatabase root
  IO.FS.withTempDir fun tmp => do
    IO.FS.writeFile (tmp / "leanfran.h") supportHeader
    let extra := #["-I", tmp.toString, "-I", headers.toString]
    let mut paths := sources
    if sources.any (·.extension != some "c") then
      for path in ← sourceFiles root config do
        if path.extension == some "c" && !paths.contains path then paths := paths.push path
    let mut models := #[]
    for path in paths do
      let command ← commandFor db config root path extra
      models := models ++ (← discoverFile root command (extra ++ #["-x", "c"]) blocks modelSource)
    let defined := models.filter (!·.declaration) |>.map (·.name)
    let mut seen : Std.HashSet String := {}
    let mut result := #[]
    for m in models do
      if m.declaration then
        if defined.contains m.name || seen.contains m.name then continue
        seen := seen.insert m.name
      result := result.push m
    let mut files : Std.HashMap (String × String) (Array FilePath) := {}
    for m in result do
      if m.declaration || m.block.isEmpty then continue
      for name in (m.closure.map (·.name)).push m.name do
        let known := files[(m.block, name)]?.getD #[]
        unless known.contains m.file do files := files.insert (m.block, name) (known.push m.file)
    let clashes := fun (m : ModelFunction) (name : String) => (files[(m.block, name)]?.getD #[]).size > 1
    return result.map fun m =>
      if m.declaration || m.block.isEmpty then m
      else {m with
        scope := if clashes m m.name then fileIdent m.file else ""
        fileScoped := m.closure.map (·.name) |>.filter (clashes m ·)}

def proofSources (root : FilePath) : IO (Array (String × FilePath × String)) := do
  let dir := root / "lean" / "Proofs"
  unless ← dir.isDir do return #[]
  let files ← dir.walkDir
  let mut result := #[]
  for path in files.qsort (·.toString < ·.toString) do
    unless path.extension == some "lean" && !(← path.isDir) do continue
    let rel := (path.toString.drop (dir.toString.length + 1)).toString
    let parts := ((rel.dropEnd ".lean".length).toString.splitOn "/")
    unless parts.all validLabel do
      throw <| IO.userError s!"lean/Proofs/{rel}: invalid proof module name"
    result := result.push ("Proofs." ++ ".".intercalate parts, path, ← IO.FS.readFile path)
  return result

def inputHash (config : Config) (proofs : Array (String × FilePath × String)) : IO String := do
  sha256 (Json.compress (Lean.toJson #[
    Json.str s!"{releaseVersion}/{Lean.versionString}", Json.str (← sha256 cLibSource),
    Json.str config.source, Lean.toJson (proofs.map fun (m, _, s) => (m, s))]))

private def qualified (name : String) : String :=
  "_root_." ++ ".".intercalate ((name.splitOn ".").map leanIdent)

private def obligations (m : ModelFunction) (fn : Verify.Function) : String := Id.run do
  let params := fn.params.filterMap fun p =>
    match p.kind with
    | .value => some (p.lean, p.boundary)
    | .array _ boundary _ => some (p.lean, s!"Array {boundary}")
    | _ => none
  let args := String.join (params.toList.map (" " ++ ·.1))
  let binders := " ".intercalate (params.toList.map fun (n, t) => s!"({n} : {t})")
  let quantified := if params.isEmpty then "" else s!"∀ {binders}, "
  let sizes := String.join (fn.params.toList.filterMap fun p =>
    match p.kind, p.ty with
    | .length array, .int _ signed width => some s!"{array}.size < 2 ^ {if signed then width - 1 else width} → "
    | _, _ => none)
  let quantified := quantified ++ sizes
  let requires := match m.requires with
    | some name => s!"{qualified name}{args} = true → "
    | none => ""
  let call := s!"{fn.lean}{args}"
  let mut out := ""
  for check in m.checks do
    let predicate := qualified check.predicate
    let prop :=
      if check.label == "refines" then
        if fn.fallible then s!"{call} = Except.ok ({predicate}{args})" else s!"{call} = {predicate}{args}"
      else if fn.fallible then s!"∃ r, {call} = Except.ok r ∧ {predicate}{args} r = true"
      else s!"{predicate}{args} ({call}) = true"
    out := out ++ s!"abbrev {fn.lean}.obligation.{leanIdent check.label} : Prop :=\n  {quantified}{requires}{prop}\n"
  return out

private def writeChanged (path : FilePath) (text : String) : IO Unit := do
  if (← (IO.FS.readFile path).toBaseIO).toOption == some text then return
  if let some parent := path.parent then IO.FS.createDirAll parent
  IO.FS.writeFile path text

private def modulePath (dir : FilePath) (name : String) : FilePath :=
  dir / (System.FilePath.mk ("/".intercalate (name.splitOn ".") ++ ".lean"))

private def lakeOutput (dir : FilePath) (args : Array String) : IO (UInt32 × String) := do
  let result ← IO.Process.output {cmd := "lake", cwd := some dir, args := #["--no-ansi"] ++ args}
  return (result.exitCode, result.stdout ++ result.stderr)

private def functionModule (m : ModelFunction) (name : String) : String :=
  s!"LeanCModel.{m.block}.{fileIdent m.file}.Fn_{name}"

private def removeTree (path : FilePath) : IO Unit := do
  if ← path.pathExists then IO.FS.removeDirAll path

def runProofs (dir : FilePath) (models : Array ModelFunction) (proofs : Array (String × FilePath × String))
    (hasModels : Bool) : IO (Array Obligation) := do
  for path in [dir / "LeanCModel", dir / "Proofs", dir / ".lake" / "build" / "lib" / "lean" / "LeanCModel",
      dir / ".lake" / "build" / "lib" / "lean" / "Proofs", dir / ".lake" / "build" / "ir" / "LeanCModel",
      dir / ".lake" / "build" / "ir" / "Proofs"] do
    removeTree path
  writeChanged (dir / "LeanCLib" / "C.lean") cLibSource
  let mut results := #[]
  let mut refs := #[]
  let mut built : Std.HashSet String := {}
  let mut failedModules : Std.HashSet String := {}
  let mut byBlock : Std.HashMap String (Array String) := {}
  for m in models do
    let mut error := m.error
    if error.isNone then
      for fn in m.closure do
        let mod := functionModule m fn.name
        if built.contains mod then continue
        if failedModules.contains mod then
          error := some s!"{m.file}:{m.line}:{m.column}: cannot elaborate dependency {fn.name}"
          break
        let callees := m.callees[fn.name]?.getD #[]
        let deps := callees.map (functionModule m)
        if let some dep := deps.find? (!built.contains ·) then
          failedModules := failedModules.insert mod
          error := some s!"{m.file}:{m.line}:{m.column}: cannot elaborate dependency {dep}"
          break
        let imports := #["LeanCLib.C", Block.moduleName m.block] ++
          (if hasModels then #["LeanfranModels"] else #[]) ++ deps
        let blockNs := s!"LeanCModel.{leanIdent m.block}"
        let fileNs := s!"{blockNs}.{fileIdent m.file}"
        let ns := if m.fileScoped.contains fn.name then fileNs else blockNs
        let opens := if ns == blockNs && callees.any m.fileScoped.contains then s!"open {fileNs}\n\n" else ""
        let checks := if fn.name == m.name then obligations m fn else ""
        let source := String.join (imports.toList.map (s!"import {·}\n")) ++
          s!"\nnamespace {ns}\n\n{opens}{fn.source}\n{checks}\nend {ns}\n"
        writeChanged (modulePath dir mod) source
        let (code, output) ← lakeOutput dir #["build", s!"+{mod}"]
        if code != 0 then
          IO.eprint output
          failedModules := failedModules.insert mod
          error := some s!"{m.file}:{m.line}:{m.column}: could not elaborate the translated definition of {fn.name} or its obligations"
          break
        built := built.insert mod
        byBlock := byBlock.insert m.block (((byBlock[m.block]?.getD #[]).push mod).toList.eraseDups.toArray)
    for label in m.labels do
      match error with
      | some detail =>
        IO.eprintln detail
        results := results.push {model := m.model, label, status := "unextracted", detail}
      | none => refs := refs.push ({model := m.model, label, status := ""} : Obligation)
  let mut modules := #[]
  for (block, mods) in byBlock.toArray.qsort (·.1 < ·.1) do
    let mod := s!"LeanCModel.{block}"
    writeChanged (modulePath dir mod) (String.join (mods.toList.map (s!"import {·}\n")))
    let (code, output) ← lakeOutput dir #["build", s!"+{mod}"]
    if code != 0 then IO.eprint output; throw <| IO.userError s!"could not build {mod}"
    modules := modules.push mod
  let mut failedSources := #[]
  let workProofs := (dir / "Proofs").toString ++ "/"
  for (mod, _, source) in proofs do
    writeChanged (modulePath dir mod) source
    let (code, output) ← lakeOutput dir #["build", s!"+{mod}"]
    if code != 0 then
      IO.eprint ((output.replace workProofs "lean/Proofs/").replace "Proofs/" "lean/Proofs/"
        |>.replace "lean/lean/Proofs/" "lean/Proofs/")
      failedSources := failedSources.push source
    else modules := modules.push mod
  if !refs.isEmpty then
    let request := dir / "obligations.json"
    IO.FS.writeFile request (Json.compress (Json.arr (refs.map fun o =>
      Json.mkObj [("model", Lean.toJson o.model), ("label", Lean.toJson o.label)])))
    let self ← IO.appPath
    let args := #["env", self.toString, "obligations", "check", "--modules"] ++ modules ++
      #["--obligations", request.toString]
    let output ← IO.Process.output {cmd := "lake", cwd := some dir, args}
    unless output.exitCode == 0 do
      IO.eprint output.stderr
      throw <| IO.userError "leanfran-c obligations check failed"
    let checked ← IO.ofExcept <| (Json.parse output.stdout >>= (·.getArr?) >>= (·.mapM Obligation.fromJson))
    unless checked.size == refs.size do throw <| IO.userError s!"invalid obligations check response: {output.stdout}"
    for o in checked do
      let o := if o.file.startsWith "Proofs/" then {o with file := "lean/" ++ o.file} else o
      let fn := (o.model.splitOn ".").getLast!
      let proof := s!"{fn}.proof.{o.label}"
      let failed := o.status == "missing" &&
        failedSources.any fun s => ((s.replace "«" "").replace "»" "").contains proof
      results := results.push (if failed then {o with status := "failed"} else o)
  return results.qsort fun a b => a.model < b.model || (a.model == b.model && a.label < b.label)

structure Lock where
  inputs : String
  functions : Std.HashMap String String
  obligations : Array Obligation

private def Lock.toJson (lock : Lock) : Json :=
  Json.mkObj [("version", Lean.toJson (1 : Nat)), ("inputs", Lean.toJson lock.inputs),
    ("functions", Json.mkObj (lock.functions.toList.mergeSort (·.1 ≤ ·.1) |>.map fun (k, v) => (k, Lean.toJson v))),
    ("obligations", Json.arr (lock.obligations.map (·.toJson)))]

private def readLock (root : FilePath) : IO (Option Lock) := do
  let .ok text ← (IO.FS.readFile (root / lockName)).toBaseIO | return none
  let parsed : Except String Lock := do
    let json ← Json.parse text
    unless (← json.getObjValAs? Nat "version") == 1 do throw "unknown lock version"
    let inputs ← json.getObjValAs? String "inputs"
    let functions ← match ← json.getObjVal? "functions" with
      | .obj fields => fields.foldlM (init := {}) fun m k v => return m.insert k (← v.getStr?)
      | _ => throw "invalid functions"
    let obligations ← (← (← json.getObjVal? "obligations").getArr?).mapM Obligation.fromJson
    return {inputs, functions, obligations}
  return parsed.toOption

def checkModels (root dir : FilePath) (config : Config) (models : Array ModelFunction) (hasModels : Bool)
    (require : Bool) : IO UInt32 := do
  if models.isEmpty && !(← (root / lockName).pathExists) then return 0
  let proofs ← proofSources root
  let inputs ← inputHash config proofs
  let results ← if models.isEmpty then pure #[] else runProofs dir models proofs hasModels
  let functions := models.foldl (init := {}) fun m fn => m.insert fn.model fn.hash
  IO.FS.writeFile (root / lockName) ((Lock.toJson {inputs, functions, obligations := results}).pretty ++ "\n")
  let mut failed := false
  for o in results do
    IO.println o.report
    failed := failed || o.status == "unextracted" || o.status == "failed" || (require && o.status != "proved")
  if failed then
    IO.eprintln "model obligations did not pass check"
    return 1
  return 0

def modelStatus (root : FilePath) (config : Config) (models : Except String (Array ModelFunction)) : IO UInt32 := do
  let lock ← readLock root
  let models ← match models with
    | .ok models => pure models
    | .error message =>
      IO.eprintln message
      for o in (lock.map (·.obligations)).getD #[] do IO.println ({o with status := "stale"} : Obligation).report
      return 1
  if models.isEmpty && !(← (root / lockName).pathExists) then return 0
  let inputs ← inputHash config (← proofSources root)
  let fresh := lock.filter (·.inputs == inputs)
  let mut stale := lock.isNone || fresh.isNone
  for m in models do
    let saved := fresh.bind fun lock => if lock.functions[m.model]? == some m.hash then some lock else none
    for label in m.labels do
      match saved.bind (·.obligations.find? fun o => o.model == m.model && o.label == label) with
      | some o => IO.println o.report
      | none =>
        stale := true
        IO.println ({model := m.model, label, status := "stale"} : Obligation).report
  if let some lock := lock then
    if lock.functions.size != models.size || lock.obligations.any (fun o => !models.any (·.model == o.model)) then
      stale := true
  if stale then
    IO.eprintln "obligation results are out of date"
    return 1
  return 0

end LeanC.Embed
