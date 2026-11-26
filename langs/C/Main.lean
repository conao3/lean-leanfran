import LeanC
import LeanC.Embed.Workspace
import LeanC.Verify.Command
import LeanC.Verify.Obligations

open Lean LeanC System

inductive CliCommand where
  | generate (target : Target) (out : FilePath) (roots : Array Name) (checks : Checks) (renames : Renames)
  | build (out : FilePath) (shared : Bool)
  | embed (command : Embed.Command) (dir : FilePath)

def usage : String :=
  "Usage: leanfran-c generate --module-name M [--roots name,...] [--prefix prefix] [--rename Lean.Name=c_name] [--allow-sorry] [--allow-lean-import] --out-dir dir\n" ++
  "       leanfran-c build [--shared] --out-dir dir\n" ++
  "       leanfran-c {sync|status} [--dir dir]\n" ++
  "       leanfran-c check [--dir dir] [--require proved]\n" ++
  "       leanfran-c translate --block name --out file.lean [--import Module]... file.c [-- clang-arg...]\n" ++
  "       leanfran-c obligations check --modules Module... --obligations file.json\n" ++
  "       leanfran-c --version | --generator-version | --help\n" ++
  "exit codes: 0 success, 1 out-of-date output or unmet obligations (status, check), " ++
    "252 invalid parameters, 254 input that cannot be converted, 255 other errors"

def parse (command : String) (args : List String) : Except String CliCommand := do
  if ["sync", "status", "check"].contains command then
    let mut dir := none
    let mut require := false
    let mut rest := args
    while let key :: tail := rest do
      match key, tail with
      | "--dir", value :: tail =>
        if dir.isSome then throw "duplicate option '--dir'"
        unless !value.isEmpty && !value.startsWith "--" do throw "missing value for '--dir'"
        dir := some value
        rest := tail
      | "--require", value :: tail =>
        unless command == "check" && value == "proved" do
          throw s!"expected '{command} [--dir dir]{if command == "check" then " [--require proved]" else ""}'"
        if require then throw "duplicate option '--require'"
        require := true
        rest := tail
      | _, _ => throw s!"expected '{command} [--dir dir]{if command == "check" then " [--require proved]" else ""}'"
    let embed := if command == "sync" then Embed.Command.sync
      else if command == "status" then .status else .check require
    return .embed embed ⟨dir.getD "."⟩
  unless command == "generate" || command == "build" do throw s!"unknown command '{command}'"
  let mut remaining := args
  let mut renames : Renames := {}
  let mut opts : Std.HashMap String String := {}
  let mut switches : Std.HashSet String := {}
  while let key :: rest := remaining do
    if (command == "generate" && ["--allow-sorry", "--allow-lean-import"].contains key) ||
        (command == "build" && key == "--shared") then
      if switches.contains key then throw s!"duplicate option '{key}'"
      switches := switches.insert key
      remaining := rest
      continue
    let known := key == "--out-dir" ||
      (command == "generate" && ["--module-name", "--roots", "--prefix", "--rename"].contains key)
    unless known do throw s!"unknown option '{key}'"
    if opts.contains key then throw s!"duplicate option '{key}'"
    let value :: tail := rest | throw s!"missing value for '{key}'"
    if value.isEmpty || value.startsWith "--" then throw s!"missing value for '{key}'"
    if key == "--rename" then
      let [leanName, cName] := value.splitOn "=" | throw "expected --rename Lean.Name=c_name"
      unless !leanName.isEmpty && cIdentifier cName do throw s!"invalid rename '{value}'"
      let name := leanName.toName
      if renames.contains name then throw s!"duplicate rename for '{leanName}'"
      renames := renames.insert name cName
    else
      opts := opts.insert key value
    remaining := tail
  let some out := opts["--out-dir"]? | throw "missing --out-dir"
  if command == "build" then return .build ⟨out⟩ (switches.contains "--shared")
  let some moduleName := opts["--module-name"]? | throw "missing --module-name"
  unless validModule moduleName do throw s!"invalid module name '{moduleName}'"
  let cPrefix := opts["--prefix"]?.getD (snakeCase (lastComponent moduleName.toName))
  unless validPrefix cPrefix do throw s!"invalid C prefix '{cPrefix}'"
  let rootNames := opts["--roots"]?.map (·.splitOn ",") |>.getD []
  if rootNames.any String.isEmpty then throw "empty declaration name in --roots"
  return .generate {moduleName, cPrefix} ⟨out⟩ (rootNames.map String.toName).toArray
    {allowSorry := switches.contains "--allow-sorry",
      allowLeanImport := switches.contains "--allow-lean-import"} renames

unsafe def main (args : List String) : IO UInt32 := do
  if args == ["--help"] then
    IO.println usage
    return 0
  if args == ["--version"] then
    IO.println s!"leanfran-c {Embed.releaseVersion} (Lean {Lean.versionString})"
    return 0
  if args == ["--generator-version"] then
    IO.println Embed.generatorVersion
    return 0
  let command :: rest := args | IO.eprintln usage; return 252
  if command == "translate" then return ← Verify.translateMain rest
  if command == "obligations" then return ← Verify.obligationsMain rest
  let cmd ← match parse command rest with
    | .ok cmd => pure cmd
    | .error message => IO.eprintln s!"leanfran-c: {message}\n{usage}"; return 252
  try
    match cmd with
    | .embed command dir =>
      try return ← Embed.execute command dir
      catch error => IO.eprintln error; return 254
    | .build out shared => build (← loadWorkspace (← IO.Process.getCurrentDir)) out shared
    | .generate target out roots checks renames =>
      if let .error message ← generate (← loadWorkspace (← IO.Process.getCurrentDir)) target out roots checks renames then
        IO.eprintln s!"leanfran-c: {message}"
        return 254
    return 0
  catch error =>
    IO.eprintln s!"leanfran-c: {error}"
    return 255
