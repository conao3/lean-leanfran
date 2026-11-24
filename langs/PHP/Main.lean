import LeanPhp
import LeanPhp.Check

open Lean LeanPhp

def defaultRoots (env : Environment) (mod : Name) (includePrivate := false) : Array Name := Id.run do
  let some idx := env.getModuleIdx? mod | return #[]
  let mut instances : Std.HashSet Name := {}
  for i in [0:env.header.moduleNames.size] do
    for e in Meta.instanceExtension.ext.getModuleEntries env i do
      let entry := match e with
        | .global entry | .scoped _ entry => entry
      if let some n := entry.globalName? then
        instances := instances.insert n
  let mut out := #[]
  for c in env.header.moduleData[idx.toNat]!.constNames do
    if !includePrivate && isPrivateName c then continue
    if (privateToUserName c).isInternalDetail || isAuxRecursor env c then continue
    if instances.contains c || instances.contains c.getPrefix then continue
    let defined := (declRangeExt.find? (level := .exported) env c).isSome ||
      (includePrivate && (declRangeExt.find? (level := .server) env c).isSome)
    if !defined then continue
    if (IR.findEnvDecl env c).isSome then out := out.push c
  return out

def version : String := "0.11.0"
def generatorVersion : String := "7"

def usage : String := "usage: leanfran-php [--version] [--generator-version] <command> <subcommand> [parameters]

leanfran-php module generate
  --module-name <Name>        Lean module to import (required unless --batch)
  --roots <Name> ...          Roots (default: the module's public definitions)
  --namespace <Name>          Lean namespace removed from public names (default: module)
  --output-dir <path>         Generate public PSR-4 classes in this directory
  --php-namespace <NS>        Namespace of the public classes (required with --output-dir)
  --facade <Name>             Public facade class (default: last component of the Lean module)
  --facade-kind class|trait   Public facade declaration (default: class)
  --type-module <N=NS>        Refer to public types generated in another PHP namespace (repeatable)
  --class <NS\\Name>           Generated class (default: Leanfran\\Generated\\Lean<Module>)
  --main <Name>               Generate a CLI entry point
  --batch <file>              JSON array of jobs with module and output_file or output_dir
                              Public jobs accept php_namespace, facade, facade_kind, type_modules and models
  --import <Name> ...         More modules to import
  --search-path <dir> ...     Extra .olean search directories
  --output-file <path>        Output path (default: stdout)
  --internal-only             Emit only the runtime-facing class
  --output json|text          Format of the summary (default: json)

leanfran-php obligations check --modules <Name> ... --obligations <file>

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"

structure JobOpts where
  roots : Array Name := #[]
  namespace? : Option Name := none
  class? : Option String := none
  main? : Option Name := none
  outputFile : Option System.FilePath := none
  outputDir : Option System.FilePath := none
  phpNamespace : Option String := none
  facade : Option String := none
  facadeKind : Option FacadeKind := none
  typeModules : Array (Name × String) := #[]
  models : Array String := #[]
  internalOnly : Bool := false

structure Opts extends JobOpts where
  moduleName : Option Name := none
  batch : Option System.FilePath := none
  searchPath : Array System.FilePath := #[]
  output : String := "json"
  imports : Array Name := #[]

partial def parseOpts (args : List String) (o : Opts) : Except String Opts := do
  let some (flag, rest) := args.head?.map (·, args.tail) | return o
  let isValue := fun (s : String) => !s.isEmpty && !s.startsWith "--"
  if flag == "--internal-only" then return ← parseOpts rest { o with internalOnly := true }
  if flag == "--roots" || flag == "--import" || flag == "--search-path" then
    let vs := (rest.takeWhile isValue).toArray
    if vs.isEmpty then throw s!"expected at least one value for {flag}"
    let o := match flag with
      | "--roots" => { o with roots := o.roots ++ vs.map String.toName }
      | "--import" => { o with imports := o.imports ++ vs.map String.toName }
      | _ => { o with searchPath := o.searchPath ++ vs.map System.FilePath.mk }
    return ← parseOpts (rest.drop vs.size) o
  unless #["--module-name", "--namespace", "--class", "--main", "--batch", "--output-file",
      "--output-dir", "--php-namespace", "--facade", "--facade-kind", "--type-module", "--output"].contains flag do
    throw s!"unknown parameter: {flag}"
  let v :: rest := rest | throw s!"expected a value for {flag}"
  unless isValue v do throw s!"expected a value for {flag}"
  match flag with
  | "--module-name" => parseOpts rest { o with moduleName := v.toName }
  | "--namespace" => parseOpts rest { o with namespace? := v.toName }
  | "--class" => parseOpts rest { o with class? := some v }
  | "--main" => parseOpts rest { o with main? := v.toName }
  | "--batch" => parseOpts rest { o with batch := some v }
  | "--output-file" => parseOpts rest { o with outputFile := some v }
  | "--output-dir" => parseOpts rest { o with outputDir := some v }
  | "--php-namespace" => parseOpts rest { o with phpNamespace := some v }
  | "--facade" => parseOpts rest { o with facade := some v }
  | "--facade-kind" => parseOpts rest { o with facadeKind := some (← FacadeKind.parse v) }
  | "--type-module" =>
    match v.splitOn "=" with
    | [n, ns] =>
      if n.isEmpty || ns.isEmpty then throw "--type-module expects LeanName=PhpNamespace"
      let n := n.toName
      if o.typeModules.any (·.1 == n) then throw s!"duplicate --type-module for {n}"
      parseOpts rest { o with typeModules := o.typeModules.push (n, ns) }
    | _ => throw "--type-module expects LeanName=PhpNamespace"
  | _ =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else throw s!"--output must be json or text: {v}"

