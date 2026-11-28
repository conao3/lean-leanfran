import LeanC.Embed.Workspace
import Leanfran.Embed

open Lean System

namespace LeanC.Embed

private def lakefile : String :=
  "name = \"leanfran_project\"\n" ++
  "moreLeanArgs = [\"-DwarningAsError=true\"]\n" ++
  "defaultTargets = [\"LeanfranBlocks\"]\n" ++
  "\n[[lean_lib]]\nname = \"LeanfranBlocks\"\nglobs = [\"LeanfranBlocks.+\"]\n" ++
  "\n[[lean_lib]]\nname = \"LeanfranExport\"\nglobs = [\"LeanfranExport.+\"]\n" ++
  "\n[[lean_lib]]\nname = \"LeanfranModels\"\n" ++
  "\n[[lean_lib]]\nname = \"LeanfranProject\"\n" ++
  "\n[[lean_lib]]\nname = \"LeanfranC\"\nglobs = [\"LeanfranC.+\"]\n" ++
  "\n[[lean_lib]]\nname = \"LeanCLib\"\nglobs = [\"LeanCLib.+\"]\n" ++
  "\n[[lean_lib]]\nname = \"LeanCModel\"\nglobs = [\"LeanCModel.+\"]\nmoreLeanArgs = [\"-DwarningAsError=false\"]\n" ++
  "\n[[lean_lib]]\nname = \"Proofs\"\nglobs = [\"Proofs.+\"]\nmoreLeanArgs = [\"-DwarningAsError=false\"]\n"

structure Built where
  stage : FilePath
  files : Array String

structure State where
  config : Config
  blocks : Array Block
  models : Models
  verified : Array FilePath
  functions : Except String (Array ModelFunction)
  built : IO.Ref (Option Built)

private def relative (root path : FilePath) : String :=
  (Leanfran.Embed.relativeTo root path).getD path.toString

private def outDir (root : FilePath) (config : Config) : String := relative root config.out

private def join (base file : String) : String :=
  if base == "." then file else s!"{base}/{file}"

private def lineMap (block : Block) : Array Leanfran.Embed.MapEntry := Id.run do
  let bytes := block.source.toUTF8
  let mut entries := #[{offset := 0, line := block.bodyLine, column := 1}]
  for i in [0:bytes.size] do
    if bytes[i]! == 10 && i + 1 < bytes.size then
      entries := entries.push {offset := i + 1, line := block.bodyLine + entries.size, column := 1}
  return entries

