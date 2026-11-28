import Leanfran.Embed.Types

open Lean System

namespace Leanfran.Embed.Project

def checkDirectory (root path : FilePath) : IO (Except Failure Unit) := do
  let mut parent := path
  while parent != root && parent.toString.length > root.toString.length do
    match ← parent.symlinkMetadata.toBaseIO with
    | .ok info =>
      unless info.type == .dir do
        return .error (.content s!"expected a project directory at {parent}")
    | .error (.noFileOrDirectory ..) => pure ()
    | .error error => return .error (.environment (toString error))
    let some next := parent.parent | break
    parent := next
  return .ok ()

def stateDir (root : FilePath) : FilePath := root / ".leanfran"

def prepare (ctx : Context) : IO (Except Failure Unit) := do
  if let .error failure ← checkDirectory ctx.root ctx.workspace then return .error failure
  let dir := stateDir ctx.root
  IO.FS.createDirAll dir
  let ignore := dir / ".gitignore"
  let current ← match ← (IO.FS.readFile ignore).toBaseIO with
    | .ok text => pure text
    | .error _ => pure ""
  let lines := current.splitOn "\n" |>.map (·.trimAscii.toString)
  let missing := #["/lock", s!"/{ctx.lang}/"].filter (!lines.contains ·)
  unless missing.isEmpty do
    let base := if current.isEmpty || current.endsWith "\n" then current else current ++ "\n"
    IO.FS.writeFile ignore (base ++ String.join (missing.toList.map (· ++ "\n")))
  return .ok ()

def withLock (root : FilePath) (exclusive : Bool) (action : IO α) : IO α := do
  let dir := stateDir root
  if !exclusive && !(← (dir / "lock").pathExists) then return ← action
  IO.FS.createDirAll dir
  let handle ← IO.FS.Handle.mk (dir / "lock") .append
  handle.lock (exclusive := exclusive)
  try action finally handle.unlock

end Leanfran.Embed.Project
