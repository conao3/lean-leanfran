import LeanRust

open Lean LeanRust

def version : String := "0.3.0"

/-- Version of the generated code. Raise it when the emitted code changes; the build script of
    lean-rust-build checks it and puts it into its cache keys. -/
def generatorVersion : String := "3"

def usage : String := "usage: lean-rust [--version] [--generator-version] <command> <subcommand> [parameters]

commands:
  module generate   Emit a Rust module for functions of a Lean module
  project generate  Build a lake project and emit a Rust module per Lean module
  crate check       Check the proofs of the obligations of a crate's Lean package

lean-rust module generate
  --module-name <Name>        Lean module to import (required unless --batch)
  --roots <Name> ...          Functions to export (default: the module's public definitions)
  --namespace <Name>          Namespace removed from public Rust names (default: the module name)
  --type-path <Name>=<path> ...
                              Types in namespace <Name> are defined by the generated module at
                              the Rust <path> (not emitted again)
  --batch <file>              JSON array of jobs {\"module\", \"output_file\", \"roots\"?, \"namespace\"?,
                              \"type_paths\"?: {<Name>: <path>}, \"model_namespace\"?}
                              run against one environment importing all their modules
  --import <Name> ...         More modules to import (their @[csimp] lemmas apply)
  --model-namespace <Name>    Namespace of the crate's Aeneas model, whose types are the
                              crate's Rust types (crate::<module>::<Type>)
  --search-path <dir> ...     Extra .olean search directories
  --output-file <path>        Write the module here (default: standard output)
  --runtime-path <path>       Rust path of the runtime (default: ::lean_rust::runtime)
  --facade-path <path>        Rust path of the lean-rust crate (default: ::lean_rust)
  --internal-only             Do not emit public functions
  --output json|text          Format of the summary (skipped definitions with reasons)

lean-rust crate check
  --lake-dir <dir>            The crate's Lean package, built (required)
  --obligations <file>        JSON array of {\"model\": <Lean name>, \"label\": <label>} (required)
  --modules <Name> ...        Modules to import (default: every module the package built)
  Prints a JSON array of {\"model\", \"label\", \"status\", \"axioms\"?, \"file\"?, \"line\"?}

lean-rust project generate
  --lake-dir <dir>            Lake project to build (required)
  --output-dir <dir>          Directory of the Rust modules and mod.rs (required)
  --modules <Name> ...        Modules to emit (default: every module the package builds)
  --runtime-path, --facade-path, --output as above

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"

structure Opts where
  moduleName : Option Name := none
  roots : Array Name := #[]
  namespace? : Option Name := none
  typePaths : Array (Name × String) := #[]
  batch : Option System.FilePath := none
  searchPath : Array System.FilePath := #[]
  outputFile : Option System.FilePath := none
  runtimePath : String := "::lean_rust::runtime"
  facadePath : String := "::lean_rust"
  internalOnly : Bool := false
  output : String := "json"
  lakeDir : Option System.FilePath := none
  outputDir : Option System.FilePath := none
  modules : Array Name := #[]
  imports : Array Name := #[]
  modelNs : Option Name := none
  obligations : Option System.FilePath := none
  sysroot : Option System.FilePath := none

def parseTypePath (s : String) : Except String (Name × String) :=
  match s.splitOn "=" with
  | [ns, path] => .ok (ns.toName, path)
  | _ => .error s!"--type-path must be <Name>=<path>: {s}"

partial def parseOpts (args : List String) (o : Opts) : Except String Opts :=
  let takeMany (rest : List String) : List String × List String :=
    (rest.takeWhile (!·.startsWith "--"), rest.dropWhile (!·.startsWith "--"))
  match args with
  | [] => .ok o
  | "--module-name" :: v :: rest => parseOpts rest { o with moduleName := v.toName }
  | "--namespace" :: v :: rest => parseOpts rest { o with namespace? := v.toName }
  | "--batch" :: v :: rest => parseOpts rest { o with batch := some v }
  | "--output-file" :: v :: rest => parseOpts rest { o with outputFile := some v }
  | "--runtime-path" :: v :: rest => parseOpts rest { o with runtimePath := v }
  | "--facade-path" :: v :: rest => parseOpts rest { o with facadePath := v }
  | "--internal-only" :: rest => parseOpts rest { o with internalOnly := true }
  | "--lake-dir" :: v :: rest => parseOpts rest { o with lakeDir := some v }
  | "--output-dir" :: v :: rest => parseOpts rest { o with outputDir := some v }
  | "--model-namespace" :: v :: rest => parseOpts rest { o with modelNs := some v.toName }
  | "--obligations" :: v :: rest => parseOpts rest { o with obligations := some v }
  | "--import" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with imports := o.imports ++ vs.toArray.map String.toName }
  | "--output" :: v :: rest =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else .error s!"--output must be json or text: {v}"
  | "--roots" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with roots := o.roots ++ vs.toArray.map String.toName }
  | "--type-path" :: rest =>
    let (vs, rest) := takeMany rest
    match vs.mapM parseTypePath with
    | .ok ps => parseOpts rest { o with typePaths := o.typePaths ++ ps.toArray }
    | .error e => .error e
  | "--modules" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with modules := o.modules ++ vs.toArray.map String.toName }
  | "--search-path" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with searchPath := o.searchPath ++ vs.toArray.map System.FilePath.mk }
  | a :: _ => .error s!"unknown parameter: {a}"

