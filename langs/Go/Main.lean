import LeanGo
import LeanGo.Check

open Lean LeanGo

def version : String := "0.11.0"
def generatorVersion : String := "11"

def usage : String := "leanfran-go --version | --generator-version | --lean-version
leanfran-go module generate --module-name <Name> [options]
leanfran-go obligations check --modules <Name> ... --obligations <file>

  --roots <Name> ...          Lean definitions to compile
  --namespace <Name>          Strip this prefix from public names
  --type-module <N=path>      Import public types from another Go package
  --import <Name> ...         More modules to import
  --search-path <dir> ...     Extra .olean search directories
  --package <name>            Generated Go package name
  --main <Name>               Generate an executable Go package
  --internal-only             Generate runtime-facing functions
  --output-dir <dir>          Generate a typed Go package
  --output-file <path>        Output path (default: stdout)
  --output json|text          Summary format (default: json)
  --batch <file>              JSON jobs with module and output_file or output_dir

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"

structure JobOpts where
  roots : Array Name := #[]
  namespace? : Option Name := none
  package? : Option String := none
  main? : Option Name := none
  outputFile : Option System.FilePath := none
  outputDir : Option System.FilePath := none
  typeModules : Array (Name × String) := #[]
  goPath : String := ""
  models : Array ModelSpec := #[]
  internalOnly : Bool := false

structure Job extends JobOpts where
  module : Name

structure Opts extends JobOpts where
  moduleName : Option Name := none
  batch : Option System.FilePath := none
  searchPath : Array System.FilePath := #[]
  output : String := "json"
  imports : Array Name := #[]

partial def parseOpts (args : List String) (o : Opts) : Except String Opts := do
  let flag :: rest := args | return o
  if flag == "--internal-only" then
    return ← parseOpts rest { o with internalOnly := true }
  let isValue (s : String) := !s.isEmpty && !s.startsWith "--"
  if #["--roots", "--import", "--search-path"].contains flag then
    let vs := (rest.takeWhile isValue).toArray
    if vs.isEmpty then throw s!"expected at least one value for {flag}"
    let o := match flag with
      | "--roots" => { o with roots := o.roots ++ vs.map String.toName }
      | "--import" => { o with imports := o.imports ++ vs.map String.toName }
      | _ => { o with searchPath := o.searchPath ++ vs.map System.FilePath.mk }
    return ← parseOpts (rest.drop vs.size) o
  unless #["--module-name", "--namespace", "--package", "--main", "--batch", "--output-file",
      "--output", "--output-dir", "--type-module"].contains flag do
    throw s!"unknown parameter: {flag}"
  let v :: rest := rest | throw s!"expected a value for {flag}"
  unless isValue v do throw s!"expected a value for {flag}"
  match flag with
  | "--module-name" => parseOpts rest { o with moduleName := v.toName }
  | "--namespace" => parseOpts rest { o with namespace? := v.toName }
  | "--package" => parseOpts rest { o with package? := some v }
  | "--main" => parseOpts rest { o with main? := v.toName }
  | "--batch" => parseOpts rest { o with batch := some v }
  | "--output-file" => parseOpts rest { o with outputFile := some v }
  | "--output-dir" => parseOpts rest { o with outputDir := some v }
  | "--type-module" =>
    let [ns, path] := v.splitOn "=" | throw "expected --type-module N=importpath"
    if ns.isEmpty || path.isEmpty || o.typeModules.any (·.1 == ns.toName) then
      throw s!"invalid or repeated --type-module: {v}"
    parseOpts rest { o with typeModules := o.typeModules.push (ns.toName, path) }
  | _ =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else throw s!"--output must be json or text: {v}"

def optionalField [FromJson α] (j : Json) (key : String) : Except String (Option α) :=
  match j.getObjVal? key with
  | .ok v => some <$> fromJson? v
  | .error _ => .ok none

def modelMap (j : Json) (key : String) : Except String (Std.TreeMap String String) := do
  let some obj ← optionalField (α := Json) j key | return {}
  (← obj.getObj?).foldlM (fun acc k v => return acc.insert k (← v.getStr?)) {}

def parseModel (j : Json) : Except String ModelSpec := do
  let lean ← j.getObjValAs? String "lean"
  let path ← j.getObjValAs? String "path"
  let name ← j.getObjValAs? String "name"
  let fields ← modelMap j "fields"
  let cases ← modelMap j "cases"
  let plain := (← optionalField (α := Bool) j "plain").getD false
  let restricted := (← optionalField (α := Bool) j "restricted").getD false
  return { lean, path, name, fields, cases, plain, restricted }

