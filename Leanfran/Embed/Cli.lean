import Leanfran.Embed.Verify

open Lean System

namespace Leanfran.Embed

structure Options where
  dir : Option String := none
  verbose : Bool := false
  require : Bool := false

def usage (backend : Backend) : String :=
  let dir := if backend.dirRequired then s!"{backend.dirOption} <dir>" else s!"[{backend.dirOption} <dir>]"
  s!"usage: leanfran --lang {backend.lang} sync {dir} [--verbose]\n" ++
  s!"       leanfran --lang {backend.lang} check {dir} [--verbose] [--require proved]\n" ++
  s!"       leanfran --lang {backend.lang} status {dir} [--require proved]"

def parseArgs (backend : Backend) (command : String) (args : List String) : Except String Options := do
  let mut options : Options := {}
  let mut rest := args
  let mut seen : Array String := #[]
  while let key :: tail := rest do
    if seen.contains key then throw s!"duplicate option '{key}'"
    seen := seen.push key
    if key == backend.dirOption then
      let value :: tail := tail | throw s!"missing value for '{key}'"
      if value.isEmpty || value.startsWith "--" then throw s!"missing value for '{key}'"
      options := {options with dir := some value}
      rest := tail
    else if key == "--verbose" && command != "status" then
      options := {options with verbose := true}
      rest := tail
    else if key == "--require" && command != "sync" then
      let value :: tail := tail | throw "missing value for '--require'"
      unless value == "proved" do throw s!"expected '--require proved', got '--require {value}'"
      options := {options with require := true}
      rest := tail
    else throw s!"unknown option '{key}' for {command}"
  if backend.dirRequired && options.dir.isNone then throw s!"{backend.dirOption} is required"
  return options

private def ofIO (action : IO (Except Failure α)) : ExceptT Failure IO α := ExceptT.mk action

def statusCommand (backend : Backend) (ctx : Context) (require : Bool) : ExceptT Failure IO UInt32 := do
  let lock ← ofIO (Verify.readLock ctx.root backend.lang)
  let (scan, _) ← ofIO (backend.scan ctx)
  let support ← Sync.supportHash (backend.supportModules ((lock.section? backend.lang).getD {}) scan)
  let blockRows ← Manifest.blockStatus ctx.root backend.lang backend.compiler support (← Manifest.read ctx.root) scan
  for line in blockRows do IO.println line
  let functions ← ofIO (Verify.functionStatus backend ctx.root scan lock)
  for line in functions.rows do IO.println line
  if !blockRows.isEmpty || functions.stale || (require && !functions.proved) then return 1
  return 0

def syncCommand (backend : Backend) (ctx : Context) (check require : Bool) : ExceptT Failure IO UInt32 := do
  let lock ← ofIO (Verify.readLock ctx.root backend.lang)
  let (scan, state) ← ofIO (backend.scan ctx)
  let support := backend.supportModules ((lock.section? backend.lang).getD {}) scan
  let synced ← Sync.sync backend ctx state scan support
  unless check do return 0
  let (scan, state) ← if scan.functionsError.isSome || synced.changed then ofIO (backend.scan ctx)
    else pure (scan, state)
  if let some e := scan.functionsError then
    let place ← display ctx.root e.file
    throw (.content (if e.file.isEmpty then e.message else s!"{place}:{e.line}:{e.column}: {e.message}"))
  if scan.functions.isEmpty && (lock.section? backend.lang).isNone then return 0
  let outcome ← Verify.obligations backend ctx state scan synced require
  Verify.writeLock ctx.root lock backend.lang outcome.section?
  let next := backend.supportModules (outcome.section?.getD {}) scan
  if (← Sync.supportHash next) != (← Sync.supportHash support) then
    discard <| Sync.sync backend ctx state scan next
  return outcome.code

def run (backend : Backend) (command : String) (args : List String) : IO UInt32 := do
  let options ← match parseArgs backend command args with
    | .ok options => pure options
    | .error message =>
      IO.eprintln s!"leanfran --lang {backend.lang}: {message}\n{usage backend}"
      return 252
  unless ["sync", "check", "status"].contains command do
    IO.eprintln s!"leanfran --lang {backend.lang}: unknown command '{command}'\n{usage backend}"
    return 252
  let dir := FilePath.mk (options.dir.getD ".")
  let fail := fun (failure : Failure) => do
    unless failure.message.isEmpty do IO.eprintln failure.message
    return failure.code
  try
    let root ← match ← backend.root dir with
      | .ok root => pure root
      | .error failure => return ← fail failure
    let dir := (← (IO.FS.realPath dir).toBaseIO).toOption.getD dir
    let state := root / ".leanfran" / backend.lang
    let ctx : Context := {
      lang := backend.lang, root, dir, state, workspace := state / "workspace", app := ← IO.appPath
      lake := (← IO.getEnv "LAKE").getD "lake", verbose := options.verbose}
    let action : ExceptT Failure IO UInt32 := match command with
      | "status" => statusCommand backend ctx options.require
      | "check" => syncCommand backend ctx true options.require
      | _ => syncCommand backend ctx false false
    match ← Project.withLock root (command != "status") action.run with
    | .ok code => return code
    | .error failure => fail failure
  catch error =>
    IO.eprintln s!"leanfran --lang {backend.lang}: {error}"
    return 255

end Leanfran.Embed
