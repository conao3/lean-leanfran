import Leanfran.Embed.Workspace
import Leanfran.Embed.Install
import Leanfran.Embed.Project
import Leanfran.Embed.Batch

open Lean System

namespace Leanfran.Embed.Sync

def filesHash (files : Array WorkspaceFile) : IO String :=
  sha256 (Json.compress (toJson (files.map fun f => (f.path, f.text))))

def supportHash (files : Array WorkspaceFile) : IO String :=
  if files.isEmpty then pure "" else filesHash files

private def join (base : String) (file : String) : String :=
  if base == "." || base.isEmpty then file else s!"{base}/{file}"

def removeStages (ctx : Context) : IO Unit := do
  unless ← ctx.state.isDir do return
  for entry in ← ctx.state.readDir do
    if entry.fileName.startsWith "stage-" then IO.FS.removeDirAll entry.path

structure Result where
  generated : Array Generated := #[]
  changed : Bool := false
  blockFiles : Array (String × Array String) := #[]
  deriving Inhabited

def ofExcept (result : Except Failure α) : ExceptT Failure IO α := ExceptT.mk (pure result)

def ofIO (action : IO (Except Failure α)) : ExceptT Failure IO α := ExceptT.mk action

def checkOutputs (ctx : Context) (scan : Scan) : IO (Except Failure Unit) := do
  for block in scan.blocks do
    if let .error failure ← Project.checkDirectory ctx.root (ctx.root / block.output.dirPath) then
      return .error failure
  for file in scan.files do
    let dir := (FilePath.mk file.path).parent.getD "."
    if let .error failure ← Project.checkDirectory ctx.root (ctx.root / dir) then return .error failure
  return .ok ()

def install (backend : Backend) (ctx : Context) (state : backend.State) (scan : Scan)
    (supportModules : Array WorkspaceFile) : ExceptT Failure IO Result := do
  let generated ← ofIO (backend.generate ctx state scan scan.blocks)
  let summaries : Summaries := generated.map fun g => (g.block, g.summary)
  let extra ← ofIO (backend.extraOutputs ctx state scan summaries)
  let mut placements : Array Install.Placement := #[]
  let mut blockFiles : Std.HashMap String (Array String) := {}
  let mut languageFiles : Array String := #[]
  for g in generated do
    let some block := scan.blocks.find? (·.name == g.block) | continue
    for file in g.files do
      let path := join block.output.dirPath file
      placements := placements.push {path, content := .file (g.stage / file)}
      blockFiles := blockFiles.insert block.name ((blockFiles.getD block.name #[]).push path)
  for file in scan.files ++ extra do
    let content := match file.source with
      | some source => Install.Content.file source
      | none => .text file.text
    placements := placements.push {path := file.path, content}
    match file.block with
    | some name => blockFiles := blockFiles.insert name ((blockFiles.getD name #[]).push file.path)
    | none => languageFiles := languageFiles.push file.path
  let current : Std.HashSet String := .ofList (placements.toList.map (·.path))
  let manifest ← Manifest.read ctx.root
  let previous := manifest.section? backend.lang
  let mut removals : Array String := #[]
  if let some s := previous then
    for entry in s.blocks do
      if inScope scan.scope entry.source || scan.blocks.any (·.name == entry.name) then
        removals := removals ++ entry.files.filter (!current.contains ·)
    removals := removals ++ s.files.filter fun f => inScope scan.scope f && !current.contains f
  removals := removals ++ scan.stray.filter (!current.contains ·)
  removals := removals.toList.eraseDups.toArray.qsort (· < ·)
  let changedPlacements ← (placements.filterM (Install.changed ctx.root) : IO (Array Install.Placement))
  let known : Std.HashSet String := .ofList ((manifest.files backend.lang) ++ scan.stray).toList
  for path in changedPlacements.map (·.path) ++ removals do
    unless ← Install.owned ctx.root known backend.generatedHeaders path do
      throw (.content s!"refusing to overwrite {path}, which leanfran did not generate")
  let sort := fun (files : Array String) => files.toList.eraseDups.toArray.qsort (· < ·)
  let kept := (previous.map (·.blocks)).getD #[] |>.filter fun entry =>
    !inScope scan.scope entry.source && !scan.blocks.any (·.name == entry.name)
  let blocks := scan.blocks.map fun block => ({
    name := block.name, source := block.origin.file, hash := block.hash
    files := sort (blockFiles.getD block.name #[])} : Manifest.BlockEntry)
  let s : Manifest.Section := {
    compiler := backend.compiler, require := scan.require, inputs := scan.inputs
    support := ← supportHash supportModules
    blocks := (blocks ++ kept).qsort (·.name < ·.name), files := sort languageFiles}
  let text := Manifest.render manifest backend.lang (some s)
  let manifestPlacement : Install.Placement := {path := Manifest.fileName, content := .text text}
  let manifestChanged ← Install.changed ctx.root manifestPlacement
  if let .error error ← (Install.install ctx.root changedPlacements removals manifestPlacement).toBaseIO then
    throw (.environment s!"could not install the generated files: {error}")
  IO.eprintln s!"leanfran: {scan.blocks.size} blocks checked and generated"
  unless removals.isEmpty do IO.eprintln s!"leanfran: removed {", ".intercalate removals.toList}"
  return {
    generated, changed := !changedPlacements.isEmpty || !removals.isEmpty || manifestChanged
    blockFiles := blockFiles.toArray}

def sync (backend : Backend) (ctx : Context) (state : backend.State) (scan : Scan)
    (supportModules : Array WorkspaceFile) : ExceptT Failure IO Result := do
  ofIO (checkOutputs ctx scan)
  ofIO (Workspace.checkVersions ctx)
  ofIO (Project.prepare ctx)
  Workspace.write backend ctx scan supportModules
  ofIO (Workspace.build backend ctx scan)
  removeStages ctx
  try install backend ctx state scan supportModules
  finally removeStages ctx

end Leanfran.Embed.Sync
