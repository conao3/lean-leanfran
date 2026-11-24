import LeanGo

open Lean LeanGo

def version : String := "0.7.0"
def generatorVersion : String := "1"

def usage : String := "leanfran-go --version | --generator-version
leanfran-go module generate --module-name <Name> [options]

  --roots <Name> ...          Lean definitions to compile
  --namespace <Name>          Limit default roots to this Lean namespace
  --import <Name> ...         More modules to import
  --search-path <dir> ...     Extra .olean search directories
  --package <name>            Generated Go package name
  --main <Name>               Generate an executable Go package
  --internal-only             Generate runtime-facing functions
  --output-file <path>        Output path (default: stdout)
  --output json|text          Summary format (default: json)
  --batch <file>              JSON array of jobs with module and output_file

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"

structure JobOpts where
  roots : Array Name := #[]
  namespace? : Option Name := none
  package? : Option String := none
  main? : Option Name := none
  outputFile : Option System.FilePath := none
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
      "--output"].contains flag do
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
  | _ =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else throw s!"--output must be json or text: {v}"

def optionalField [FromJson α] (j : Json) (key : String) : Except String (Option α) :=
  match j.getObjVal? key with
  | .ok v => some <$> fromJson? v
  | .error _ => .ok none

def parseJobs (j : Json) (internalOnly : Bool) : Except String (Array Job) := do
  let jobs ← j.getArr?
  if jobs.isEmpty then throw "expected at least one job"
  jobs.mapM fun e => do
    let module := (← e.getObjValAs? String "module").toName
    let roots := (← optionalField (α := Array String) e "roots").getD #[] |>.map String.toName
    let namespace? := (← optionalField (α := String) e "namespace").map String.toName
    let package? ← optionalField (α := String) e "package"
    let main? := (← optionalField (α := String) e "main").map String.toName
    let outputFile := some (System.FilePath.mk (← e.getObjValAs? String "output_file"))
    let internalOnly := (← optionalField (α := Bool) e "internal_only").getD internalOnly
    return { module, roots, namespace?, package?, main?, outputFile, internalOnly }

def goPackage (job : Job) : Except String String := do
  let pkg := if job.main?.isSome then "main" else
    job.package?.getD ((toString job.module).replace "." "" |>.toLower)
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

def printSummary (o : Opts) (summary : Json) (toStderr : Bool) : IO Unit := do
  let print := if toStderr || (summary.getObjVal? "error").isOk then IO.eprintln else IO.println
  if o.output == "json" then print summary.compress
  else
    let mod := (summary.getObjValD "module").getStr?.toOption.getD ""
    match (summary.getObjValD "error").getStr? with
    | .ok e => print s!"leanfran-go: {mod}: {e}"
    | .error _ => print s!"{mod}: package {(summary.getObjValD "package").getStr?.toOption.getD ""}"

def runJob (env : Environment) (job : Job) : IO (Json × UInt32) := do
  let mod := toString job.module
  let failed (code : UInt32) (msg : String) : IO (Json × UInt32) :=
    pure (Json.mkObj [("module", mod), ("error", msg), ("code", code.toNat)], code)
  let pkg ← match goPackage job with
    | .ok name => pure name
    | .error e => return ← failed 252 e
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

def moduleGenerate (o : Opts) : IO UInt32 := do
  let jobs ← match o.batch with
    | some file =>
      if o.moduleName.isSome || !o.roots.isEmpty || o.namespace?.isSome || o.package?.isSome ||
          o.main?.isSome || o.outputFile.isSome then
        return ← fail 252 "put module and output options in the batch jobs"
      match Json.parse (← IO.FS.readFile file) >>= (parseJobs · o.internalOnly) with
      | .ok jobs => pure jobs
      | .error e => return ← fail 252 s!"--batch: {e}"
    | none =>
      let some module := o.moduleName | return ← fail 252 "--module-name is required"
      pure #[{ o.toJobOpts with module : Job }]
  initSearchPath (← findSysroot) o.searchPath.toList
  let searchPath ← searchPathRef.get
  let mods := (jobs.map (·.module) ++ o.imports).foldl (fun a m => if a.contains m then a else a.push m) #[]
  for m in mods do
    if (← searchPath.findWithExt "olean" m).isNone then
      return ← fail 252 s!"module not found: {m}"
  let env ← importModules (mods.map fun m => { module := m }) {} (trustLevel := 1024)
  let mut code : UInt32 := 0
  let mut summaries := #[]
  for job in jobs do
    let (summary, status) ← runJob env job
    summaries := summaries.push summary
    if code == 0 then code := status
  if o.batch.isSome && o.output == "json" then
    IO.println (Json.arr summaries).compress
  else
    for summary in summaries do printSummary o summary (o.batch.isNone && o.outputFile.isNone)
  return code

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println version; return 0
  | ["--generator-version"] => IO.println generatorVersion; return 0
  | [] | ["help"] | ["--help"] | ["module", "generate", "--help"] => IO.print usage; return 0
  | "module" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try moduleGenerate o
      catch e => fail 255 (toString e)
  | _ => fail 252 "unknown command (see leanfran-go help)"