def fail (code : UInt32) (msg : String) : IO UInt32 := do
  IO.eprintln s!"lean-rust: {msg}"
  return code

structure Job where
  module : Name
  roots : Array Name := #[]
  namespace? : Option Name := none
  typePaths : Array (Name × String) := #[]
  outputFile : Option System.FilePath := none
  modelNs : Option Name := none

/-- The definitions of `mod` exported by default: public, written in the source (with a declaration
    range), not instances or their auxiliary definitions, with IR. -/
def defaultRoots (env : Environment) (mod : Name) : Array Name := Id.run do
  let some idx := env.getModuleIdx? mod | return #[]
  let mut out := #[]
  for c in env.header.moduleData[idx.toNat]!.constNames do
    if isPrivateName c || c.isInternalDetail || isAuxRecursor env c then continue
    if Meta.isInstanceCore env c || Meta.isInstanceCore env c.getPrefix then continue
    if (declRangeExt.find? (level := .exported) env c).isNone then continue
    if (IR.findEnvDecl env c).isSome then out := out.push c
  return out

def header (mod : Name) (o : Opts) : String :=
  s!"// Generated by lean-rust (generator {generatorVersion}) from {mod}. Do not edit.\n#[allow(unused_imports)]\nuse {o.runtimePath} as rt;\n#[allow(unused_imports)]\nuse rt::Obj;\n\n"

/-- Runs one job; the summary is a JSON object, the code an exit code. -/
def runJob (env : Environment) (o : Opts) (job : Job) : IO (Json × UInt32) := do
  let failed (code : UInt32) (msg : String) : IO (Json × UInt32) :=
    return (Json.mkObj [("module", toString job.module), ("error", msg), ("code", code.toNat)], code)
  if env.getModuleIdx? job.module |>.isNone then return ← failed 252 s!"module not imported: {job.module}"
  let roots := if job.roots.isEmpty then defaultRoots env job.module else job.roots
  let strip := job.namespace?.getD job.module
  let ctx : Core.Context := { fileName := "<lean-rust>", fileMap := default, maxHeartbeats := 0 }
  let (res, _) ← (generate roots strip job.typePaths o.facadePath o.internalOnly (job.modelNs <|> o.modelNs)).run'.toIO ctx { env }
  match res with
  | .error e => failed 254 e
  | .ok out =>
    let missing := out.externs.filter (!runtimeExterns.contains ·)
    unless missing.isEmpty do
      return ← failed 254 s!"externs not in the runtime: {", ".intercalate missing.toList}"
    let src := header job.module o ++ out.items
    match job.outputFile with
    | none => IO.print src
    | some p =>
      if let some dir := p.parent then IO.FS.createDirAll dir
      IO.FS.writeFile p src
    let skipped := out.skipped.map fun s => Json.mkObj [("name", toString s.name), ("reason", s.reason)]
    let publics := out.publics.map fun (l, r) => Json.mkObj [("lean", toString l), ("rust", r)]
    return (Json.mkObj [("module", toString job.module), ("functions", out.decls.size), ("externs", out.externs.size),
      ("public", Json.arr publics), ("skipped", Json.arr skipped)], 0)

