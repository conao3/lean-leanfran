import Lean.Data.Json

open Lean System

namespace LeanC.ClangAst

structure Location where
  file : FilePath
  offset : Nat := 0
  column : Nat := 1
  deriving Inhabited

structure Node where
  json : Json
  location : Location
  children : Array Node
  deriving Inhabited

def Node.get? (node : Node) (key : String) : Option Json :=
  (node.json.getObjVal? key).toOption

def Node.string (node : Node) (key : String) : String :=
  (node.get? key >>= (·.getStr?.toOption)).getD ""

def Node.kind (node : Node) : String :=
  node.string "kind"

def Node.typeName (node : Node) (key : String := "qualType") : String :=
  ((node.get? "type").getD .null |>.getObjValAs? String key).toOption.getD ""

private def bareLocation (loc : Json) (last : FilePath) : FilePath :=
  (loc.getObjValAs? String "file").toOption.map FilePath.mk |>.getD last

private def sourceLocation (loc : Json) (last : FilePath) : Option Location × FilePath :=
  match loc.getObjVal? "expansionLoc" with
  | .ok expansion =>
    let spelling := bareLocation ((loc.getObjVal? "spellingLoc").toOption.getD .null) last
    let file := bareLocation expansion spelling
    let offset := (expansion.getObjValAs? Nat "offset").toOption.getD 0
    let column := (expansion.getObjValAs? Nat "col").toOption.getD 1
    (some {file, offset, column}, file)
  | .error _ =>
    match loc.getObjValAs? Nat "offset" with
    | .ok offset =>
      let file := bareLocation loc last
      let column := (loc.getObjValAs? Nat "col").toOption.getD 1
      (some {file, offset, column}, file)
    | .error _ => (none, last)

private partial def readNode (json : Json) (parent : Location) (last : FilePath) : Node × FilePath :=
  let (loc, last) := sourceLocation ((json.getObjVal? "loc").toOption.getD .null) last
  let range := (json.getObjVal? "range").toOption.getD .null
  let (begin, last) := sourceLocation ((range.getObjVal? "begin").toOption.getD .null) last
  let (_, last) := sourceLocation ((range.getObjVal? "end").toOption.getD .null) last
  let location := (loc <|> begin).getD parent
  let (children, last) := ((json.getObjVal? "inner" >>= (·.getArr?)).toOption.getD #[]).foldl
    (fun (children, last) child =>
      let (node, last) := readNode child location last
      (children.push node, last)) (#[], last)
  ({json, location, children}, last)

partial def Node.walk (node : Node) : Array Node :=
  #[node] ++ node.children.flatMap Node.walk

def parse (file : FilePath) (input : String) : Except String Node := do
  let json ← Json.parse input
  let root := (readNode json {file} file).1
  unless root.kind == "TranslationUnitDecl" do throw "expected a clang translation unit"
  return root

structure CompileCommand where
  directory : FilePath
  file : FilePath
  flags : Array String
  deriving Inhabited, BEq

def absolute (dir path : FilePath) : FilePath :=
  let path := (if path.isAbsolute then path else dir / path).normalize
  let parts := path.components.foldl (init := #[]) fun parts part =>
    if part == "." || (part.isEmpty && !parts.isEmpty) then parts
    else if part == ".." && parts.size > 1 then parts.pop
    else parts.push part
  ⟨"/".intercalate parts.toList⟩

private def splitCommand (command : String) : Except String (Array String) := do
  let mut quote := none
  let mut escaped := false
  let mut word := none
  let mut words := #[]
  for c in command.toList do
    if escaped then
      word := some ((word.getD "").push c)
      escaped := false
    else if c == '\\' && quote != some '\'' then
      escaped := true
    else if some c == quote then
      quote := none
    else if quote.isNone && (c == '"' || c == '\'') then
      quote := some c
      word := some (word.getD "")
    else if quote.isNone && c.isWhitespace then
      if let some value := word then words := words.push value
      word := none
    else
      word := some ((word.getD "").push c)
  if escaped || quote.isSome then throw "unterminated quote or escape in compile command"
  return if let some value := word then words.push value else words

private def compileFlags (directory file : FilePath) (argv : Array String) : Array String := Id.run do
  let mut flags := #[]
  let mut args := (argv.toList.drop 1).dropWhile (fun arg => ["ccache", "sccache", "distcc"].contains
    ((FilePath.mk arg).fileName.getD ""))
  if ["ccache", "sccache", "distcc"].contains ((FilePath.mk (argv[0]?.getD "")).fileName.getD "") then
    args := args.drop 1
  while let arg :: rest := args do
    args := rest
    if ["-o", "-MF", "-MT", "-MQ", "-MJ", "--serialize-diagnostics"].contains arg then
      args := rest.drop 1
    else if ["-c", "-S", "-E", "-MD", "-MMD", "-MP", "-MG", "-M", "-MM", "--"].contains arg ||
        (["-o", "-MF", "-MT", "-MQ", "-MJ"].any (fun flag => arg.startsWith flag)) then
      continue
    else if !arg.startsWith "-" && absolute directory ⟨arg⟩ == file then
      continue
    else
      flags := flags.push arg
  return flags

def readDatabase (root : FilePath) : IO (Array CompileCommand) := do
  let path := root / "compile_commands.json"
  unless ← path.pathExists do return #[]
  let source ← IO.FS.readFile path
  let result : Except String (Array CompileCommand) := do
    (← (← Json.parse source).getArr?).mapM fun entry => do
      let directory := absolute root ⟨← entry.getObjValAs? String "directory"⟩
      let file := absolute directory ⟨← entry.getObjValAs? String "file"⟩
      let argv ← match entry.getObjVal? "arguments" with
        | .ok args => fromJson? args
        | .error _ => splitCommand (← entry.getObjValAs? String "command")
      if argv.isEmpty then throw s!"empty compile command for {file}"
      return {directory, file, flags := compileFlags directory file argv}
  IO.ofExcept (result.mapError fun message => s!"{path}: {message}")

def dump (command : CompileCommand) (extra : Array String := #[]) : IO Node := do
  let output ← IO.Process.output {
    cmd := "clang", cwd := some command.directory
    args := extra ++ command.flags ++ #["-Xclang", "-ast-dump=json", "-fsyntax-only", command.file.toString] }
  unless output.exitCode == 0 do
    throw <| IO.userError s!"{command.file}: clang exited with {output.exitCode}\n{output.stderr}"
  IO.ofExcept ((parse command.file output.stdout).mapError fun message => s!"{command.file}: {message}")

def dependencies (command : CompileCommand) (extra : Array String := #[]) : IO (Array FilePath) := do
  let result ← IO.Process.output {
    cmd := "clang", cwd := some command.directory
    args := extra ++ command.flags ++ #["-MM", "-MG", "-MT", "leanfran", command.file.toString] }
  unless result.exitCode == 0 do return #[]
  let deps := ((result.stdout.drop "leanfran:".length).toString.replace "\\\n" " ")
  let mut paths := #[]
  let mut escaped := false
  let mut path := ""
  for c in deps.toList do
    if escaped then
      path := path.push c
      escaped := false
    else if c == '\\' then
      escaped := true
    else if c.isWhitespace then
      unless path.isEmpty do
        paths := paths.push (absolute command.directory ⟨path.replace "$$" "$"⟩)
        path := ""
    else
      path := path.push c
  return paths

end LeanC.ClangAst