private def clangFound : IO Bool := do
  let clang ← (IO.Process.output {cmd := "clang", args := #["--version"]}).toBaseIO
  return clang.toOption.any (·.exitCode == 0)

private def oldOutputs (root : FilePath) (config : Config) : IO (Array String) := do
  let manifest := config.out / "leanfran.manifest.json"
  let .ok text ← (IO.FS.readFile manifest).toBaseIO | return #[]
  let blocks := match Json.parse text >>= (·.getObjValAs? (Array Json) "blocks") with
    | .ok blocks => blocks.filterMap fun (b : Json) => (b.getObjValAs? String "name").toOption
    | .error _ => #[]
  let names : Array String := #["leanfran.manifest.json", modelTestSource, "leanfran_model_test.h"] ++ outputFiles ++
    blocks.map (s!"{·}.h")
  let out := outDir root config
  names.filterMapM fun (name : String) => do
    return if ← (config.out / name).pathExists then some (join out name) else none

private def scanProject (ctx : Leanfran.Embed.Context) :
    IO (Except Leanfran.Embed.Failure (Leanfran.Embed.Scan × State)) := do
  let root := ctx.root
  try
    let config ← readConfig root
    let (blocks, sources, verified) ← scan root config
    if let some src := sources[0]? then
      unless ← clangFound do
        return .error (.environment s!"{relative root src.path}:{src.line}:1: error: LF_STRUCT requires clang on PATH")
    let models ← readModels root config blocks sources
    let functions ← (discoverModels root config blocks verified models.source config.out).toBaseIO
    let out := outDir root config
    let mut converted := #[]
    for block in blocks do
      let deps := block.imports.map Block.moduleName
      let deps := if models.blocks.contains block.name then deps.push "LeanfranModels" else deps
      let hash ← Leanfran.Embed.sha256 (Json.compress (toJson (block.imports, block.source)))
      let entry : Leanfran.Embed.Block := {
        name := block.name, module := Block.moduleName block.name, path := s!"LeanfranBlocks/{block.name}.lean"
        prelude := imports deps, text := block.source, postlude := "", map := lineMap block
        origin := {file := block.file.toString, line := block.line, column := 1}, uses := block.imports
        hash, job := Json.mkObj [], output := .dir out}
      converted := converted.push entry
    let mut inputs := #[models.source]
    for path in models.inputs do
      inputs := inputs.push s!"{relative root path}:{← Leanfran.Embed.sha256 (← IO.FS.readFile path)}"
    let built ← IO.mkRef none
    let state : State := {config, blocks, models, verified, functions := functions.mapError toString, built}
    let modelHash ← Leanfran.Embed.sha256 (Json.compress (toJson inputs))
    let inputHash ← Leanfran.Embed.sha256 (Json.compress (toJson #[config.source, modelHash]))
    let stray ← oldOutputs root config
    let proofInputs ← Leanfran.Embed.sha256 config.source
    let scan : Leanfran.Embed.Scan := {
      require := config.requirements
      inputs := inputHash
      blocks := converted
      workspace := if models.source.isEmpty then #[] else #[{path := "LeanfranModels.lean", text := models.source}]
      stray
      functions := (functions.toOption.getD #[]).map fun m => {
        id := m.id, labels := m.labels, hash := m.hash
        origin := {file := m.file.toString, line := m.line, column := m.column}}
      functionsError := match functions with
        | .ok _ => none
        | .error error => some {file := "", line := 0, column := 0, message := toString error}
      proofInputs}
    return .ok (scan, state)
  catch error =>
    return .error (.content (toString error))

private unsafe def generateProject (ctx : Leanfran.Embed.Context) (state : State) (scan : Leanfran.Embed.Scan)
    (_ : Array Leanfran.Embed.Block) : IO (Except Leanfran.Embed.Failure (Array Leanfran.Embed.Generated)) := do
  let stage ← Leanfran.Embed.Batch.stageDir ctx
  let scratch := stage / "build"
  let output := stage / "output"
  let lake := fun (args : Array String) => do
    match ← Leanfran.Embed.Workspace.runLake ctx .codePoint scan args with
    | .ok () => pure ()
    | .error failure => throw (IO.userError failure.message)
  try
    let config := state.config
    let (exports, types) ← buildProject ctx.workspace state.blocks state.models scratch output config.out lake
    writeModelTest ctx.root scratch output config.out config state.blocks state.models state.verified exports types
    state.built.set (some {stage := output, files := ← Leanfran.Embed.Batch.filesUnder output})
    return .ok (state.blocks.map fun block => {block := block.name, stage := output, files := #[s!"{block.name}.h"]})
  catch error =>
    return .error (.content (toString error))

private def extraOutputs (ctx : Leanfran.Embed.Context) (state : State) (_ : Leanfran.Embed.Scan)
    (_ : Leanfran.Embed.Summaries) : IO (Except Leanfran.Embed.Failure (Array Leanfran.Embed.ProjectFile)) := do
  let some built ← state.built.get | return .ok #[]
  let headers := state.blocks.map (s!"{·.name}.h")
  let out := outDir ctx.root state.config
  return .ok (built.files.filter (!headers.contains ·) |>.map fun file =>
    {path := join out file, source := some (built.stage / file)})

private def translateProject (_ : Leanfran.Embed.Context) (state : State) (_ : Leanfran.Embed.TranslateInput) :
    IO (Except Leanfran.Embed.Failure Leanfran.Embed.Translation) :=
  return match state.functions with
    | .ok models => .ok (translation models (!state.models.source.isEmpty))
    | .error message => .error (.content message)

private def projectRoot (dir : FilePath) : IO (Except Leanfran.Embed.Failure FilePath) := do
  let root ← match ← (IO.FS.realPath dir).toBaseIO with
    | .ok root => pure root
    | .error error => return .error (.content s!"{dir}: {error}")
  let path := root / "leanfran.toml"
  unless ← path.pathExists do
    return .error (.content
      s!"{path} not found; create leanfran.toml with at least `sources = [\"src/**/*.c\"]` in the project root")
  return .ok root

unsafe def backend : Leanfran.Embed.Backend := {
  lang := "c", version := releaseVersion, generatorVersion, dirOption := "--dir", dirRequired := false
  State, root := projectRoot, scan := scanProject, translate := translateProject, lakefile
  supportFiles := #[{path := "LeanfranC/Json.lean", text := jsonSupportSource}, {path := "LeanCLib/C.lean", text := cLibSource}]
  ownedDirs := #["LeanfranBlocks"], verificationDir := "."
  generatedHeaders := #["#ifndef LEANFRAN_", "Name: leanfran", "LEANFRAN_CFLAGS := ", "if(NOT TARGET leanfran::leanfran)"]
  columnUnit := .codePoint, job := fun _ _ => Json.mkObj [], generateArgs := #[]
  generate := generateProject, supportModules := fun _ _ => #[], extraOutputs}

end LeanC.Embed
