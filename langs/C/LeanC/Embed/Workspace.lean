import LeanC.Build
import LeanC.Embed.Models
import LeanC.Embed.ModelTest

open Lean Lake System

namespace LeanC.Embed

private def manifestName := "leanfran.manifest.json"
private def supportHeader := include_str "../../support/leanfran.h"
private def supportSource := include_str "../../support/leanfran.c"

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
  models : String := ""
  deriving FromJson, ToJson

private def makeManifest (config : Config) (blocks : Array Block) (models : Models) : IO Manifest := do
  let hashes : Array BlockHash ← blocks.mapM fun block => do
    let sha256 ← sha256 (Json.compress (toJson (block.imports, block.source)))
    pure {name := block.name, file := block.file.toString, line := block.line, sha256}
  let compiler ← sha256 compilerKey
  let mut inputs := #[models.source]
  for path in models.inputs do
    inputs := inputs.push s!"{path}:{← sha256 (← IO.FS.readFile path)}"
  let modelHash ← sha256 (Json.compress (toJson inputs))
  let configHash ← sha256 config.source
  return {schema := 3, compiler, config := configHash, blocks := hashes, models := modelHash}

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
  if previous.models != current.models then stale := stale.push "LF_STRUCT"
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

private def duplicateDefinition (blocks : Array Block) (line : String) : Option String := do
  let [_, rest] := line.splitOn "import LeanfranBlocks." | none
  let [later, rest] := rest.splitOn " failed, environment already contains '" | none
  let [name, earlier] := rest.splitOn "' from LeanfranBlocks." | none
  let later ← blocks.find? (·.name == later)
  let earlier ← blocks.find? (·.name == earlier.trimAscii.toString)
  return s!"{later.file}:{later.line}:1: error: Lean blocks '{earlier.name}' ({earlier.file}:{earlier.line}) " ++
    s!"and '{later.name}' both define '{name}'; the definitions of all Lean blocks share one namespace"

private def remapDiagnostic (dir : FilePath) (blocks : Array Block) (models : Models) (line : String) : String := Id.run do
  if let some message := duplicateDefinition blocks line then return message
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
      let count := block.imports.size + (if models.blocks.contains block.name then 1 else 0)
      let sourceLine := if n ≤ count then block.bodyLine - 1
        else block.bodyLine + n - count - 1
      let severity := if label == "error: " || label == "warning: " then label else ""
      return s!"{block.file}:{sourceLine}:{col + 1}: {severity}{(":".intercalate message).trimAscii}"
  return line

private def runLake (dir : FilePath) (blocks : Array Block) (models : Models) (args : Array String) : IO Unit := do
  let result ← IO.Process.output {cmd := "lake", cwd := some dir, args := #["--no-ansi"] ++ args}
  for stream in #[result.stdout, result.stderr] do
    if !stream.isEmpty then
      IO.eprint ("\n".intercalate ((stream.splitOn "\n").map (remapDiagnostic dir blocks models)))
  unless result.exitCode == 0 do
    throw <| IO.userError s!"lake {args[0]!} exited with {result.exitCode}"

private def workspace (dir : FilePath) (config : Config) (blocks : Array Block) (models : Models) : IO Unit := do
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
  let modelFile := dir / "LeanfranModels.lean"
  if !models.source.isEmpty then
    discard <| writeChanged modelFile models.source
  else if ← modelFile.pathExists then
    IO.FS.removeFile modelFile
  for block in blocks do
    let deps := block.imports.map Block.moduleName
    let deps := if models.blocks.contains block.name then deps.push "LeanfranModels" else deps
    discard <| writeChanged (blockPath dir block) (imports deps ++ block.source)
  IO.FS.createDirAll (dir / "LeanfranC")
  discard <| writeChanged (dir / "LeanfranC" / "Json.lean") jsonSupportSource
  IO.FS.createDirAll (dir / "LeanCLib")
  discard <| writeChanged (dir / "LeanCLib" / "C.lean") cLibSource
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
    "\n[[lean_lib]]\nname = \"LeanfranModels\"\n" ++
    "\n[[lean_lib]]\nname = \"LeanfranProject\"\n" ++
    "\n[[lean_lib]]\nname = \"LeanfranC\"\nglobs = [\"LeanfranC.+\"]\n" ++
    "\n[[lean_lib]]\nname = \"LeanCLib\"\nglobs = [\"LeanCLib.+\"]\n" ++
    "\n[[lean_lib]]\nname = \"LeanCModel\"\nglobs = [\"LeanCModel.+\"]\nmoreLeanArgs = [\"-DwarningAsError=false\"]\n" ++
    "\n[[lean_lib]]\nname = \"Proofs\"\nglobs = [\"Proofs.+\"]\nmoreLeanArgs = [\"-DwarningAsError=false\"]\n")
  discard <| writeChanged (dir / "lean-toolchain") s!"leanprover/lean4:v{Lean.versionString}\n"
  if !(← manifest.pathExists) || installed.toOption != some requirements then
    runLake dir blocks models #["update", "--keep-toolchain"]
    discard <| writeChanged dependencyConfig requirements
  runLake dir blocks models #["build"]

