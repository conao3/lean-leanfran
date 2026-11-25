import LeanC.Build
import LeanC.Embed.Scan

open Lean Lake System

namespace LeanC.Embed

private def manifestName := "leanfran.manifest.json"
private def supportHeader := include_str "../../support/leanfran.h"
private def supportSource := include_str "../../support/leanfran.c"

private def releaseVersion : String :=
  ((supportHeader.splitOn "#define LEANFRAN_VERSION \"")[1]!.splitOn "\"").head!

private def sha256 (text : String) : IO String := do
  let args : IO.Process.SpawnArgs := if Platform.isOSX then
    {cmd := "shasum", args := #["-a", "256"]}
  else {cmd := "sha256sum"}
  let output ← IO.Process.run args (some text)
  return (output.splitOn " ").head!

private structure BlockHash where
  name : String
  file : String
  line : Nat
  sha256 : String
  deriving FromJson, ToJson, BEq

private structure Manifest where
  schema : Nat
  compiler : String
  config : String
  blocks : Array BlockHash
  deriving FromJson, ToJson

private def makeManifest (config : Config) (blocks : Array Block) : IO Manifest := do
  let hashes : Array BlockHash ← blocks.mapM fun block => do
    let sha256 ← sha256 (Json.compress (toJson (block.imports, block.source)))
    pure {name := block.name, file := block.file.toString, line := block.line, sha256}
  let compiler ← sha256 s!"{releaseVersion}/{Lean.versionString}"
  return {schema := 1, compiler, config := ← sha256 config.source, blocks := hashes}

private def outputFiles (blocks : Array Block) : Array String :=
  #["leanfran.h", "leanfran.pc", "leanfran.mk", "leanfran-config.cmake", "libleanfran.a"] ++
    blocks.map (fun block => s!"{block.name}.h")

private def status (config : Config) (blocks : Array Block) (current : Manifest) : IO UInt32 := do
  let previous ← (IO.FS.readFile (config.out / manifestName)).toBaseIO
  let .ok previous := previous >>= fun text => (Json.parse text >>= fromJson?).mapError IO.userError
    | IO.println "stale: leanfran.manifest.json"; return 1
  let previous : Manifest := previous
  let mut stale := #[]
  if previous.schema != current.schema || previous.compiler != current.compiler then
    stale := stale.push "leanfran-c"
  if previous.config != current.config then stale := stale.push "leanfran.toml"
  let old := Std.HashMap.ofList (previous.blocks.toList.map fun b => (b.name, b))
  let new := Std.HashSet.ofList (current.blocks.toList.map (·.name))
  stale := stale ++ (current.blocks.filter (fun b => old[b.name]? != some b)).map (·.name)
  stale := stale ++ (previous.blocks.filter (!new.contains ·.name)).map (·.name)
  for file in outputFiles blocks do
    unless ← (config.out / file).pathExists do stale := stale.push file
  if stale.isEmpty then
    IO.println "up to date"
    return 0
  IO.println s!"stale: {", ".intercalate stale.toList}"
  return 1

private def writeChanged (path : FilePath) (text : String) : IO Bool := do
  if (← (IO.FS.readFile path).toBaseIO).toOption == some text then return false
  IO.FS.writeFile path text
  return true

private def blockPath (dir : FilePath) (block : Block) : FilePath :=
  dir / "LeanfranBlocks" / s!"{block.name}.lean"

private def imports (modules : Array String) : String :=
  String.join (modules.toList.map (fun name => s!"import {name}\n"))

private def remapDiagnostic (dir : FilePath) (blocks : Array Block) (line : String) : String := Id.run do
  for block in blocks do
    let generated := (blockPath "." block).toString
    let relative := (generated.drop 2).toString
    for file in #[(blockPath dir block).toString, generated, relative] do
      let parts := line.splitOn (file ++ ":")
      let [label, location] := parts | continue
      if !label.isEmpty && !label.endsWith " " then continue
      let number :: column :: message := location.splitOn ":" | continue
      let some n := number.toNat? | continue
      let some col := column.toNat? | continue
      let sourceLine := if n ≤ block.imports.size then block.bodyLine - 1
        else block.bodyLine + n - block.imports.size - 1
      let severity := if label == "error: " || label == "warning: " then label else ""
      return s!"{block.file}:{sourceLine}:{col + 1}: {severity}{(":".intercalate message).trimAscii}"
  return line

private def runLake (dir : FilePath) (blocks : Array Block) (args : Array String) : IO Unit := do
  let result ← IO.Process.output {cmd := "lake", cwd := some dir, args := #["--no-ansi"] ++ args}
  for stream in #[result.stdout, result.stderr] do
    if !stream.isEmpty then
      IO.eprint ("\n".intercalate ((stream.splitOn "\n").map (remapDiagnostic dir blocks)))
  unless result.exitCode == 0 do
    throw <| IO.userError s!"lake {args[0]!} exited with {result.exitCode}"

private def workspace (dir : FilePath) (config : Config) (blocks : Array Block) : IO Unit := do
  let sources := dir / "LeanfranBlocks"
  IO.FS.createDirAll sources
  let desired := Std.HashSet.ofList (blocks.toList.map (fun block => s!"{block.name}.lean"))
  for entry in ← sources.readDir do
    if entry.path.extension == some "lean" && !desired.contains entry.fileName then
      IO.FS.removeFile entry.path
      let lib := dir / ".lake" / "build" / "lib" / "lean" / "LeanfranBlocks"
      if ← lib.isDir then
        for artifact in ← lib.readDir do
          if artifact.fileName.startsWith s!"{entry.path.fileStem.getD ""}." then
            IO.FS.removeFile artifact.path
  for block in blocks do
    discard <| writeChanged (blockPath dir block) (imports (block.imports.map Block.moduleName) ++ block.source)
  IO.FS.createDirAll (dir / "LeanfranC")
  discard <| writeChanged (dir / "LeanfranC" / "Json.lean") jsonSupportSource
  let lakefile := dir / "lakefile.toml"
  let requirements := Toml.ppTable config.requirements
  let manifest := dir / "lake-manifest.json"
  let dependencyConfig := dir / "leanfran-requirements.toml"
  let installed ← (IO.FS.readFile dependencyConfig).toBaseIO
  discard <| writeChanged lakefile (
    "name = \"leanfran_project\"\n" ++
    "moreLeanArgs = [\"-DwarningAsError=true\"]\n" ++
    "defaultTargets = [\"LeanfranBlocks\"]\n\n" ++ requirements ++
    "\n[[lean_lib]]\nname = \"LeanfranBlocks\"\nglobs = [\"LeanfranBlocks.+\"]\n" ++
    "\n[[lean_lib]]\nname = \"LeanfranExport\"\nglobs = [\"LeanfranExport.+\"]\n" ++
    "\n[[lean_lib]]\nname = \"LeanfranProject\"\n" ++
    "\n[[lean_lib]]\nname = \"LeanfranC\"\nglobs = [\"LeanfranC.+\"]\n")
  discard <| writeChanged (dir / "lean-toolchain") s!"leanprover/lean4:v{Lean.versionString}\n"
  if !(← manifest.pathExists) || installed.toOption != some requirements then
    runLake dir blocks #["update", "--keep-toolchain"]
    discard <| writeChanged dependencyConfig requirements
  runLake dir blocks #["build"]

private unsafe def buildProject (dir : FilePath) (blocks : Array Block) (scratch stage out : FilePath) :
    IO Unit := do
  let ws ← loadWorkspace dir
  let mut symbols : Std.HashSet String := .ofList ["leanfran_init", "lf_project_initialized"]
  let mut modules := #[]
  let mut sources := #[]
  IO.FS.createDirAll scratch
  IO.FS.createDirAll stage
  for block in blocks do
    let target := {moduleName := Block.moduleName block.name, cPrefix := block.name : Target}
    let names ← match ← generate ws target scratch #[] {} {} true with
      | .ok names => pure names
      | .error error => throw <| IO.userError s!"{block.file}:{block.line}:1: error: {error}"
    for name in names do
      if symbols.contains name then
        throw <| IO.userError s!"{block.file}:{block.line}:1: error: C name collision: {name}"
      symbols := symbols.insert name
    let header := s!"{block.name}.h"
    IO.FS.writeFile (stage / header) (← IO.FS.readFile (scratch / header))
    let exportFile := exportPath target dir
    IO.FS.createDirAll exportFile.parent.get!
    discard <| writeChanged exportFile (← IO.FS.readFile (exportPath target scratch))
    modules := modules.push (exportModule target.moduleName.toName).toString
    sources := sources.push (scratch / s!"{block.name}.c", s!"block_{block.name}", true)
  let projectModule := "LeanfranProject"
  discard <| writeChanged (dir / s!"{projectModule}.lean") (imports modules)
  runLake dir blocks #["build", s!"+{projectModule}:olean"]
  let ws ← loadWorkspace dir
  let mod ← findModule ws {moduleName := projectModule, cPrefix := "leanfran"}
  let objects ← moduleObjects ws mod
  let flags ← moduleLinkFlags ws mod
  let support := scratch / "leanfran.c"
  let init := scratch / "leanfran-init.c"
  let header := supportHeader.replace "void lf_error_clear("
    "lf_status leanfran_init(lf_error *err);\nvoid lf_error_clear("
  IO.FS.writeFile (stage / "leanfran.h") header
  IO.FS.writeFile (scratch / "leanfran.h") header
  IO.FS.writeFile support supportSource
  IO.FS.writeFile init (emitProjectInitializer (Lean.mkModuleInitializationFunctionName mod.name mod.pkg.id?))
  let lean := ws.lakeEnv.lean
  let native ← compileCObjects lean scratch (sources ++ #[(support, "support", true), (init, "init", true)])
  let archive := "libleanfran.a"
  let library := scratch / archive
  let some () ← (Lake.compileStaticLib library (native ++ objects) lean.ar).toBaseIO
    | throw <| IO.userError s!"could not create {archive}"
  IO.FS.rename library (stage / archive)
  writeLinkFiles stage "leanfran" archive releaseVersion flags.staticFlags out

private def checkDirectory (root path : FilePath) : IO Unit := do
  let mut parent := path
  while parent != root do
    match ← parent.symlinkMetadata.toBaseIO with
    | .ok info =>
      unless info.type == .dir do
        throw <| IO.userError s!"expected a project directory at {parent}"
    | .error (.noFileOrDirectory ..) => pure ()
    | .error error => throw error
    parent := parent.parent.get!

private def publish (stage out backup : FilePath) : IO Unit := do
  let hadOutput ← out.isDir
  if hadOutput then IO.FS.rename out backup
  try
    IO.FS.rename stage out
  catch error =>
    if hadOutput then IO.FS.rename backup out
    throw error
  if hadOutput then IO.FS.removeDirAll backup

private unsafe def sync (state : FilePath) (config : Config) (blocks : Array Block) (manifest : Manifest) :
    IO Unit := do
  let out := config.out
  let dir := state / "workspace"
  IO.FS.createDirAll out.parent.get!
  let transaction := out.parent.get! / s!".{out.fileName.get!}.leanfran-{← IO.Process.getPID}"
  IO.FS.createDir transaction
  let stage := transaction / "output"
  let backup := transaction / "previous"
  try
    workspace dir config blocks
    buildProject dir blocks (transaction / "build") stage out
    IO.FS.writeFile (stage / manifestName) ((toJson manifest).pretty ++ "\n")
    publish stage out backup
  finally
    unless ← backup.pathExists do IO.FS.removeDirAll transaction

inductive Command where
  | sync
  | status
  | check

unsafe def execute (command : Command) (dir : FilePath) : IO UInt32 := do
  let root ← IO.FS.realPath dir
  let state := root / ".leanfran"
  checkDirectory root state
  if (command matches .status) && !(← state.isDir) then
    let config ← readConfig root
    checkDirectory root config.out
    let blocks ← scan root config
    return ← status config blocks (← makeManifest config blocks)
  IO.FS.createDirAll state
  let lock ← IO.FS.Handle.mk (state / "lock") .append
  lock.lock (exclusive := !(command matches .status))
  try
    let config ← readConfig root
    checkDirectory root config.out
    let blocks ← scan root config
    let manifest ← makeManifest config blocks
    match command with
    | .status => status config blocks manifest
    | .sync | .check =>
      checkDirectory root (state / "workspace")
      if (← config.out.isDir) && !(← (config.out / manifestName).pathExists) then
        unless (← config.out.readDir).isEmpty do
          throw <| IO.userError s!"output directory {config.out} is nonempty and has no {manifestName}"
      sync state config blocks manifest
      if command matches .check then
        let config ← readConfig root
        let blocks ← scan root config
        status config blocks (← makeManifest config blocks)
      else
        IO.println s!"synced {blocks.size} Lean blocks"
        return 0
  finally
    lock.unlock

end LeanC.Embed