def parseJobs (j : Json) (internalOnly : Bool) : Except String (Array Job) := do
  let jobs ← j.getArr?
  if jobs.isEmpty then throw "expected at least one job"
  jobs.mapM fun e => do
    let module := (← e.getObjValAs? String "module").toName
    let roots := (← optionalField (α := Array String) e "roots").getD #[] |>.map String.toName
    let namespace? := (← optionalField (α := String) e "namespace").map String.toName
    let package? ← optionalField (α := String) e "package"
    let main? := (← optionalField (α := String) e "main").map String.toName
    let outputFile := (← optionalField (α := String) e "output_file").map System.FilePath.mk
    let outputDir := (← optionalField (α := String) e "output_dir").map System.FilePath.mk
    unless outputFile.isSome != outputDir.isSome do
      throw s!"{module}: expected exactly one of output_file or output_dir"
    let typeModules ← ((← optionalField (α := Array String) e "type_modules").getD #[]).mapM fun spec => do
      let [ns, path] := spec.splitOn "=" | throw "expected type_modules entries in N=importpath form"
      if ns.isEmpty || path.isEmpty then throw s!"invalid type module: {spec}"
      pure (ns.toName, path)
    let internalOnly := (← optionalField (α := Bool) e "internal_only").getD internalOnly
    let goPath := (← optionalField (α := String) e "go_path").getD ""
    let models ← ((← optionalField (α := Array Json) e "models").getD #[]).mapM parseModel
    return { module, roots, namespace?, package?, main?, outputFile, outputDir, typeModules, internalOnly, goPath, models }

def goPackage (job : Job) : Except String String := do
  let moduleName := match job.module with
    | .str _ s => s.toLower
    | .num _ n => toString n
    | .anonymous => ""
  let pkg := if job.main?.isSome then "main" else
    job.package?.getD moduleName
  let letters (c : Char) := c.isAlpha || c == '_'
  let reserved := #["break", "default", "func", "interface", "select", "case", "defer", "go",
    "map", "struct", "chan", "else", "goto", "package", "switch", "const", "fallthrough",
    "if", "range", "type", "continue", "for", "import", "return", "var", "_"]
  unless (pkg.toList.head?.any letters) && pkg.toList.all (fun c => letters c || c.isDigit)
      && !reserved.contains pkg do
    throw s!"invalid Go package name: {pkg}"
  return pkg

def defaultRoots (env : Environment) (job : Job) : Array Name := Id.run do
  let some idx := env.getModuleIdx? job.module | return #[]
  let mut roots := #[]
  for c in env.header.moduleData[idx.toNat]!.constNames do
    if c.isInternalDetail || isPrivateName c then continue
    if (declRangeExt.find? (level := .exported) env c).isNone then continue
    if !job.namespace?.all (·.isPrefixOf c) then continue
    match env.find? c with
    | some (.defnInfo _) | some (.opaqueInfo _) =>
      let target := csimpTarget env c
      if IR.findEnvDecl env target |>.isSome then
        unless roots.contains target do roots := roots.push target
    | _ => pure ()
  return roots

def publicDecls (env : Environment) (job : Job) : Array Name × Array Name := Id.run do
  let some idx := env.getModuleIdx? job.module | return (#[], job.roots)
  let mut types := #[]
  let mut roots := #[]
  for c in env.header.moduleData[idx.toNat]!.constNames do
    let publicName := (privateToUserName? c).getD c
    if publicName.isInternalDetail then continue
    if (declRangeExt.find? (level := .exported) env c).isNone && !isPrivateName c then continue
    match env.find? c with
    | some (.inductInfo _) => types := types.push c
    | some (.defnInfo d) =>
      if d.type.isSort then types := types.push c
      else if isPrivateName c || (IR.findEnvDecl env (csimpTarget env c)).isSome then roots := roots.push c
    | some (.opaqueInfo _) => roots := roots.push c
    | _ => pure ()
  return (types.qsort Name.lt, (if job.roots.isEmpty then roots else job.roots).qsort Name.lt)

def writePublic (dir : System.FilePath) (sources : Array (String × String)) : IO (Array String) := do
  let mut formatted := #[]
  for (name, source) in sources do
    let tmp ← IO.FS.createTempFile
    let (_, path) := tmp
    try
      IO.FS.writeFile path source
      let out ← IO.Process.output { cmd := "gofmt", args := #[path.toString] }
      unless out.exitCode == 0 do throw (IO.userError out.stderr)
      formatted := formatted.push (name, out.stdout)
    finally
      IO.FS.removeFile path
  IO.FS.createDirAll dir
  for (name, source) in formatted do
    IO.FS.writeFile (dir / name) source
  for entry in ← dir.readDir do
    if entry.fileName.endsWith ".go" && !sources.any (·.1 == entry.fileName) then
      if (← entry.path.metadata).type == .file then
        let handle ← IO.FS.Handle.mk entry.path .read
        if (← handle.getLine).startsWith "// Code generated by leanfran-go" then
          IO.FS.removeFile entry.path
  return sources.map (fun (name, _) => (dir / name).toString)

def printSummary (o : Opts) (summary : Json) (toStderr : Bool) : IO Unit := do
  let print := if toStderr || (summary.getObjVal? "error").isOk then IO.eprintln else IO.println
  if o.output == "json" then print summary.compress
  else
    let mod := (summary.getObjValD "module").getStr?.toOption.getD ""
    match (summary.getObjValD "error").getStr? with
    | .ok e => print s!"leanfran-go: {mod}: {e}"
    | .error _ =>
      print s!"{mod}: package {(summary.getObjValD "package").getStr?.toOption.getD ""}"
      for file in (summary.getObjValD "files").getArr?.toOption.getD #[] do
        print s!"  wrote {file.getStr?.toOption.getD ""}"
      for skipped in (summary.getObjValD "skipped").getArr?.toOption.getD #[] do
        let name := (skipped.getObjValD "name").getStr?.toOption.getD ""
        let reason := (skipped.getObjValD "reason").getStr?.toOption.getD ""
        print s!"  skipped {name}: {reason}"

def runJob (env : Environment) (job : Job) : IO (Json × UInt32) := do
  let mod := toString job.module
  let failed (code : UInt32) (msg : String) : IO (Json × UInt32) :=
    pure (Json.mkObj [("module", mod), ("error", msg), ("code", code.toNat)], code)
  let pkg ← match goPackage job with
    | .ok name => pure name
    | .error e => return ← failed 252 e
  if let some dir := job.outputDir then
    let (types, roots) := publicDecls env job
    let strip := job.namespace?.getD job.module
    let typeModules := job.typeModules.qsort (fun a b =>
      if a.1.components.length == b.1.components.length then Name.lt a.1 b.1
      else a.1.components.length > b.1.components.length)
    let (publicModule, env) ← try inspectPublic env { strip, typeModules, models := job.models } types roots
      catch e => return ← failed 254 e.toString
    let sources ← match publicSources env job.module pkg generatorVersion job.goPath publicModule with
      | .ok sources => pure sources
      | .error reason => return ← failed 254 reason
    let files ← writePublic dir sources
    let skipped := publicModule.skipped.map fun s => Json.mkObj [("name", toString s.name), ("reason", s.reason)]
    let functions := Json.mkObj (publicModule.functions.toList.map fun f =>
      ((stripName strip f.source).toString, toJson f.ident))
    let valueFunctions := Json.mkObj (publicModule.handles.toList.map fun f =>
      ((stripName strip f.source).toString, toJson ("Handle." ++ f.ident)))
    let scopedValueFunctions := Json.mkObj (publicModule.handles.toList.map fun f =>
      ((stripName strip f.source).toString, toJson ("Handle.In(scope)." ++ f.ident)))
    let valueConversions := Json.arr <| (publicModule.conversions.qsort (fun a b => a.newIdent < b.newIdent)).map fun c =>
      Json.mkObj [("type", toJson c.desc.valueStem), ("new", toJson ("Value." ++ c.newIdent)), ("read", toJson ("Value." ++ c.readIdent)),
        ("newIn", toJson ("Value.In(scope)." ++ c.newIdent)), ("readIn", toJson ("Value.In(scope)." ++ c.readIdent))]
    return (Json.mkObj [("module", mod), ("package", pkg), ("files", toJson files),
      ("skipped", toJson skipped), ("functions", functions), ("valueFunctions", valueFunctions),
      ("scopedValueFunctions", scopedValueFunctions), ("valueConversions", valueConversions),
      ("types", verificationTypes publicModule.state job.goPath)], 0)
  let roots := if job.roots.isEmpty then defaultRoots env job else job.roots.map (csimpTarget env)
  let source ← match generate env job.module roots pkg job.main? generatorVersion job.internalOnly with
    | .ok source => pure source
    | .error e => return ← failed 254 e
  match job.outputFile with
  | none => IO.print source
  | some path =>
    if let some dir := path.parent then IO.FS.createDirAll dir
    IO.FS.writeFile path source
  return (Json.mkObj [("module", mod), ("package", pkg)], 0)

def fail (code : UInt32) (msg : String) : IO UInt32 := do
  IO.eprintln s!"leanfran-go: {msg}"
  return code

unsafe def moduleGenerate (o : Opts) : IO UInt32 := do
  let jobs ← match o.batch with
    | some file =>
      if o.moduleName.isSome || !o.roots.isEmpty || o.namespace?.isSome || o.package?.isSome ||
          o.main?.isSome || o.outputFile.isSome || o.outputDir.isSome || !o.typeModules.isEmpty then
        return ← fail 252 "put module and output options in the batch jobs"
      match Json.parse (← IO.FS.readFile file) >>= (parseJobs · o.internalOnly) with
      | .ok jobs => pure jobs
      | .error e => return ← fail 252 s!"--batch: {e}"
    | none =>
      let some module := o.moduleName | return ← fail 252 "--module-name is required"
      pure #[{ o.toJobOpts with module : Job }]
  for job in jobs do
    if (job.typeModules.map Prod.fst).toList.eraseDups.length != job.typeModules.size then
      return ← fail 252 "duplicate type module namespace"
    if job.outputDir.isSome && (job.outputFile.isSome || job.internalOnly || job.main?.isSome) then
      return ← fail 252 "--output-dir requires a public library package"
    if job.outputDir.isNone && !job.typeModules.isEmpty then
      return ← fail 252 "--type-module requires --output-dir"
  initSearchPath (← findSysroot) o.searchPath.toList
  let searchPath ← searchPathRef.get
  let mods := (jobs.map (·.module) ++ o.imports).foldl (fun a m => if a.contains m then a else a.push m) #[]
  for m in mods do
    if (← searchPath.findWithExt "olean" m).isNone then
      return ← fail 252 s!"module not found: {m}"
  let publicOutput := jobs.any (·.outputDir.isSome)
  if publicOutput then enableInitializersExecution
  let env ← importModules (mods.map fun m => { module := m }) {} (trustLevel := 1024) (loadExts := publicOutput)
  let mut code : UInt32 := 0
  let mut summaries := #[]
  for job in jobs do
    let (summary, status) ← runJob env job
    summaries := summaries.push summary
    if code == 0 then code := status
  if o.batch.isSome && o.output == "json" then
    IO.println (Json.arr summaries).compress
  else
    for summary in summaries do printSummary o summary (o.batch.isNone && o.outputFile.isNone && o.outputDir.isNone)
  return code

unsafe def checkObligations (args : List String) : IO UInt32 := do
  let modules := args.takeWhile (! ·.startsWith "--")
  if modules.isEmpty then return ← fail 252 "--modules requires at least one name"
  let ["--obligations", file] := args.drop modules.length
    | return ← fail 252 "expected --modules <Name> ... --obligations <file>"
  let refs ← match Json.parse (← IO.FS.readFile file) >>= parseObligations with
    | .ok refs => pure refs
    | .error message => return ← fail 252 s!"{file}: {message}"
  enableInitializersExecution
  initSearchPath (← findSysroot)
  let names := modules.toArray.map String.toName
  let searchPath ← searchPathRef.get
  for m in names do
    if (← searchPath.findWithExt "olean" m).isNone then
      return ← fail 252 s!"module not found: {m}"
  let env ← importModules (names.map fun m => { module := m }) {} (loadExts := true)
  let ctx : Core.Context := { fileName := file, fileMap := default, maxHeartbeats := 0 }
  let (results, _) ← ((refs.mapM checkObligation).run').toIO ctx { env }
  IO.println (Json.arr results).compress
  return 0

unsafe def main (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println version; return 0
  | ["--generator-version"] => IO.println generatorVersion; return 0
  | ["--lean-version"] => IO.println Lean.versionString; return 0
  | [] | ["help"] | ["--help"] | ["module", "generate", "--help"] => IO.print usage; return 0
  | "module" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try moduleGenerate o
      catch e => fail 255 (toString e)
  | ["obligations", "check", "--help"] => IO.print usage; return 0
  | "obligations" :: "check" :: "--modules" :: rest =>
    try checkObligations rest
    catch e => fail 255 (toString e)
  | _ => fail 252 "unknown command (see leanfran-go help)"