private unsafe def buildProject (dir : FilePath) (blocks : Array Block) (models : Models)
    (scratch stage out : FilePath) :
    IO (Std.HashMap String (Array Export) × Array Desc) := do
  let ws ← loadWorkspace dir
  let mut exports : Std.HashMap String (Array Export) := {}
  let mut types : Array Desc := #[]
  let mut symbols : Std.HashSet String := .ofList ["leanfran_init", "lf_project_initialized"]
  let mut modules := #[]
  let mut sources := #[]
  IO.FS.createDirAll scratch
  IO.FS.createDirAll stage
  for block in blocks do
    let target := {moduleName := Block.moduleName block.name, cPrefix := block.name : Target}
    let names ← match ← generate ws target scratch #[] {} {} true models.types with
      | .ok (names, entries, descs) =>
        exports := exports.insert block.name entries
        types := types ++ descs
        pure names
      | .error error => throw <| IO.userError s!"{block.file}:{block.line}:1: error: {error}"
    for name in names do
      if symbols.contains name then
        throw <| IO.userError s!"{block.file}:{block.line}:1: error: C name collision: {name}"
      symbols := symbols.insert name
    let header := s!"{block.name}.h"
    let text ← IO.FS.readFile (scratch / header)
    IO.FS.writeFile (stage / header) text
    let scratchHeader := models.headers.foldl (init := text) fun text (header, file) =>
      text.replace s!"#include \"{header}\"" s!"#include \"{file}\""
    IO.FS.writeFile (scratch / header) scratchHeader
    let exportFile := exportPath target dir
    IO.FS.createDirAll exportFile.parent.get!
    discard <| writeChanged exportFile (← IO.FS.readFile (exportPath target scratch))
    modules := modules.push (exportModule target.moduleName.toName).toString
    sources := sources.push (scratch / s!"{block.name}.c", s!"block_{block.name}", true)
  let projectModule := "LeanfranProject"
  discard <| writeChanged (dir / s!"{projectModule}.lean") (imports modules)
  runLake dir blocks models #["build", s!"+{projectModule}:olean"]
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
  let wrappers ← compileCObjects lean scratch sources (#["-iquote", scratch.toString] ++ models.flags)
  let native ← compileCObjects lean scratch #[(support, "support", true), (init, "init", true)]
  let native := wrappers ++ native
  let archive := "libleanfran.a"
  let library := scratch / archive
  let some () ← (Lake.compileStaticLib library (native ++ objects) lean.ar).toBaseIO
    | throw <| IO.userError s!"could not create {archive}"
  IO.FS.rename library (stage / archive)
  writeLinkFiles stage "leanfran" archive releaseVersion flags.staticFlags out
  return (exports, types)

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

private def writeModelTest (root scratch stage out : FilePath) (config : Config) (blocks : Array Block)
    (models : Models) (verified : Array FilePath) (exports : Std.HashMap String (Array Export))
    (types : Array Desc) : IO Unit := do
  let functions ← discoverModels root config blocks verified models.source scratch
  if functions.isEmpty then return
  let (source, files) := modelTest functions blocks exports types
  IO.FS.writeFile (stage / modelTestSource) source
  IO.FS.writeFile (stage / "leanfran_model_test.h") modelTestSupport
  let mk := stage / "leanfran.mk"
  IO.FS.writeFile mk ((← IO.FS.readFile mk) ++ modelTestMake out config (files.map (root / ·)))

private unsafe def sync (root state : FilePath) (config : Config) (blocks : Array Block) (models : Models)
    (verified : Array FilePath) (manifest : Manifest) :
    IO Unit := do
  let out := config.out
  let dir := state / "workspace"
  IO.FS.createDirAll out.parent.get!
  let transaction := out.parent.get! / s!".{out.fileName.get!}.leanfran-{← IO.Process.getPID}"
  IO.FS.createDir transaction
  let stage := transaction / "output"
  let backup := transaction / "previous"
  try
    workspace dir config blocks models
    let (exports, types) ← buildProject dir blocks models (transaction / "build") stage out
    writeModelTest root (transaction / "build") stage out config blocks models verified exports types
    IO.FS.writeFile (stage / manifestName) ((toJson manifest).pretty ++ "\n")
    publish stage out backup
  finally
    unless ← backup.pathExists do IO.FS.removeDirAll transaction

inductive Command where
  | sync
  | status
  | check (require : Bool)

private def statusAll (root : FilePath) (config : Config) (blocks : Array Block) (models : Models)
    (verified : Array FilePath) : IO UInt32 := do
  let code ← status config blocks (← makeManifest config blocks models)
  let functions ← (discoverModels root config blocks verified models.source config.out).toBaseIO
  let modelCode ← modelStatus root config (functions.mapError toString)
  return max code modelCode

unsafe def execute (command : Command) (dir : FilePath) : IO UInt32 := do
  let root ← IO.FS.realPath dir
  let state := root / ".leanfran"
  checkDirectory root state
  if (command matches .status) && !(← state.isDir) then
    let config ← readConfig root
    checkDirectory root config.out
    let (blocks, sources, verified) ← scan root config
    let models ← readModels root config blocks sources
    return ← statusAll root config blocks models verified
  IO.FS.createDirAll state
  let lock ← IO.FS.Handle.mk (state / "lock") .append
  lock.lock (exclusive := !(command matches .status))
  try
    let config ← readConfig root
    checkDirectory root config.out
    let (blocks, sources, verified) ← scan root config
    let models ← readModels root config blocks sources
    let manifest ← makeManifest config blocks models
    match command with
    | .status => statusAll root config blocks models verified
    | .sync | .check _ =>
      checkDirectory root (state / "workspace")
      if (← config.out.isDir) && !(← (config.out / manifestName).pathExists) then
        unless (← config.out.readDir).isEmpty do
          throw <| IO.userError s!"output directory {config.out} is nonempty and has no {manifestName}"
      sync root state config blocks models verified manifest
      if let .check require := command then
        let functions ← discoverModels root config blocks verified models.source config.out
        let modelCode ← checkModels root (state / "workspace") config functions (!models.source.isEmpty) require
        let config ← readConfig root
        let (blocks, sources, _) ← scan root config
        let models ← readModels root config blocks sources
        let code ← status config blocks (← makeManifest config blocks models)
        return max code modelCode
      else
        IO.println s!"synced {blocks.size} Lean blocks"
        return 0
  finally
    lock.unlock

end LeanC.Embed