def printSummary (o : Opts) (toStderr : Bool) (j : Json) : IO Unit := do
  let out := if toStderr then IO.eprintln else IO.println
  if o.output == "json" then out j.compress
  else
    let get (k : String) := (j.getObjValD k)
    let mod := (get "module").getStr?.toOption.getD ""
    match (get "error").getStr? with
    | .ok e => IO.eprintln s!"lean-rust: {mod}: {e}"
    | .error _ =>
      out s!"{mod}: {get "functions"} functions, {get "externs"} externs, {(get "public").getArr?.toOption.getD #[] |>.size} public"
      for s in (get "skipped").getArr?.toOption.getD #[] do
        IO.eprintln s!"lean-rust: skipped {(s.getObjValD "name").getStr?.toOption.getD ""}: {(s.getObjValD "reason").getStr?.toOption.getD ""}"

def importAll (o : Opts) (mods : Array Name) : IO (Except Name Environment) := do
  initSearchPath (← o.sysroot.getDM findSysroot) o.searchPath.toList
  let sp ← searchPathRef.get
  for m in mods do
    if (← sp.findWithExt "olean" m).isNone then return .error m
  .ok <$> importModules (mods.map fun m => { module := m }) {} (trustLevel := 1024) (loadExts := true)

def parseJobs (j : Json) : Except String (Array Job) := do
  let arr ← j.getArr?
  arr.mapM fun e => do
    let module := (← e.getObjValAs? String "module").toName
    let roots := (e.getObjValAs? (Array String) "roots").toOption.getD #[] |>.map String.toName
    let namespace? := (e.getObjValAs? String "namespace").toOption.map String.toName
    let outputFile := (e.getObjValAs? String "output_file").toOption.map System.FilePath.mk
    let modelNs := (e.getObjValAs? String "model_namespace").toOption.map String.toName
    let typePaths := match e.getObjVal? "type_paths" with
      | .ok (.obj kvs) => kvs.toArray.filterMap fun (k, v) => v.getStr?.toOption.map fun p => (k.toName, p)
      | _ => #[]
    return { module, roots, namespace?, typePaths, outputFile, modelNs }

def runJobs (o : Opts) (jobs : Array Job) : IO (Array Json × UInt32) := do
  let env ← match ← importAll o (jobs.map (·.module) ++ o.imports) with
    | .ok env => pure env
    | .error m =>
      let j := Json.mkObj [("module", toString m), ("error", s!"no .olean for {m} in the search path"), ("code", 252)]
      return (jobs.map fun _ => j, 252)
  let mut out := #[]
  let mut code : UInt32 := 0
  for job in jobs do
    let (j, c) ← runJob env o job
    out := out.push j
    code := max code c
  return (out, code)

def moduleGenerate (o : Opts) : IO UInt32 := do
  if let some file := o.batch then
    let jobs ← match Json.parse (← IO.FS.readFile file) >>= parseJobs with
      | .ok js => pure js
      | .error e => return ← fail 252 s!"invalid --batch file {file}: {e}"
    let (out, code) ← runJobs o jobs
    if o.output == "json" then IO.println (Json.arr out).compress
    else for j in out do printSummary o false j
    return code
  let some mod := o.moduleName | fail 252 "--module-name is required"
  let (out, code) ← runJobs o #[{ module := mod, roots := o.roots, namespace? := o.namespace?, typePaths := o.typePaths, outputFile := o.outputFile }]
  printSummary o o.outputFile.isNone out[0]!
  return code

def runCmd (cmd : String) (args : Array String) (cwd : System.FilePath) : IO String := do
  let out ← IO.Process.output { cmd, args, cwd }
  if out.exitCode != 0 then
    throw (IO.userError s!"{cmd} {" ".intercalate args.toList} failed ({out.exitCode}):\n{out.stdout}{out.stderr}")
  return out.stdout

/-- Rust module name of a Lean module: `RomanNumerals.Basic` → `roman_numerals_basic`. -/
def rustModName (m : Name) : String :=
  rustIdent ("_".intercalate (m.components.map fun c => sanitize (snakeCase (componentString c))))

partial def oleanModules (root : System.FilePath) (dir : System.FilePath) (pre : Name) : IO (Array Name) := do
  let mut out := #[]
  for e in ← dir.readDir do
    if ← e.path.isDir then
      out := out ++ (← oleanModules root e.path (pre.str e.fileName))
    else if e.fileName.endsWith ".olean" then
      out := out.push (pre.str (e.path.fileStem.getD ""))
  return out

