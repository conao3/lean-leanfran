import LeanC

open Lean LeanC System

inductive CliCommand where
  | generate (target : Target) (out : FilePath) (roots : Array Name) (renames : Renames)
  | build (out : FilePath)

def usage : String :=
  "Usage: leanfran-c generate --module-name M [--roots name,...] [--prefix prefix] [--rename Lean.Name=c_name] --out-dir dir\n" ++
  "       leanfran-c build --out-dir dir"

def parse (command : String) (args : List String) : Except String CliCommand := do
  unless command == "generate" || command == "build" do throw s!"unknown command '{command}'"
  let mut remaining := args
  let mut renames : Renames := {}
  let mut opts : Std.HashMap String String := {}
  while let key :: rest := remaining do
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
  if command == "build" then return .build ⟨out⟩
  let some moduleName := opts["--module-name"]? | throw "missing --module-name"
  unless validModule moduleName do throw s!"invalid module name '{moduleName}'"
  let cPrefix := opts["--prefix"]?.getD (snakeCase (lastComponent moduleName.toName))
  unless validPrefix cPrefix do throw s!"invalid C prefix '{cPrefix}'"
  let rootNames := opts["--roots"]?.map (·.splitOn ",") |>.getD []
  if rootNames.any String.isEmpty then throw "empty declaration name in --roots"
  return .generate {moduleName, cPrefix} ⟨out⟩ (rootNames.map String.toName).toArray renames

unsafe def main (args : List String) : IO UInt32 := do
  if args == ["--help"] then
    IO.println usage
    return 0
  if args == ["--version"] then
    IO.println s!"leanfran-c (Lean {Lean.versionString})"
    return 0
  let command :: rest := args | IO.eprintln usage; return 252
  let cmd ← match parse command rest with
    | .ok cmd => pure cmd
    | .error message => IO.eprintln s!"leanfran-c: {message}\n{usage}"; return 252
  try
    let ws ← loadWorkspace
    match cmd with
    | .build out => build ws out
    | .generate target out roots renames =>
      if let .error message ← generate ws target out roots renames then
        IO.eprintln s!"leanfran-c: {message}"
        return 254
    return 0
  catch error =>
    IO.eprintln s!"leanfran-c: {error}"
    return 255