def fail (code : UInt32) (msg : String) : IO UInt32 := do
  IO.eprintln s!"leanfran-php: {msg}"
  return code

structure Job extends JobOpts where
  module : Name

structure PhpClass where
  ns : String
  name : String

def jobClass (job : Job) : Except String PhpClass := do
  match job.class? with
  | none =>
    let cls := "Lean" ++ "_".intercalate ((toString job.module).splitOn ".")
    return { ns := "Leanfran\\Generated", name := if phpIdentifier cls then cls else job.module.mangle "Lean" }
  | some cls =>
    let parts := ((if cls.startsWith "\\" then cls.drop 1 else cls.toSlice).toString).splitOn "\\"
    let name := parts.getLast!
    if !parts.all phpIdentifier || parts.head!.toLower == "namespace" || reservedClasses.contains name.toLower then
      throw s!"invalid PHP class name: {cls}"
    if name.toLower == "l" then throw s!"PHP class name conflicts with the runtime alias L: {cls}"
    return { ns := "\\".intercalate parts.dropLast, name }

def publicMarker : String := "<?php // Generated by leanfran-php "

def header (mod : Name) (cls : PhpClass) (publicOutput := false) : String :=
  let moduleLabel := (toString mod).replace "\n" "\\n" |>.replace "\r" "\\r" |>.replace "?>" "? >"
  let ns := if cls.ns.isEmpty then "" else s!"namespace {cls.ns};\n\n"
  (if publicOutput then "<?php " else "<?php\n") ++ s!"// Generated by leanfran-php (generator {generatorVersion}) from {moduleLabel}. Do not edit.\n\n"
    ++ "declare(strict_types=1);\n\n" ++ ns ++ "use Conao3\\Leanfran\\Runtime as L;\n\n"
    ++ s!"final class {cls.name}\n\{\n"

def validNamespace (ns : String) : Bool :=
  let parts := ns.splitOn "\\"
  parts.all phpIdentifier && parts.head!.toLower != "namespace"

def moduleTypes (env : Environment) (mod : Name) : Array Name := Id.run do
  let some idx := env.getModuleIdx? mod | return #[]
  let mut types := #[]
  for c in env.header.moduleData[idx.toNat]!.constNames do
    if c.isInternalDetail && !isPrivateName c then continue
    if (declRangeExt.find? (level := .exported) env c).isNone && !isPrivateName c then continue
    match env.find? c with
    | some (.inductInfo info) =>
      if info.numParams == 0 || info.numIndices != 0 || isClass env c then
        types := types.push c
    | some (.defnInfo info) =>
      if info.type.isSort && info.value.getAppFn.constName? == some ``Subtype then
        types := types.push c
    | _ => pure ()
  return types