def projectGenerate (o : Opts) : IO UInt32 := do
  let some lakeDir := o.lakeDir | fail 252 "--lake-dir is required"
  let some outDir := o.outputDir | fail 252 "--output-dir is required"
  unless ← lakeDir.isDir do return ← fail 252 s!"not a directory: {lakeDir}"
  let lake := (← IO.getEnv "LAKE").getD "lake"
  discard <| runCmd lake (#["build"] ++ o.modules.map toString) lakeDir
  let leanPath := (← runCmd lake #["env", "printenv", "LEAN_PATH"] lakeDir).trimAscii.toString
  let paths := (leanPath.splitOn ":").filter (!·.isEmpty) |>.toArray.map System.FilePath.mk
  let sysroot := System.FilePath.mk (← runCmd lake #["env", "printenv", "LEAN_SYSROOT"] lakeDir).trimAscii.toString
  let lib := lakeDir / ".lake" / "build" / "lib" / "lean"
  let mods ← if o.modules.isEmpty then oleanModules lib lib .anonymous else pure o.modules
  let mods := mods.qsort (·.toString < ·.toString)
  if mods.isEmpty then return ← fail 252 s!"no modules in {lakeDir}"
  IO.FS.createDirAll outDir
  let jobs := mods.map fun m => { module := m, outputFile := some (outDir / s!"{rustModName m}.rs") : Job }
  let (out, code) ← runJobs { o with searchPath := o.searchPath ++ paths, sysroot } jobs
  let modRs := s!"// Generated by lean-rust (generator {generatorVersion}). Do not edit.\n\n" ++
    String.join (mods.toList.map fun m =>
      s!"#[allow(dead_code, non_snake_case, non_camel_case_types, unused_imports, unused_parens, unused_qualifications, unsafe_op_in_unsafe_fn, clippy::all)]\npub mod {rustModName m};\n")
  IO.FS.writeFile (outDir / "mod.rs") modRs
  if o.output == "json" then IO.println (Json.arr out).compress
  else for j in out do printSummary o false j
  return code

def crateCheck (o : Opts) : IO UInt32 := do
  let some lakeDir := o.lakeDir | fail 252 "--lake-dir is required"
  let some file := o.obligations | fail 252 "--obligations is required"
  let obls ← match Json.parse (← IO.FS.readFile file) >>= parseObligations with
    | .ok v => pure v
    | .error e => return ← fail 252 s!"invalid --obligations file {file}: {e}"
  unless ← lakeDir.isDir do return ← fail 252 s!"not a directory: {lakeDir}"
  let lake := (← IO.getEnv "LAKE").getD "lake"
  let leanPath := (← runCmd lake #["env", "printenv", "LEAN_PATH"] lakeDir).trimAscii.toString
  let paths := (leanPath.splitOn ":").filter (!·.isEmpty) |>.toArray.map System.FilePath.mk
  let sysroot := System.FilePath.mk (← runCmd lake #["env", "printenv", "LEAN_SYSROOT"] lakeDir).trimAscii.toString
  let lib := lakeDir / ".lake" / "build" / "lib" / "lean"
  let mods ← if o.modules.isEmpty then oleanModules lib lib .anonymous else pure o.modules
  let mods := mods.filter (fun m => !m.toString.endsWith "_Template") |>.qsort (·.toString < ·.toString)
  match ← importAll { o with searchPath := o.searchPath ++ paths, sysroot } mods with
  | .error m => fail 252 s!"no .olean for {m} in the search path"
  | .ok env =>
    let ctx : Core.Context := { fileName := "<lean-rust>", fileMap := default, maxHeartbeats := 0 }
    let (out, _) ← ((obls.mapM checkObligation).run').toIO ctx { env }
    IO.println (Json.arr out).compress
    return 0

unsafe def main (args : List String) : IO UInt32 := do
  enableInitializersExecution
  match args with
  | ["--version"] => IO.println s!"lean-rust {version}"; return 0
  | ["--generator-version"] => IO.println generatorVersion; return 0
  | ["help"] | ["--help"] | [] => IO.print usage; return 0
  | "module" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try moduleGenerate o
      catch e => fail 255 (toString e)
  | "project" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try projectGenerate o
      catch e => fail 255 (toString e)
  | "crate" :: "check" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try crateCheck o
      catch e => fail 255 (toString e)
  | _ => IO.eprint usage; return 252
