import Lake
import Lake.Load.Workspace
import LeanC.Header
import LeanC.Check
import LeanC.Link
import LeanC.Schema

open Lean Lake System

namespace LeanC

structure Target where
  moduleName : String
  cPrefix : String
  jsonSupport : Bool := false
  deriving FromJson, ToJson

def validModule (name : String) : Bool :=
  (name.splitOn ".").all fun part =>
    part.toList.head?.any (fun c => c.isAlpha || c == '_') &&
      part.toList.all (fun c => c.isAlphanum || c == '_' || c == '\'')

def run (args : IO.Process.SpawnArgs) : IO String := do
  let output ← IO.Process.output args
  unless output.exitCode == 0 do
    throw <| IO.userError s!"{args.cmd} exited with {output.exitCode}\n{output.stdout}{output.stderr}"
  unless output.stderr.isEmpty do IO.eprint output.stderr
  return output.stdout

def loadWorkspace (dir : FilePath) : IO Workspace := do
  let version ← run {cmd := "lean", cwd := some dir, args := #["--version"]}
  let some actual := (version.splitOn "version ")[1]?.map (fun s => (s.splitOn ",").head!)
    | throw <| IO.userError s!"could not read Lean version: {version.trimAscii}"
  unless actual == Lean.versionString do
    throw <| IO.userError s!"leanfran-c was built with Lean {Lean.versionString}, found Lean {actual}"
  let sysroot ← run {cmd := "lean", cwd := some dir, args := #["--print-prefix"]}
  let lean ← Lake.LeanInstall.get ⟨sysroot.trimAscii.toString⟩
  let lakeEnv ← (Lake.Env.compute (Lake.LakeInstall.ofLean lean) lean (← Lake.findElanInstall?))
    |>.adapt IO.userError
  let some ws ← (Lake.loadWorkspace {lakeEnv, wsDir := dir}).toBaseIO
    | throw <| IO.userError "could not load Lake workspace"
  return ws

def findModule (ws : Workspace) (target : Target) : IO Lake.Module := do
  let some mod := ws.findModule? target.moduleName.toName
    | throw <| IO.userError s!"Lake cannot find module '{target.moduleName}'"
  return mod

def exportPath (target : Target) (dir : FilePath) : FilePath :=
  Lean.modToFilePath dir (exportModule target.moduleName.toName) "lean"

structure Checks where
  allowSorry : Bool := false
  allowLeanImport : Bool := false

private def missingExterns (lean : LeanInstall) (externs : Std.HashSet String) :
    IO (Array String) := do
  if externs.isEmpty then return #[]
  let libs : Array FilePath := #["libleanrt.a", "libInit.a", "libStd.a"]
  let symbols ← run {cmd := "nm", args := #["-P", "-g"] ++ libs.map (lean.leanLibDir / · |>.toString)}
  let mut missing := externs
  for line in symbols.splitOn "\n" do
    match (line.split Char.isWhitespace |>.toStringList).filter (!·.isEmpty) with
    | symbol :: kind :: _ =>
      if kind.length == 1 && kind != "U" && kind != "w" && kind != "v" then
        let name := if Platform.isOSX then (symbol.drop 1).toString else symbol
        missing := missing.erase name
    | _ => pure ()
  let header ← IO.FS.readFile (lean.includeDir / "lean" / "lean.h")
  for line in header.splitOn "\n" do
    if line.startsWith "static inline " then
      let declaration := (line.splitOn "(").head!.trimAscii.toString
      if let some name := (declaration.splitOn " ").getLast? then
        missing := missing.erase ((name.dropWhile (· == '*')).toString)
  return missing.toArray.qsort (· < ·)

private def selectExports (env : Environment) (moduleName : Name) (cPrefix : String)
    (roots : Array Name) (checks : Checks) (renames : Renames) : ExceptT String IO (Array Export × Array Desc) := do
  if let some chain := leanImportChain env moduleName then
    let message := s!"Lean compiler import: {" -> ".intercalate (chain.map Name.toString)}"
    unless checks.allowLeanImport do throw s!"{message} (use --allow-lean-import to allow)"
  let names := if roots.isEmpty then defaultRoots env moduleName else roots
  let mut exports := #[]
  let mut descs := #[]
  for name in names.qsort Name.lt do
    let read : MetaM (Except String (Export × Array Desc)) := do
      try
        return .ok (← (readExport cPrefix renames name).run descs)
      catch error =>
        return .error (← error.toMessageData.toString)
    let described ← ExceptT.lift <| read.run'.toIO' {fileName := "<C exports>", fileMap := default} {env}
    match described with
    | .error message =>
      if !roots.isEmpty || message.startsWith "C name collision:" || message.startsWith "C invariant:" then throw message
      IO.eprintln s!"leanfran-c: skipping {message}"
    | .ok (entry, types) =>
      exports := exports.push entry
      descs := types
  let mut claimed : Std.HashSet String := {}
  let reserved := [s!"{cPrefix}_init", s!"lf_{cPrefix}_initialize", s!"lf_{cPrefix}_nat_decimal",
    s!"lf_{cPrefix}_int_decimal", "init_error", "initialize_once"]
  let supportNames := ["LF_INLINE", "lf_error_clear", "lf_set_error", "lf_copy_string", "lf_copy_io_error",
    "lf_str_free", "lf_byte_array_free", "lf_byte_array_to_lean", "lf_byte_array_from_lean"]
  let integerNames := ["lf_nat_from_u64", "lf_nat_to_u64", "lf_nat_from_lean_u64",
    "lf_int_from_i64", "lf_int_to_i64", "lf_int_from_lean_i64"] ++
    ["lf_nat", "lf_int"].flatMap fun name =>
      ["free", "from_dec", "to_dec", "from_lean", "to_lean"].map fun suffix => s!"{name}_{suffix}"
  let typeNames := (descs.toList.flatMap fun d => d.names ++ d.deciderNames) ++
    (exportJsonApis cPrefix exports descs).toList.flatMap JsonApi.names
  let functionNames := exports.toList.flatMap fun e => [e.symbol, s!"lf_{e.symbol}"]
  for name in reserved ++ supportNames ++ integerNames ++ typeNames ++ functionNames do
    if claimed.contains name then throw s!"C name collision: {name}"
    claimed := claimed.insert name
  return (exports, descs)

private def reachableRoots (exports : Array Export) (descs : Array Desc) : Array Name :=
  let deciders := descs.flatMap (fun d => d.ctors.flatMap (·.invariants.flatMap (·.dependencies)))
  (deciders.foldl (init := ({} : Std.HashSet Name)) (·.insert ·)).toArray.qsort Name.lt ++
    exports.map (·.name)

private def checkSorry (env : Environment) (checks : Checks) (roots : Array Name) :
    ExceptT String IO Unit := do
  let sorryRoots ← roots.filterM (fun name => ExceptT.lift (usesSorry env name))
  if !sorryRoots.isEmpty then
    let names := ", ".intercalate (sorryRoots.toList.map fun name => s!"'{name}'")
    let message := s!"{names} depends on sorryAx"
    if checks.allowSorry then IO.eprintln s!"leanfran-c: warning: {message}"
    else throw s!"{message} (use --allow-sorry to allow)"

def jsonSupportSource : String := include_str "../lean/LeanfranC/Json.lean"

private def generateFiles (env : Environment) (lean : LeanInstall) (target : Target)
    (out : FilePath) (roots : Array Name) (checks : Checks) (renames : Renames)
    (projectInit : Bool) : ExceptT String IO (Array String) := do
  if projectInit then
    if let some idx := env.getModuleIdx? target.moduleName.toName then
      for info in env.header.moduleData[idx.toNat]!.constants do
        if info.type.hasSorry || (info.value? (allowOpaque := true)).any Expr.hasSorry then
          throw s!"'{info.name}' uses sorryAx"
  let (exports, descs) ← selectExports env target.moduleName.toName target.cPrefix roots checks renames
  let reachable := reachableRoots exports descs
  checkSorry env checks reachable
  let calls ← foreignCalls env reachable
  let externs ← missingExterns lean calls.externs
  let implementations := calls.implementations.map fun pair => s!"{pair.1} -> {pair.2}"
  let apis := exportJsonApis target.cPrefix exports descs
  let file := exportPath target out
  IO.FS.createDirAll file.parent.get!
  IO.FS.writeFile file (emitExportModule target.moduleName.toName target.cPrefix exports descs apis)
  IO.FS.writeFile (out / s!"{target.cPrefix}.h") (emitHeader target.cPrefix exports descs apis)
  IO.FS.writeFile (out / s!"{target.cPrefix}.c") (emitSource target.moduleName.toName target.cPrefix exports descs apis projectInit)
  IO.FS.writeFile (out / s!"{target.cPrefix}.schema.json") (emitSchema target.moduleName.toName target.cPrefix descs exports)
  IO.FS.writeFile (out / "leanfran.h") (include_str "../support/leanfran.h")
  IO.FS.writeFile (out / "leanfran.c") (include_str "../support/leanfran.c")
  let writeReport := fun suffix (lines : Array String) =>
    IO.FS.writeFile (out / s!"{target.cPrefix}.{suffix}.txt")
      (String.join (lines.toList.map (· ++ "\n")))
  writeReport "externs" externs
  writeReport "implemented-by" (implementations.qsort (· < ·))
  let jsonSupport := !apis.isEmpty
  if jsonSupport then
    IO.FS.createDirAll (out / "LeanfranC")
    IO.FS.writeFile (out / "LeanfranC" / "Json.lean") jsonSupportSource
  IO.FS.writeFile (out / "leanfran.json") ((toJson {target with jsonSupport}).compress ++ "\n")
  return #[s!"{target.cPrefix}_init", s!"lf_{target.cPrefix}_nat_decimal",
    s!"lf_{target.cPrefix}_int_decimal"] ++ (descs.toList.flatMap fun d => d.names ++ d.deciderNames).toArray ++
    (apis.toList.flatMap JsonApi.names).toArray ++
    exports.flatMap (fun entry => #[entry.symbol, s!"lf_{entry.symbol}"])

unsafe def generate (ws : Workspace) (target : Target) (out : FilePath) (roots : Array Name)
    (checks : Checks := {}) (renames : Renames := {}) (projectInit : Bool := false) :
    IO (Except String (Array String)) := do
  let mod ← findModule ws target
  discard <| ws.runBuild mod.olean.fetch
  Lean.initSearchPath ws.lakeEnv.lean.sysroot ws.leanPath
  Lean.enableInitializersExecution
  let env ← Lean.importModules #[{module := mod.name}] {} (loadExts := true)
  (generateFiles env ws.lakeEnv.lean target out roots checks renames projectInit).run

def moduleObjects (ws : Workspace) (mod : Lake.Module) : IO (Array FilePath) := do
  let imports ← ws.runBuild mod.transImports.fetch
  ws.runBuild (Job.collectArray <$> (imports.push mod).mapM (·.oExport.fetch))

def moduleLinkFlags (ws : Workspace) (mod : Lake.Module) : IO LinkFlags := do
  let lean := ws.lakeEnv.lean
  Lean.initSearchPath lean.sysroot ws.leanPath
  let env ← Lean.importModules #[{module := mod.name}] {}
  let leanPrefix ← run {cmd := lean.lean.toString, args := #["--print-prefix"]}
  let ldflags ← run {cmd := lean.leanc.toString, args := #["--print-ldflags"]}
  IO.ofExcept <| linkFlags ⟨leanPrefix.trimAscii.toString⟩ ldflags
    (leanImportChain env mod.name).isSome (importsStd env mod.name)

private def cCompiler (lean : LeanInstall) : FilePath :=
  if lean.customCc then lean.cc else "cc"

def compileCObjects (lean : LeanInstall) (tmp : FilePath)
    (sources : Array (FilePath × String × Bool)) : IO (Array FilePath) := do
  let cFlags := #["-I", lean.includeDir.toString] ++ lean.cFlags ++ #["-fPIC"]
  sources.mapM fun (source, name, publicSymbols) => do
    let obj := tmp / s!"{name}.o"
    let args := if publicSymbols then cFlags.push "-fvisibility=default" else cFlags
    let some () ← (Lake.compileO obj source args (cCompiler lean)).toBaseIO
      | throw <| IO.userError s!"could not compile {source}"
    return obj

def build (ws : Workspace) (out : FilePath) (shared : Bool := false) : IO Unit := do
  let out ← IO.FS.realPath out
  let manifest ← IO.FS.readFile (out / "leanfran.json")
  let .ok (target : Target) := Json.parse manifest >>= fromJson?
    | throw <| IO.userError "invalid leanfran.json"
  unless validPrefix target.cPrefix && validModule target.moduleName do
    throw <| IO.userError "invalid prefix or module in leanfran.json"
  let mod ← findModule ws target
  let objects ← moduleObjects ws mod
  let lean := ws.lakeEnv.lean
  let flags ← moduleLinkFlags ws mod
  IO.FS.withTempDir fun tmp => do
    let generated := tmp / "export.c"
    let mut envVars := ws.augmentedEnvVars
    let mut runtimeSources := #[]
    if target.jsonSupport then
      let dir := tmp / "LeanfranC"
      IO.FS.createDirAll dir
      let jsonC := tmp / "json.c"
      discard <| run {
        cmd := lean.lean.toString
        env := envVars
        args := #["-R", out.toString, "-o", (dir / "Json.olean").toString,
          "-c", jsonC.toString, (out / "LeanfranC" / "Json.lean").toString]}
      envVars := envVars.filter (·.1 != "LEAN_PATH") |>.push
        ("LEAN_PATH", some (SearchPath.toString (tmp :: ws.augmentedLeanPath)))
      runtimeSources := #[(jsonC, s!"leanfran_{target.cPrefix}_json", false)]
    discard <| run {
      cmd := lean.lean.toString
      env := envVars
      args := #["-R", out.toString, "-c", generated.toString, (exportPath target out).toString]}
    let native ← compileCObjects lean tmp (runtimeSources ++ #[
      (generated, s!"leanfran_{target.cPrefix}_export", false),
      (out / s!"{target.cPrefix}.c", s!"leanfran_{target.cPrefix}_wrapper", true),
      (out / "leanfran.c", s!"leanfran_{target.cPrefix}_support", true)])
    let file := if shared then sharedLibrary target.cPrefix else s!"lib{target.cPrefix}.a"
    let library := tmp / file
    if shared then
      let mode := if Platform.isOSX then
          #["-dynamiclib", s!"-Wl,-install_name,@rpath/{file}", "-Wl,-undefined,dynamic_lookup"]
        else #["-shared", s!"-Wl,-soname,{file}"]
      discard <| run {
        cmd := (cCompiler lean).toString
        args := mode ++ #["-o", library.toString] ++ (native ++ objects).map FilePath.toString ++
          flags.sharedFlags}
    else
      let some () ← (Lake.compileStaticLib library (native ++ objects) lean.ar).toBaseIO
        | throw <| IO.userError s!"could not create {file}"
    let staging := out / s!".{file}.{← IO.Process.getPID}"
    try
      IO.FS.writeBinFile staging (← IO.FS.readBinFile library)
      IO.FS.rename staging (out / file)
      let dependencies := if shared then
          #[s!"-Wl,-rpath,{out}"] ++ flags.sharedFlags
        else flags.staticFlags
      writeLinkFiles out target.cPrefix file (toString mod.pkg.version) dependencies
    finally
      if ← staging.pathExists then IO.FS.removeFile staging

end LeanC
