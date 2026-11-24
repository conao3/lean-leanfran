import Lake
import Lake.Load.Workspace
import LeanC.Header

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

unsafe def generate (ws : Workspace) (target : Target) (out : FilePath) (roots : Array Name) (renames : Renames := {}) :
    IO (Except String Unit) := do
  let mod ← findModule ws target
  discard <| ws.runBuild mod.olean.fetch
  Lean.initSearchPath ws.lakeEnv.lean.sysroot ws.leanPath
  Lean.enableInitializersExecution
  let env ← Lean.importModules #[{module := mod.name}] {} (loadExts := true)
  let names := if roots.isEmpty then defaultRoots env mod.name else roots
  let mut exports := #[]
  let mut descs := #[]
  for name in names.qsort Name.lt do
    let read : MetaM (Except String (Export × Array Desc)) := do
      try
        return .ok (← (readExport target.cPrefix renames name).run descs)
      catch error =>
        return .error (← error.toMessageData.toString)
    match ← read.run' |>.toIO' {fileName := "<C exports>", fileMap := default} {env} with
    | .error message =>
      if !roots.isEmpty || message.startsWith "C name collision:" then return .error message
      IO.eprintln s!"leanfran-c: skipping {message}"
    | .ok (entry, types) =>
      exports := exports.push entry
      descs := types
  let mut claimed : Std.HashSet String := {}
  let cPrefix := target.cPrefix
  let reserved := [s!"{cPrefix}_init", s!"lf_{cPrefix}_initialize", s!"lf_{cPrefix}_nat_decimal",
    s!"lf_{cPrefix}_int_decimal", "init_error", "initialize_once"]
  let supportNames := ["LF_INLINE", "lf_error_clear", "lf_set_error", "lf_copy_string", "lf_copy_io_error",
    "lf_str_free", "lf_byte_array_free", "lf_byte_array_to_lean", "lf_byte_array_from_lean"]
  let integerNames := ["lf_nat_from_u64", "lf_nat_to_u64", "lf_nat_from_lean_u64",
    "lf_int_from_i64", "lf_int_to_i64", "lf_int_from_lean_i64"] ++
    ["lf_nat", "lf_int"].flatMap fun name =>
      ["free", "from_dec", "to_dec", "from_lean", "to_lean"].map fun suffix => s!"{name}_{suffix}"
  let typeNames := descs.toList.flatMap Desc.names
  let functionNames := exports.toList.flatMap fun e => [e.symbol, s!"lf_{e.symbol}"]
  for name in reserved ++ supportNames ++ integerNames ++ typeNames ++ functionNames do
    if claimed.contains name then return .error s!"C name collision: {name}"
    claimed := claimed.insert name
  let file := exportPath target out
  IO.FS.createDirAll file.parent.get!
  IO.FS.writeFile file (emitExportModule mod.name target.cPrefix exports)
  IO.FS.writeFile (out / s!"{target.cPrefix}.h") (emitHeader target.cPrefix exports descs)
  IO.FS.writeFile (out / s!"{target.cPrefix}.c") (emitSource mod.name target.cPrefix exports descs)
  IO.FS.writeFile (out / "leanfran.h") (include_str "../support/leanfran.h")
  IO.FS.writeFile (out / "leanfran.c") (include_str "../support/leanfran.c")
  IO.FS.writeFile (out / "leanfran.json") ((toJson target).compress ++ "\n")
  return .ok ()

def build (ws : Workspace) (out : FilePath) : IO Unit := do
  let manifest ← IO.FS.readFile (out / "leanfran.json")
  let .ok (target : Target) := Json.parse manifest >>= fromJson?
    | throw <| IO.userError "invalid leanfran.json"
  unless validPrefix target.cPrefix && validModule target.moduleName do
    throw <| IO.userError "invalid prefix or module in leanfran.json"
  let mod ← findModule ws target
  let imports ← ws.runBuild mod.transImports.fetch
  let objects ← ws.runBuild (Job.collectArray <$> (imports.push mod).mapM (·.oExport.fetch))
  IO.FS.withTempDir fun tmp => do
    let generated := tmp / "export.c"
    let lean := ws.lakeEnv.lean
    let env := ws.augmentedEnvVars
    let cFlags := #["-I", lean.includeDir.toString] ++ lean.ccFlags
    discard <| run {
      cmd := lean.lean.toString
      env := env
      args := #["-R", out.toString, "-c", generated.toString, (exportPath target out).toString]}
    let mut native := #[]
    for (source, name) in #[(generated, "export"), (out / s!"{target.cPrefix}.c", "wrapper"),
        (out / "leanfran.c", "support")] do
      let obj := tmp / s!"leanfran_{target.cPrefix}_{name}.o"
      let some () ← (Lake.compileO obj source cFlags lean.cc).toBaseIO
        | throw <| IO.userError s!"could not compile {source}"
      native := native.push obj
    let file := s!"lib{target.cPrefix}.a"
    let archive := tmp / file
    let some () ← (Lake.compileStaticLib archive (native ++ objects) lean.ar).toBaseIO
      | throw <| IO.userError s!"could not create {file}"
    let staging := out / s!".{file}.{← IO.Process.getPID}"
    try
      IO.FS.writeBinFile staging (← IO.FS.readBinFile archive)
      IO.FS.rename staging (out / file)
    finally
      if ← staging.pathExists then IO.FS.removeFile staging

end LeanC
