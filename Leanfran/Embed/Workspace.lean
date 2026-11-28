import Leanfran.Embed.Backend
import Leanfran.Embed.Diagnostics

open Lean System

namespace Leanfran.Embed.Workspace

private def bareKey (key : String) : Bool :=
  !key.isEmpty && key.toList.all fun c => c.isAlphanum || c == '_' || c == '-'

private def tomlKey (key : String) : String :=
  if bareKey key then key else (Json.str key).compress

private partial def tomlValue : Json → String
  | .arr items => "[" ++ ", ".intercalate (items.toList.map tomlValue) ++ "]"
  | .obj fields => "{" ++ ", ".intercalate ((objFields (.obj fields)).toList.map fun (k, v) => s!"{tomlKey k} = {tomlValue v}") ++ "}"
  | .null => "\"\""
  | value => value.compress

def requirements (root : FilePath) (require : Array Json) : String := Id.run do
  let mut out := ""
  for table in require do
    unless table matches .obj _ do continue
    out := out ++ "\n[[require]]\n"
    for (key, value) in objFields table do
      let value := match key, value with
        | "path", .str path => if (FilePath.mk path).isAbsolute then value else .str (root / path).toString
        | _, value => value
      if value matches .null then continue
      out := out ++ s!"{tomlKey key} = {tomlValue value}\n"
  return out

private def versionOf (cmd : String) (marker : String) : IO (Except Failure Unit) := do
  match ← (IO.Process.output {cmd, args := #["--version"]}).toBaseIO with
  | .error _ => return .error (.environment s!"{cmd} not found on PATH; leanfran needs Lean {Lean.versionString}")
  | .ok output =>
    let text := output.stdout.trimAscii.toString
    unless output.exitCode == 0 && (text.splitOn marker).length > 1 do
      return .error (.environment
        s!"{cmd} --version printed '{text}'; leanfran was built with Lean {Lean.versionString}, so put that Lean on PATH")
    return .ok ()

def checkVersions (ctx : Context) : IO (Except Failure Unit) := do
  let toolchain := ctx.root / "lean-toolchain"
  if ← toolchain.pathExists then
    let text := (← IO.FS.readFile toolchain).trimAscii.toString
    let expected := s!"leanprover/lean4:v{Lean.versionString}"
    unless text == expected do
      return .error (.environment s!"{toolchain} selects {text}, but leanfran was built with {expected}")
  if let .error failure ← versionOf "lean" s!"version {Lean.versionString}," then return .error failure
  versionOf ctx.lake s!"Lean version {Lean.versionString})"

def runLake (ctx : Context) (unit : ColumnUnit) (scan : Scan) (args : Array String) : IO (Except Failure Unit) := do
  let flags := if ctx.verbose then #["--no-ansi", "--verbose"] else #["--no-ansi"]
  let spawn : IO.Process.SpawnArgs := {cmd := ctx.lake, cwd := some ctx.workspace, args := flags ++ args}
  let result ← match ← (IO.Process.output spawn).toBaseIO with
    | .ok result => pure result
    | .error error => return .error (.environment s!"could not run {ctx.lake}: {error}")
  for stream in #[result.stdout, result.stderr] do
    unless stream.isEmpty do
      IO.eprint (← Diagnostics.remap ctx.root ctx.workspace unit scan.blocks scan.workspace ctx.verbose stream)
  unless result.exitCode == 0 do
    return .error (.content s!"lake {args[0]!} exited with {result.exitCode}")
  return .ok ()

private def removeArtifacts (ctx : Context) (relative : FilePath) : IO Unit := do
  let some parent := relative.parent | return
  let lib := ctx.workspace / ".lake" / "build" / "lib" / "lean" / parent
  unless ← lib.isDir do return
  let stem := relative.fileStem.getD ""
  for artifact in ← lib.readDir do
    if artifact.fileName.startsWith s!"{stem}." then IO.FS.removeFile artifact.path

def write (backend : Backend) (ctx : Context) (scan : Scan) (supportModules : Array WorkspaceFile) : IO Unit := do
  let ws := ctx.workspace
  IO.FS.createDirAll ws
  discard <| writeChanged (ws / "lean-toolchain") s!"leanprover/lean4:v{Lean.versionString}\n"
  discard <| writeChanged (ws / "lakefile.toml") (backend.lakefile ++ requirements ctx.root scan.require)
  let mut written : Std.HashSet String := {}
  for block in scan.blocks do
    discard <| writeChanged (ws / block.path) (block.prelude ++ block.text ++ block.postlude)
    written := written.insert block.path
  for file in scan.workspace ++ backend.supportFiles ++ supportModules do
    discard <| writeChanged (ws / file.path) file.text
    written := written.insert file.path
  for dir in backend.ownedDirs do
    unless ← (ws / dir).isDir do continue
    for path in ← (ws / dir).walkDir do
      unless path.extension == some "lean" do continue
      let some relative := relativeTo ws path | continue
      unless written.contains relative do
        IO.FS.removeFile path
        removeArtifacts ctx relative

def build (backend : Backend) (ctx : Context) (scan : Scan) : IO (Except Failure Unit) := do
  let requirements := requirements ctx.root scan.require
  let installed := ctx.workspace / "leanfran-requirements.toml"
  let previous ← (IO.FS.readFile installed).toBaseIO
  if !(← (ctx.workspace / "lake-manifest.json").pathExists) || previous.toOption != some requirements then
    if let .error failure ← runLake ctx backend.columnUnit scan #["update", "--keep-toolchain"] then
      return .error failure
    discard <| writeChanged installed requirements
  runLake ctx backend.columnUnit scan #["build"]

end Leanfran.Embed.Workspace
