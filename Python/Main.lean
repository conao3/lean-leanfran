import LeanPython

open Lean LeanPython

def version : String := "0.1.0"

/-- Version of the generated code. Raise it when the emitted code changes; `lean-python sync`
    checks it and puts it into its cache keys. -/
def generatorVersion : String := "2"

def usage : String := "usage: lean-python [--version] [--generator-version] <command> <subcommand> [parameters]

commands:
  module generate      Emit a Python module for functions of a Lean module
  obligations check    Judge the proofs of obligations (used by `lean-py check`)

lean-python module generate
  --module-name <Name>        Lean module to import (required unless --batch)
  --roots <Name> ...          Functions to export (default: the module's public definitions)
  --namespace <Name>          Namespace removed from public Python names (default: the module name)
  --batch <file>              JSON array of jobs {\"module\", \"output_file\", \"roots\"?, \"namespace\"?,
                              \"type_modules\"?: [{\"namespace\", \"module\", \"adopt\"?}]}
                              run against one environment importing all their modules
  --type-module <Name>=<module> ...
                              Types in namespace <Name> are classes of the Python <module>
  --model-module <Name>=<module> ...
                              As --type-module, for a module of pydantic models given the
                              layout of the Lean structures
  --import <Name> ...         More modules to import (their @[csimp] lemmas apply)
  --search-path <dir> ...     Extra .olean search directories
  --output-file <path>        Write the module here (default: standard output)
  --internal-only             Do not emit public functions and types
  --output json|text          Format of the summary (skipped definitions with reasons)

lean-python obligations check
  --modules <Name> ...        Modules to import (required)
  --obligations <file>        JSON array of {\"model\": <Lean name>, \"label\": <label>} (required)
  --search-path <dir> ...     Extra .olean search directories
  Prints a JSON array of {\"model\", \"label\", \"status\", \"axioms\"?, \"file\"?, \"line\"?}; the
  status is proved, sorry, axioms, missing, mismatch or unextracted

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"

structure Opts where
  moduleName : Option Name := none
  roots : Array Name := #[]
  namespace? : Option Name := none
  batch : Option System.FilePath := none
  searchPath : Array System.FilePath := #[]
  outputFile : Option System.FilePath := none
  internalOnly : Bool := false
  output : String := "json"
  imports : Array Name := #[]
  typeModules : Array (Name × String × Bool) := #[]
  modules : Array Name := #[]
  obligations : Option System.FilePath := none

def parseTypeModule (adopt : Bool) (s : String) : Except String (Name × String × Bool) :=
  match s.splitOn "=" with
  | [ns, m] => .ok (ns.toName, m, adopt)
  | _ => .error s!"expected <Name>=<module>: {s}"

partial def parseOpts (args : List String) (o : Opts) : Except String Opts :=
  let takeMany (rest : List String) : List String × List String :=
    (rest.takeWhile (!·.startsWith "--"), rest.dropWhile (!·.startsWith "--"))
  match args with
  | [] => .ok o
  | "--module-name" :: v :: rest => parseOpts rest { o with moduleName := v.toName }
  | "--namespace" :: v :: rest => parseOpts rest { o with namespace? := v.toName }
  | "--batch" :: v :: rest => parseOpts rest { o with batch := some v }
  | "--output-file" :: v :: rest => parseOpts rest { o with outputFile := some v }
  | "--internal-only" :: rest => parseOpts rest { o with internalOnly := true }
  | "--import" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with imports := o.imports ++ vs.toArray.map String.toName }
  | "--output" :: v :: rest =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else .error s!"--output must be json or text: {v}"
  | "--roots" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with roots := o.roots ++ vs.toArray.map String.toName }
  | "--obligations" :: v :: rest => parseOpts rest { o with obligations := some v }
  | "--modules" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with modules := o.modules ++ vs.toArray.map String.toName }
  | "--type-module" :: rest =>
    let (vs, rest) := takeMany rest
    match vs.mapM (parseTypeModule false) with
    | .ok ps => parseOpts rest { o with typeModules := o.typeModules ++ ps.toArray }
    | .error e => .error e
  | "--model-module" :: rest =>
    let (vs, rest) := takeMany rest
    match vs.mapM (parseTypeModule true) with
    | .ok ps => parseOpts rest { o with typeModules := o.typeModules ++ ps.toArray }
    | .error e => .error e
  | "--search-path" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with searchPath := o.searchPath ++ vs.toArray.map System.FilePath.mk }
  | a :: _ => .error s!"unknown parameter: {a}"

def fail (code : UInt32) (msg : String) : IO UInt32 := do
  IO.eprintln s!"lean-python: {msg}"
  return code

structure Job where
  module : Name
  roots : Array Name := #[]
  namespace? : Option Name := none
  outputFile : Option System.FilePath := none
  typeModules : Array (Name × String × Bool) := #[]
  modules : Array Name := #[]
  obligations : Option System.FilePath := none

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

def header (mod : Name) : String :=
  s!"# Generated by lean-python (generator {generatorVersion}) from {mod}. Do not edit.\n# ruff: noqa\n__lean_module__ = \"{mod}\"\n"