def publicHeader (mod : Name) (ns : String) : String :=
  let label := (toString mod).replace "\n" "\\n" |>.replace "\r" "\\r" |>.replace "?>" "? >"
  publicMarker ++ s!"(generator {generatorVersion}) from {label}. Do not edit.\n\ndeclare(strict_types=1);\n\nnamespace {ns};\n\n"

def generatedFiles (dir : System.FilePath) : IO (Array System.FilePath) := do
  if !(← dir.pathExists) then return #[]
  unless (← dir.symlinkMetadata).type == .dir do
    throw (IO.userError s!"expected an output directory: {dir}")
  let mut paths := #[]
  for e in ← dir.readDir do
    if e.path.extension == some "php" && (← e.path.symlinkMetadata).type == .file then
      let h ← IO.FS.Handle.mk e.path .read
      if (← h.getLine).startsWith publicMarker then paths := paths.push e.path
  return paths

def writePublic (dir : System.FilePath) (files : Array (String × String)) : IO Unit := do
  let old ← (· ++ ·) <$> generatedFiles dir <*> generatedFiles (dir / "Internal")
  let paths := files.map fun (f, _) => dir / f
  for path in paths do
    let metadata ← try some <$> path.symlinkMetadata catch
      | .noFileOrDirectory .. => pure none
      | e => throw e
    if metadata.isSome && !old.contains path then
      throw (IO.userError s!"refusing to overwrite a non-generated file: {path}")
  IO.FS.createDirAll (dir / "Internal")
  for ((_, src), path) in files.zip paths do
    IO.FS.writeFile path src
  for path in old do
    unless paths.contains path do IO.FS.removeFile path

