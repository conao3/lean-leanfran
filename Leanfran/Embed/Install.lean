import Leanfran.Embed.Manifest

open Lean System

namespace Leanfran.Embed.Install

inductive Content where
  | text (value : String)
  | file (path : FilePath)
  deriving Inhabited

def Content.bytes : Content → IO ByteArray
  | .text t => pure t.toUTF8
  | .file path => IO.FS.readBinFile path

structure Placement where
  path : String
  content : Content
  deriving Inhabited

private def firstLine (path : FilePath) : IO ByteArray := do
  let bytes ← IO.FS.readBinFile path
  let stop := (bytes.toList.findIdx? (· == 10)).getD bytes.size
  return bytes.extract 0 stop

private def startsWith (bytes pre : ByteArray) : Bool :=
  pre.size ≤ bytes.size && bytes.extract 0 pre.size == pre

def owned (root : FilePath) (known : Std.HashSet String) (headers : Array String) (path : String) : IO Bool := do
  let file := root / path
  if !(← file.pathExists) || known.contains path then return true
  if (← file.symlinkMetadata).type != .file then return false
  let line ← firstLine file
  return headers.any fun header => startsWith line header.toUTF8

private inductive Action where
  | created (dest : FilePath)
  | replaced (dest backup : FilePath)
  | removed (dest backup : FilePath)

private def undo : Action → IO Unit
  | .created dest => do if ← dest.pathExists then IO.FS.removeFile dest
  | .replaced dest backup => do
    if ← dest.pathExists then IO.FS.removeFile dest
    IO.FS.rename backup dest
  | .removed dest backup => IO.FS.rename backup dest

private partial def prune (root dir : FilePath) : IO Unit := do
  if dir == root || dir.toString.length ≤ root.toString.length then return
  unless ← dir.isDir do return
  unless (← dir.readDir).isEmpty do return
  IO.FS.removeDir dir
  if let some parent := dir.parent then prune root parent

def changed (root : FilePath) (placement : Placement) : IO Bool := do
  let dest := root / placement.path
  match ← (IO.FS.readBinFile dest).toBaseIO with
  | .ok current => return current != (← placement.content.bytes)
  | .error _ => return true

private partial def missingDirs (root dir : FilePath) : IO (List FilePath) := do
  if dir == root || dir.toString.length ≤ root.toString.length || (← dir.pathExists) then return []
  return dir :: (← missingDirs root (dir.parent.getD root))

private def place (root : FilePath) (pid counter : Nat) (placement : Placement) :
    IO (List FilePath × Action) := do
  let dest := root / placement.path
  let dir := dest.parent.getD root
  let created ← missingDirs root dir
  IO.FS.createDirAll dir
  let temp := dir / s!".leanfran-{pid}-{counter}"
  try IO.FS.writeBinFile temp (← placement.content.bytes)
  catch error =>
    for d in created do try IO.FS.removeDir d catch _ => pure ()
    throw error
  let action ← if ← dest.pathExists then
      let backup := dir / s!".leanfran-{pid}-{counter}.previous"
      IO.FS.rename dest backup
      pure (Action.replaced dest backup)
    else pure (Action.created dest)
  try IO.FS.rename temp dest
  catch error =>
    try IO.FS.removeFile temp catch _ => pure ()
    undo action
    for d in created do try IO.FS.removeDir d catch _ => pure ()
    throw error
  return (created, action)

def install (root : FilePath) (placements : Array Placement) (removals : Array String) (manifest : Placement) :
    IO Unit := do
  let pid := (← IO.Process.getPID).toNat
  let actions ← IO.mkRef (#[] : Array Action)
  let created ← IO.mkRef (#[] : Array FilePath)
  let counter ← IO.mkRef 0
  let next := counter.modifyGet fun n => (n + 1, n + 1)
  let record := fun (result : List FilePath × Action) => do
    created.modify (· ++ result.1.toArray)
    actions.modify (·.push result.2)
  try
    for placement in placements do
      record (← place root pid (← next) placement)
    for path in removals do
      let dest := root / path
      unless ← dest.pathExists do continue
      let backup := (dest.parent.getD root) / s!".leanfran-{pid}-{← next}.previous"
      IO.FS.rename dest backup
      actions.modify (·.push (.removed dest backup))
    record (← place root pid (← next) manifest)
  catch error =>
    for action in (← actions.get).reverse do
      try undo action catch _ => pure ()
    for dir in ← created.get do
      try IO.FS.removeDir dir catch _ => pure ()
    throw error
  for action in ← actions.get do
    match action with
    | .replaced _ backup | .removed _ backup => try IO.FS.removeFile backup catch _ => pure ()
    | .created _ => pure ()
  for path in removals do
    prune root ((root / path).parent.getD root)

end Leanfran.Embed.Install