/-- Runs one job; the summary is a JSON object, the code an exit code. -/
def runJob (env : Environment) (o : Opts) (job : Job) : IO (Json × UInt32) := do
  let failed (code : UInt32) (msg : String) : IO (Json × UInt32) :=
    return (Json.mkObj [("module", toString job.module), ("error", msg), ("code", code.toNat)], code)
  if env.getModuleIdx? job.module |>.isNone then return ← failed 252 s!"module not imported: {job.module}"
  let roots := if job.roots.isEmpty then defaultRoots env job.module else job.roots
  let strip := job.namespace?.getD job.module
  let ctx : Core.Context := { fileName := "<lean-python>", fileMap := default, maxHeartbeats := 0 }
  let (res, _) ← (generate roots strip o.internalOnly (o.typeModules ++ job.typeModules)).toIO ctx { env }
  match res with
  | .error e => failed 254 e
  | .ok out =>
    let missing := out.externs.filter (!runtimeExterns.contains ·)
    unless missing.isEmpty do
      return ← failed 254 s!"externs not in the runtime: {", ".intercalate missing.toList}"
    let src := header job.module ++ moduleHeader out.externs ++ "\n" ++ out.items ++ out.publicItems
    match job.outputFile with
    | none => IO.print src
    | some p =>
      if let some dir := p.parent then IO.FS.createDirAll dir
      IO.FS.writeFile p src
    let skipped := out.skipped.map fun s => Json.mkObj [("name", toString s.name), ("reason", s.reason)]
    let publics := out.publics.map fun (l, r) => Json.mkObj [("lean", toString l), ("python", r)]
    return (Json.mkObj [("module", toString job.module), ("functions", out.decls.size), ("externs", out.externs.size),
      ("public", Json.arr publics), ("skipped", Json.arr skipped)], 0)

def printSummary (o : Opts) (toStderr : Bool) (j : Json) : IO Unit := do
  let out := if toStderr then IO.eprintln else IO.println
  if o.output == "json" then out j.compress
  else
    let get (k : String) := (j.getObjValD k)
    let mod := (get "module").getStr?.toOption.getD ""
    match (get "error").getStr? with
    | .ok e => IO.eprintln s!"lean-python: {mod}: {e}"
    | .error _ =>
      out s!"{mod}: {get "functions"} functions, {get "externs"} externs, {(get "public").getArr?.toOption.getD #[] |>.size} public"
      for s in (get "skipped").getArr?.toOption.getD #[] do
        IO.eprintln s!"lean-python: skipped {(s.getObjValD "name").getStr?.toOption.getD ""}: {(s.getObjValD "reason").getStr?.toOption.getD ""}"

def importAll (o : Opts) (mods : Array Name) : IO (Except Name Environment) := do
  initSearchPath (← findSysroot) o.searchPath.toList
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
    let tms := (e.getObjValAs? (Array Json) "type_modules").toOption.getD #[]
    let typeModules ← tms.mapM fun t => do
      let ns := (← t.getObjValAs? String "namespace").toName
      let m ← t.getObjValAs? String "module"
      let adopt := (t.getObjValAs? Bool "adopt").toOption.getD false
      pure (ns, m, adopt)
    return { module, roots, namespace?, outputFile, typeModules }

def moduleGenerate (o : Opts) : IO UInt32 := do
  let jobs ← match o.batch with
    | some f =>
      match Json.parse (← IO.FS.readFile f) >>= parseJobs with
      | .ok js => pure js
      | .error e => return ← fail 252 s!"--batch: {e}"
    | none =>
      let some m := o.moduleName | return ← fail 252 "--module-name is required"
      pure #[{ module := m, roots := o.roots, namespace? := o.namespace?, outputFile := o.outputFile : Job }]
  let mods := (jobs.map (·.module) ++ o.imports).foldl (fun a m => if a.contains m then a else a.push m) #[]
  let env ← match ← importAll o mods with
    | .ok env => pure env
    | .error m => return ← fail 252 s!"module not found: {m}"
  let mut code : UInt32 := 0
  let mut summaries := #[]
  for job in jobs do
    let (j, c) ← runJob env o job
    summaries := summaries.push j
    if c != 0 && code == 0 then code := c
  if o.batch.isSome then
    if o.output == "json" then IO.println (Json.arr summaries).compress
    else for j in summaries do printSummary o false j
  else
    for j in summaries do printSummary o (o.outputFile.isNone) j
  return code

def obligationsCheck (o : Opts) : IO UInt32 := do
  let some file := o.obligations | return ← fail 252 "--obligations is required"
  if o.modules.isEmpty then return ← fail 252 "--modules is required"
  let obls ← match Json.parse (← IO.FS.readFile file) >>= parseObligations with
    | .ok v => pure v
    | .error e => return ← fail 252 s!"invalid --obligations file {file}: {e}"
  match ← importAll o o.modules with
  | .error m => fail 252 s!"no .olean for {m} in the search path"
  | .ok env =>
    let ctx : Core.Context := { fileName := "<lean-python>", fileMap := default, maxHeartbeats := 0 }
    let (out, _) ← ((obls.mapM checkObligation).run').toIO ctx { env }
    IO.println (Json.arr out).compress
    return 0

unsafe def main (args : List String) : IO UInt32 := do
  enableInitializersExecution
  match args with
  | ["--version"] => IO.println version; return 0
  | ["--generator-version"] => IO.println generatorVersion; return 0
  | [] | ["help"] | ["--help"] => IO.print usage; return 0
  | "module" :: "help" :: _ => IO.print usage; return 0
  | "module" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try moduleGenerate o
      catch e => fail 255 (toString e)
  | "obligations" :: "check" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try obligationsCheck o
      catch e => fail 255 (toString e)
  | _ => fail 252 s!"unknown command (see `lean-python help`)"