def runPublic (env : Environment) (job : Job) (dir : System.FilePath) (roots : Array Name) :
    IO (Except (UInt32 × String) Json) := do
  if job.outputFile.isSome || job.internalOnly || job.class?.isSome || job.main?.isSome then
    return .error (252, "--output-dir cannot be combined with --output-file, --internal-only, --class or --main")
  let some ns := job.phpNamespace | return .error (252, "--php-namespace is required with --output-dir")
  unless validNamespace ns && job.typeModules.all (validNamespace ∘ Prod.snd) do
    return .error (252, "invalid PHP namespace")
  let facadeBase := job.facade.getD (phpIdent (sanitize (componentString job.module)))
  unless phpIdentifier facadeBase do
    return .error (252, s!"invalid PHP facade class name: {facadeBase}")
  let facade := phpIdent facadeBase
  let kind := job.facadeKind.getD .cls
  let internalName := "Lean" ++ (if kind == .trait then (ns.splitOn "\\").getLast!
    else "_".intercalate (job.module.components.map fun n => sanitize (componentString n)))
  let cls : PhpClass := { ns := ns ++ "\\Internal", name := internalName }
  let internal := "\\" ++ cls.ns ++ "\\" ++ cls.name
  let typeModules := job.typeModules.qsort (fun a b => a.1.components.length > b.1.components.length)
  unless job.models.all validNamespace do
    return .error (252, "invalid PHP model class name")
  let models := job.models.foldl (fun out cls =>
    let name := (cls.splitOn "\\").foldl Name.str `LeanPhpModels
    out.insert name cls) ({} : Std.HashMap Name String)
  let cfg : MarshalCfg := { strip := job.namespace?.getD job.module, typeModules, models }
  let types := if job.roots.isEmpty then moduleTypes env job.module else #[]
  let (pub, env) ← inspectPublic env cfg types roots facade
  if let some clash := pub.skipped.find? (·.reason.startsWith collisionLabel) then
    return .error (254, clash.reason)
  let targets := pub.functions.map (·.target.name) ++ pub.state.deciders
  let out ← match generate env job.module targets none with
    | .ok out => pure out
    | .error e => return .error (254, e)
  let render : RenderCfg := { ns, internal, state := pub.state, methods := out.methods, env }
  let types ← match pub.state.types.mapM (emitType render) with
    | .ok types => pure types
    | .error e => return .error (254, e)
  let typeFiles := (types.flatMap (·.1)).map fun (path, src) => (path, publicHeader job.module ns ++ src)
  let descs := String.join (pub.state.types.toList.map (emitDescriptor render))
  let constructors := String.join (types.toList.map (·.2))
  let results := String.join (pub.functions.toList.map (emitResult render))
  let methods := "\n".intercalate (pub.functions.toList.map (emitPublicFn render))
  let facadeFile := (facade ++ ".php", publicHeader job.module ns ++
    s!"{kind.declaration} {facade}\n\{\n{methods}}\n")
  let internalFile := ("Internal/" ++ cls.name ++ ".php", header job.module cls true ++ out.items ++ descs ++ constructors ++ results ++ "}\n")
  let files := typeFiles ++ #[facadeFile, internalFile]
  writePublic dir files
  let paths := files.map fun (path, _) => (dir / path).toString
  let skipped := pub.skipped.map fun s => Json.mkObj [("name", (privateToUserName s.name).toString), ("reason", s.reason)]
  return .ok (Json.mkObj [("module", toString job.module), ("class", ns ++ "\\" ++ facade),
    ("functions", out.functions), ("externs", out.externs), ("files", toJson paths), ("skipped", toJson skipped)])

def runJob (env : Environment) (job : Job) : IO (Json × UInt32) := do
  let failed (code : UInt32) (msg : String) : IO (Json × UInt32) :=
    return (Json.mkObj [("module", toString job.module), ("error", msg), ("code", code.toNat)], code)
  let roots := if job.roots.isEmpty then defaultRoots env job.module job.outputDir.isSome else job.roots
  if let some dir := job.outputDir then
    match ← runPublic env job dir roots with
    | .ok summary => return (summary, 0)
    | .error (code, e) => return ← failed code e
  if job.phpNamespace.isSome || job.facade.isSome || job.facadeKind.isSome || !job.typeModules.isEmpty then
    return ← failed 252 "--php-namespace, --facade, --facade-kind and --type-module require --output-dir"
  let cls ← match jobClass job with
    | .ok cls => pure cls
    | .error e => return ← failed 252 e
  match generate env job.module roots job.main? with
  | .error e => failed 254 e
  | .ok out =>
    let qualified := if cls.ns.isEmpty then cls.name else cls.ns ++ "\\" ++ cls.name
    let launch := if job.main?.isNone then "" else
      "\nif (\\PHP_SAPI === 'cli' && isset($_SERVER['SCRIPT_FILENAME']) && \\realpath($_SERVER['SCRIPT_FILENAME']) === __FILE__) {\n"
        ++ s!"    exit(\\{qualified}::runMain(\\array_slice($_SERVER['argv'], 1)));\n}\n"
    let src := header job.module cls ++ out.items ++ "}\n" ++ launch
    match job.outputFile with
    | none => IO.print src
    | some p =>
      if let some dir := p.parent then IO.FS.createDirAll dir
      IO.FS.writeFile p src
    return (Json.mkObj [("module", toString job.module), ("class", qualified), ("functions", out.functions),
      ("externs", out.externs)], 0)

def printSummary (o : Opts) (toStderr : Bool) (j : Json) : IO Unit := do
  let out := if toStderr || (j.getObjVal? "error").isOk then IO.eprintln else IO.println
  if o.output == "json" then out j.compress
  else
    let mod := (j.getObjValD "module").getStr?.toOption.getD ""
    match (j.getObjValD "error").getStr? with
    | .ok e => out s!"leanfran-php: {mod}: {e}"
    | .error _ =>
      out s!"{mod}: class {(j.getObjValD "class").getStr?.toOption.getD ""}, {j.getObjValD "functions"} functions, {j.getObjValD "externs"} externs"
      if let .ok files := (j.getObjValD "files").getArr? then
        for file in files do out (file.getStr?.toOption.getD "")
      if let .ok skipped := (j.getObjValD "skipped").getArr? then
        for item in skipped do
          let name := (item.getObjValD "name").getStr?.toOption.getD ""
          let reason := (item.getObjValD "reason").getStr?.toOption.getD ""
          IO.eprintln s!"leanfran-php: skipped {name}: {reason}"

def optionalField [FromJson α] (j : Json) (key : String) : Except String (Option α) :=
  match j.getObjVal? key with
  | .ok v => some <$> fromJson? v
  | .error _ => .ok none

def parseJobs (j : Json) : Except String (Array Job) := do
  let jobs ← j.getArr?
  jobs.mapM fun e => do
    let module := (← e.getObjValAs? String "module").toName
    let roots := (← optionalField (α := Array String) e "roots").getD #[] |>.map String.toName
    let namespace? := (← optionalField (α := String) e "namespace").map String.toName
    let class? ← optionalField (α := String) e "class"
    let main? := (← optionalField (α := String) e "main").map String.toName
    let outputFile := (← optionalField (α := String) e "output_file").map System.FilePath.mk
    let outputDir := (← optionalField (α := String) e "output_dir").map System.FilePath.mk
    unless outputFile.isSome != outputDir.isSome do
      throw s!"{module}: expected exactly one of output_file or output_dir"
    let phpNamespace ← optionalField (α := String) e "php_namespace"
    let facade ← optionalField (α := String) e "facade"
    let facadeKind ← (← optionalField (α := String) e "facade_kind").mapM FacadeKind.parse
    let foreign := (← optionalField (α := Array Json) e "type_modules").getD #[]
    let typeModules ← foreign.mapM fun item => do
      let ns := (← item.getObjValAs? String "namespace").toName
      let phpNs ← item.getObjValAs? String "php_namespace"
      pure (ns, phpNs)
    let models := (← optionalField (α := Array String) e "models").getD #[]
    unless models.isEmpty || outputDir.isSome do throw s!"{module}: models require output_dir"
    return { module, roots, namespace?, class?, main?, outputFile, outputDir, phpNamespace, facade, facadeKind, typeModules, models }

def importAll (o : Opts) (mods : Array Name) (publicOutput : Bool) : IO (Except Name Environment) := do
  initSearchPath (← findSysroot) o.searchPath.toList
  let sp ← searchPathRef.get
  for m in mods do
    if (← sp.findWithExt "olean" m).isNone then return .error m
  .ok <$> importModules (mods.map fun m => { module := m }) {} (trustLevel := 1024)
    (loadExts := publicOutput)

unsafe def moduleGenerate (o : Opts) : IO UInt32 := do
  let jobs ← match o.batch with
    | some f =>
      if o.moduleName.isSome || !o.roots.isEmpty || o.namespace?.isSome || o.class?.isSome ||
          o.main?.isSome || o.outputFile.isSome || o.outputDir.isSome || o.phpNamespace.isSome ||
          o.facade.isSome || o.facadeKind.isSome || !o.typeModules.isEmpty then
        return ← fail 252 "put module and output options in the batch jobs"
      match Json.parse (← IO.FS.readFile f) >>= parseJobs with
      | .ok js => pure js
      | .error e => return ← fail 252 s!"--batch: {e}"
    | none =>
      let some module := o.moduleName | return ← fail 252 "--module-name is required"
      pure #[{ o.toJobOpts with module : Job }]
  let mods := (jobs.map (·.module) ++ o.imports).foldl (fun a m => if a.contains m then a else a.push m) #[]
  let publicOutput := jobs.any (·.outputDir.isSome)
  if publicOutput then enableInitializersExecution
  let env ← match ← importAll o mods publicOutput with
    | .ok env => pure env
    | .error m => return ← fail 252 s!"module not found: {m}"
  let mut code : UInt32 := 0
  let mut summaries := #[]
  for job in jobs do
    let (j, c) ← runJob env job
    summaries := summaries.push j
    if c != 0 && code == 0 then code := c
  if o.batch.isSome && o.output == "json" then IO.println (Json.arr summaries).compress
  else for j in summaries do printSummary o (o.batch.isNone && o.outputFile.isNone && o.outputDir.isNone) j
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
  match ← importAll {} (modules.toArray.map String.toName) true with
  | .error name => fail 252 s!"module not found: {name}"
  | .ok env =>
    let ctx : Core.Context := { fileName := file, fileMap := default, maxHeartbeats := 0 }
    let (results, _) ← ((refs.mapM checkObligation).run').toIO ctx { env }
    IO.println (Json.arr results).compress
    return 0

unsafe def main (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println version; return 0
  | ["--generator-version"] => IO.println generatorVersion; return 0
  | [] | ["help"] | ["--help"] | "module" :: "help" :: _
  | ["module", "generate", "--help"] | ["obligations", "check", "--help"] => IO.print usage; return 0
  | "module" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try moduleGenerate o
      catch e => fail 255 (toString e)
  | "obligations" :: "check" :: "--modules" :: rest =>
    try checkObligations rest
    catch e => fail 255 (toString e)
  | _ => fail 252 "unknown command (see leanfran-php help)"
