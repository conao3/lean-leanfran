import Lake
import Lake.Load.Workspace
import LeanC.Header
import LeanC.Check
import LeanC.Link

open Lean Lake System

namespace LeanC

structure Target where
  moduleName : String
  cPrefix : String
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

def loadWorkspace : IO Workspace := do
  let version ← run {cmd := "lean", args := #["--version"]}
  let some actual := (version.splitOn "version ")[1]?.map (fun s => (s.splitOn ",").head!)
    | throw <| IO.userError s!"could not read Lean version: {version.trimAscii}"
  unless actual == Lean.versionString do
    throw <| IO.userError s!"leanfran-c was built with Lean {Lean.versionString}, found Lean {actual}"
  let some lean ← Lake.findLeanCmdInstall?
    | throw <| IO.userError "could not locate the Lean installation"
  let lakeEnv ← (Lake.Env.compute (Lake.LakeInstall.ofLean lean) lean (← Lake.findElanInstall?))
    |>.adapt IO.userError
  let some ws ← (Lake.loadWorkspace {lakeEnv, wsDir := ← IO.Process.getCurrentDir}).toBaseIO
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
    (roots : Array Name) (checks : Checks) : ExceptT String IO (Array Export) := do
  if let some chain := leanImportChain env moduleName then
    let message := s!"Lean compiler import: {" -> ".intercalate (chain.map Name.toString)}"
    unless checks.allowLeanImport do throw s!"{message} (use --allow-lean-import to allow)"
  let names := if roots.isEmpty then defaultRoots env moduleName else roots
  let mut exports := #[]
  for name in names.qsort Name.lt do
    match readExport env cPrefix name with
    | .error message =>
      if !roots.isEmpty then throw message
      IO.eprintln s!"leanfran-c: skipping {message}"
    | .ok entry =>
      if [s!"{cPrefix}_init", s!"{cPrefix}_initialize"].contains entry.symbol ||
          exports.any (fun prev => prev.symbol == entry.symbol) then
        throw s!"C name collision: {entry.symbol}"
      exports := exports.push entry
  let sorryRoots ← exports.filterM fun entry => usesSorry env entry.name
  if !sorryRoots.isEmpty then
    let names := ", ".intercalate (sorryRoots.toList.map fun entry => s!"'{entry.name}'")
    let message := s!"{names} depends on sorryAx"
    if checks.allowSorry then IO.eprintln s!"leanfran-c: warning: {message}"
    else throw s!"{message} (use --allow-sorry to allow)"
  return exports

private def generateFiles (env : Environment) (lean : LeanInstall) (target : Target)
    (out : FilePath) (roots : Array Name) (checks : Checks) : ExceptT String IO Unit := do
  let exports ← selectExports env target.moduleName.toName target.cPrefix roots checks
  let calls ← foreignCalls env (exports.map (·.name))
  let externs ← missingExterns lean calls.externs
  let implementations := calls.implementations.map fun pair => s!"{pair.1} -> {pair.2}"
  let file := exportPath target out
  IO.FS.createDirAll file.parent.get!
  IO.FS.writeFile file (emitExportModule target.moduleName.toName exports)
  IO.FS.writeFile (out / s!"{target.cPrefix}.h") (emitHeader target.cPrefix exports)
  IO.FS.writeFile (out / s!"{target.cPrefix}.c") (emitSource target.moduleName.toName target.cPrefix exports)
  IO.FS.writeFile (out / "leanfran.h") (include_str "../support/leanfran.h")
  IO.FS.writeFile (out / "leanfran.c") (include_str "../support/leanfran.c")
  let writeReport := fun suffix (lines : Array String) =>
    IO.FS.writeFile (out / s!"{target.cPrefix}.{suffix}.txt")
      (String.join (lines.toList.map (· ++ "\n")))
  writeReport "externs" externs
  writeReport "implemented-by" (implementations.qsort (· < ·))
  IO.FS.writeFile (out / "leanfran.json") ((toJson target).compress ++ "\n")

unsafe def generate (ws : Workspace) (target : Target) (out : FilePath) (roots : Array Name)
    (checks : Checks := {}) : IO (Except String Unit) := do
  let mod ← findModule ws target
  discard <| ws.runBuild mod.olean.fetch
  Lean.initSearchPath ws.lakeEnv.lean.sysroot ws.leanPath
  Lean.enableInitializersExecution
  let env ← Lean.importModules #[{module := mod.name}] {} (loadExts := true)
  (generateFiles env ws.lakeEnv.lean target out roots checks).run

def build (ws : Workspace) (out : FilePath) (shared : Bool := false) : IO Unit := do
  let out ← IO.FS.realPath out
  let manifest ← IO.FS.readFile (out / "leanfran.json")
  let .ok (target : Target) := Json.parse manifest >>= fromJson?
    | throw <| IO.userError "invalid leanfran.json"
  unless validPrefix target.cPrefix && validModule target.moduleName do
    throw <| IO.userError "invalid prefix or module in leanfran.json"
  let mod ← findModule ws target
  let imports ← ws.runBuild mod.transImports.fetch
  let objects ← ws.runBuild (Job.collectArray <$> (imports.push mod).mapM (·.oExport.fetch))
  let lean := ws.lakeEnv.lean
  Lean.initSearchPath lean.sysroot ws.leanPath
  let env ← Lean.importModules #[{module := mod.name}] {}
  let leanPrefix ← run {cmd := lean.lean.toString, args := #["--print-prefix"]}
  let ldflags ← run {cmd := lean.leanc.toString, args := #["--print-ldflags"]}
  let flags ← IO.ofExcept <| linkFlags ⟨leanPrefix.trimAscii.toString⟩ ldflags
    (leanImportChain env mod.name).isSome (importsStd env mod.name)
  IO.FS.withTempDir fun tmp => do
    let generated := tmp / "export.c"
    let env := ws.augmentedEnvVars
    let cc : FilePath := if lean.customCc then lean.cc else "cc"
    let cFlags := #["-I", lean.includeDir.toString] ++ lean.cFlags ++ #["-fPIC"]
    discard <| run {
      cmd := lean.lean.toString
      env := env
      args := #["-R", out.toString, "-c", generated.toString, (exportPath target out).toString]}
    let mut native := #[]
    for (source, name) in #[(generated, "export"), (out / s!"{target.cPrefix}.c", "wrapper"),
        (out / "leanfran.c", "support")] do
      let obj := tmp / s!"leanfran_{target.cPrefix}_{name}.o"
      let args := if name == "export" then cFlags else cFlags.push "-fvisibility=default"
      let some () ← (Lake.compileO obj source args cc).toBaseIO
        | throw <| IO.userError s!"could not compile {source}"
      native := native.push obj
    let file := if shared then sharedLibrary target.cPrefix else s!"lib{target.cPrefix}.a"
    let library := tmp / file
    if shared then
      let mode := if Platform.isOSX then
          #["-dynamiclib", s!"-Wl,-install_name,@rpath/{file}", "-Wl,-undefined,dynamic_lookup"]
        else #["-shared", s!"-Wl,-soname,{file}"]
      discard <| run {
        cmd := cc.toString
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
