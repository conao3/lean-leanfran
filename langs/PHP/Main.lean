import LeanPhp

open Lean LeanPhp

def defaultRoots (env : Environment) (mod : Name) : Array Name := Id.run do
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
    if isPrivateName c || c.isInternalDetail || isAuxRecursor env c then continue
    if instances.contains c || instances.contains c.getPrefix then continue
    if (declRangeExt.find? (level := .exported) env c).isNone then continue
    if (IR.findEnvDecl env c).isSome then out := out.push c
  return out

def version : String := "0.6.0"
def generatorVersion : String := "2"

def usage : String := "usage: leanfran-php [--version] [--generator-version] <command> <subcommand> [parameters]

leanfran-php module generate
  --module-name <Name>        Lean module to import (required unless --batch)
  --roots <Name> ...          Roots (default: the module's public definitions)
  --namespace <Name>          Namespace for public wrappers (reserved for public API generation)
  --class <NS\\Name>           Generated class (default: Leanfran\\Generated\\Lean<Module>)
  --main <Name>               Generate a CLI entry point
  --batch <file>              JSON array of jobs with module, output_file, roots?, namespace?, class?, main?
  --import <Name> ...         More modules to import
  --search-path <dir> ...     Extra .olean search directories
  --output-file <path>        Output path (default: stdout)
  --internal-only             Emit only the runtime-facing class
  --output json|text          Format of the summary (default: json)

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"

structure JobOpts where
  roots : Array Name := #[]
  namespace? : Option Name := none
  class? : Option String := none
  main? : Option Name := none
  outputFile : Option System.FilePath := none

structure Opts extends JobOpts where
  moduleName : Option Name := none
  batch : Option System.FilePath := none
  searchPath : Array System.FilePath := #[]
  output : String := "json"
  imports : Array Name := #[]

partial def parseOpts (args : List String) (o : Opts) : Except String Opts := do
  let some (flag, rest) := args.head?.map (·, args.tail) | return o
  let isValue := fun (s : String) => !s.isEmpty && !s.startsWith "--"
  if flag == "--internal-only" then return ← parseOpts rest o
  if flag == "--roots" || flag == "--import" || flag == "--search-path" then
    let vs := (rest.takeWhile isValue).toArray
    if vs.isEmpty then throw s!"expected at least one value for {flag}"
    let o := match flag with
      | "--roots" => { o with roots := o.roots ++ vs.map String.toName }
      | "--import" => { o with imports := o.imports ++ vs.map String.toName }
      | _ => { o with searchPath := o.searchPath ++ vs.map System.FilePath.mk }
    return ← parseOpts (rest.drop vs.size) o
  unless #["--module-name", "--namespace", "--class", "--main", "--batch", "--output-file", "--output"].contains flag do
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
  | _ =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else throw s!"--output must be json or text: {v}"

def fail (code : UInt32) (msg : String) : IO UInt32 := do
  IO.eprintln s!"leanfran-php: {msg}"
  return code

structure Job extends JobOpts where
  module : Name

def phpIdentifier (s : String) : Bool :=
  let start := fun (c : Char) => c.isAlpha || c == '_' || c.toNat >= 128
  match s.toList with
  | [] => false
  | c :: cs => start c && cs.all (fun c => start c || c.isDigit)

def reservedClasses : List String :=
  ("__class__ __dir__ __file__ __function__ __halt_compiler __line__ __method__ __namespace__ " ++
    "__property__ __trait__ abstract and array as bool break callable case catch class clone const continue declare " ++
    "default die do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile eval exit " ++
    "extends false final finally float fn for foreach function global goto if implements include include_once " ++
    "instanceof insteadof int interface isset list match mixed namespace never new null object or parent print " ++
    "private protected public readonly require require_once return self static string switch throw " ++
    "trait true try unset use var void while xor yield iterable").splitOn " "

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

def header (mod : Name) (cls : PhpClass) : String :=
  let moduleLabel := (toString mod).replace "\n" "\\n" |>.replace "\r" "\\r" |>.replace "?>" "? >"
  let ns := if cls.ns.isEmpty then "" else s!"namespace {cls.ns};\n\n"
  "<?php\n" ++ s!"// Generated by leanfran-php (generator {generatorVersion}) from {moduleLabel}. Do not edit.\n\n"
    ++ "declare(strict_types=1);\n\n" ++ ns ++ "use Conao3\\Leanfran\\Runtime as L;\n\n"
    ++ s!"final class {cls.name}\n\{\n"

def runJob (env : Environment) (job : Job) : IO (Json × UInt32) := do
  let failed (code : UInt32) (msg : String) : IO (Json × UInt32) :=
    return (Json.mkObj [("module", toString job.module), ("error", msg), ("code", code.toNat)], code)
  let cls ← match jobClass job with
    | .ok cls => pure cls
    | .error e => return ← failed 252 e
  let roots := if job.roots.isEmpty then defaultRoots env job.module else job.roots
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
    | .error _ => out s!"{mod}: class {(j.getObjValD "class").getStr?.toOption.getD ""}, {j.getObjValD "functions"} functions, {j.getObjValD "externs"} externs"

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
    let outputFile : Option System.FilePath := some (← e.getObjValAs? String "output_file")
    return { module, roots, namespace?, class?, main?, outputFile }

def importAll (o : Opts) (mods : Array Name) : IO (Except Name Environment) := do
  initSearchPath (← findSysroot) o.searchPath.toList
  let sp ← searchPathRef.get
  for m in mods do
    if (← sp.findWithExt "olean" m).isNone then return .error m
  .ok <$> importModules (mods.map fun m => { module := m }) {} (trustLevel := 1024)

def moduleGenerate (o : Opts) : IO UInt32 := do
  let jobs ← match o.batch with
    | some f =>
      if o.moduleName.isSome || !o.roots.isEmpty || o.namespace?.isSome || o.class?.isSome ||
          o.main?.isSome || o.outputFile.isSome then
        return ← fail 252 "put module, roots, namespace, class, main and output_file in the batch jobs"
      match Json.parse (← IO.FS.readFile f) >>= parseJobs with
      | .ok js => pure js
      | .error e => return ← fail 252 s!"--batch: {e}"
    | none =>
      let some module := o.moduleName | return ← fail 252 "--module-name is required"
      pure #[{ o.toJobOpts with module : Job }]
  let mods := (jobs.map (·.module) ++ o.imports).foldl (fun a m => if a.contains m then a else a.push m) #[]
  let env ← match ← importAll o mods with
    | .ok env => pure env
    | .error m => return ← fail 252 s!"module not found: {m}"
  let mut code : UInt32 := 0
  let mut summaries := #[]
  for job in jobs do
    let (j, c) ← runJob env job
    summaries := summaries.push j
    if c != 0 && code == 0 then code := c
  if o.batch.isSome && o.output == "json" then IO.println (Json.arr summaries).compress
  else for j in summaries do printSummary o (o.batch.isNone && o.outputFile.isNone) j
  return code

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println version; return 0
  | ["--generator-version"] => IO.println generatorVersion; return 0
  | [] | ["help"] | ["--help"] | "module" :: "help" :: _
  | ["module", "generate", "--help"] => IO.print usage; return 0
  | "module" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => fail 252 e
    | .ok o =>
      try moduleGenerate o
      catch e => fail 255 (toString e)
  | _ => fail 252 "unknown command (see leanfran-php help)"
