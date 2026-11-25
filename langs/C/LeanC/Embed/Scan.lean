import Lake.Toml.Load
import LeanC.Export

open Lean Lake System

namespace LeanC.Embed

structure Config where
  source : String
  sources : Array String
  leanFiles : Array String
  cflags : Array String
  out : FilePath
  requirements : Toml.Table

private def failAt (file : FilePath) (line : Nat) (message : String) : IO α :=
  throw <| IO.userError s!"{file}:{line}:1: error: {message}"

private def strings (table : Toml.Table) (key : Name) : Except String (Array String) := do
  match table.find? key with
  | none => return #[]
  | some (.array _ values) => values.mapM fun
    | .string _ value => pure value
    | _ => throw s!"'{key}' must be an array of strings"
  | _ => throw s!"'{key}' must be an array of strings"

private def relativeParts (path : String) : Except String (List String) := do
  let parts := (path.splitOn "/").filter (· != ".")
  if (FilePath.mk path).isAbsolute || parts.isEmpty ||
      parts.any (fun part => part.isEmpty || part == ".." || part.contains '\x00') then
    throw s!"expected a path inside the project, got '{path}'"
  return parts

def readConfig (root : FilePath) : IO Config := do
  let path := root / "leanfran.toml"
  let source ← IO.FS.readFile path
  let table ← match ← (Toml.loadToml (Parser.mkInputContext source path.toString)).toBaseIO with
    | .ok table => pure table
    | .error messages =>
      throw <| IO.userError ("".intercalate (← messages.toList.mapM (fun message => (message.toString : IO String))))
  let result : Except String Config := do
    let sources ← strings table `sources
    let leanFiles ← strings table `«lean-files»
    let cflags ← strings table `cflags
    for pattern in sources ++ leanFiles do discard <| relativeParts pattern
    let out ← match table.find? `«out-dir» with
      | none => pure "leanfran"
      | some (.string _ value) => pure value
      | _ => throw "'out-dir' must be a string"
    let parts ← relativeParts out
    if [".leanfran", ".git", "leanfran.toml"].contains parts.head!.toLower then
      throw s!"reserved output path '{out}'"
    let requirements ← match table.find? `require with
      | none => pure Toml.Table.empty
      | some (.array ref values) => do
        let values ← values.mapM fun
          | .table ref dep => do
            let dep ← match dep.find? `path with
              | some (.string ref path) =>
                let path := FilePath.mk path
                pure (dep.insert `path (.string ref (if path.isAbsolute then path else root / path).toString))
              | none => pure dep
              | _ => throw "a Lake dependency 'path' must be a string"
            pure (.table ref dep)
          | _ => throw "'require' must contain Lake dependency tables"
        pure (Toml.Table.empty.insert `require (.array ref values))
      | _ => throw "'require' must contain Lake dependency tables"
    return {source, sources, leanFiles, cflags, out := root / String.intercalate "/" parts, requirements}
  match result with
  | .ok config => return config
  | .error message => failAt path 1 message

private def inClass (c : Char) : List Char → Bool
  | first :: '-' :: last :: rest => (first ≤ c && c ≤ last) || inClass c rest
  | first :: rest => first == c || inClass c rest
  | [] => false

private def matchComponent (pattern name : String) : Bool := Id.run do
  let chars := name.toList.toArray
  let mut matched := #[true] ++ chars.map (fun _ => false)
  let mut pattern := pattern.toList
  while let token :: tail := pattern do
    pattern := tail
    let mut advance : Char → Bool := (· == token)
    if token == '*' then
      for i in [0:chars.size] do
        matched := matched.set! (i + 1) (matched[i]! || matched[i + 1]!)
      continue
    if token == '?' then advance := fun _ => true
    if token == '[' then
      let items := tail.takeWhile (· != ']')
      if !items.isEmpty && tail.length > items.length then
        pattern := tail.drop (items.length + 1)
        advance := match items with
          | '!' :: rest => fun c => !inClass c rest
          | _ => fun c => inClass c items
    matched := #[false] ++ (chars.mapIdx fun i c => matched[i]! && advance c)
  return matched.back!

private partial def matchFiles (dir out : FilePath) (pattern : List String) : IO (Array FilePath) := do
  let part :: tail := pattern | return #[]
  let mut files := #[]
  if part == "**" && !tail.isEmpty then
    files ← matchFiles dir out tail
  for entry in ← dir.readDir do
    if entry.path == out || [".git", ".leanfran"].contains entry.fileName then continue
    if !matchComponent part entry.fileName then continue
    let metadata ← entry.path.symlinkMetadata
    if metadata.type == .dir then
      if part == "**" then
        files := files ++ (← matchFiles entry.path out pattern)
      else if !tail.isEmpty then
        files := files ++ (← matchFiles entry.path out tail)
    else if metadata.type == .file && tail.isEmpty then
      files := files.push entry.path
  return files

private def filesFor (root out : FilePath) (patterns : Array String) : IO (Array FilePath) := do
  let mut files : Std.HashSet FilePath := {}
  for pattern in patterns do
    let parts ← IO.ofExcept (relativeParts pattern)
    for path in ← matchFiles root out parts do
      files := files.insert path
  return files.toArray.qsort (fun a b => a.toString < b.toString)

structure Block where
  name : String
  file : FilePath
  line : Nat
  bodyLine : Nat
  source : String
  imports : Array String := #[]
  deriving Inhabited

def Block.moduleName (name : String) : String := s!"LeanfranBlocks.{name}"

private def validBlockName (name : String) : Bool :=
  cIdentifier name && name.toList.all (fun c => c.toNat < 128) &&
    !["lf", "leanfran"].contains name.toLower

private structure SourceChar where
  char : Char := '\x00'
  offset : Nat := 0
  line : Nat := 1
  deriving Inhabited

private def spliceLines (source : Array Char) : Array SourceChar := Id.run do
  let mut chars := #[]
  let mut line := 1
  let mut i := 0
  while i < source.size do
    if source[i]! == '\\' && source[i + 1]? == some '\n' then
      line := line + 1
      i := i + 2
    else
      let char := source[i]!
      chars := chars.push {char, offset := i, line}
      if char == '\n' then line := line + 1
      i := i + 1
  return chars

private def blockAt (file : FilePath) (line headerLine : Nat) (comment : String) : IO (Option Block) := do
  let header := ((comment.splitOn "\n").head!).trimAscii.toString
  let keyword := "leanfran:lean"
  if header != keyword && !(header.startsWith (keyword ++ " ")) &&
      !(header.startsWith (keyword ++ "\t")) then
    return none
  let name := (header.drop keyword.length).trimAscii.toString
  unless validBlockName name do failAt file line s!"invalid Lean block name '{name}'"
  let lines := (comment.splitOn "\n").drop 1
  let first := (lines.headD "").trimAscii.toString
  if first.startsWith "imports:" then
    let imports := ((first.drop "imports:".length).toString.splitOn ",").map (·.trimAscii.toString)
    for name in imports do
      unless validBlockName name do failAt file (headerLine + 1) s!"invalid Lean block import '{name}'"
    return some {
      name, file, line, bodyLine := headerLine + 2, imports := imports.toArray,
      source := "\n".intercalate (lines.drop 1)}
  return some {name, file, line, bodyLine := headerLine + 1, source := "\n".intercalate lines}

structure ModelSource where
  path : FilePath
  line : Nat
  deriving Inhabited

private def scanC (file : FilePath) (source : String) : IO (Array Block × Option Nat × Bool) := do
  let source := (source.replace "\r\n" "\n").toList.toArray
  let chars := spliceLines source
  let charAt := fun i => chars[i]!.char
  let next := fun i c => i < chars.size && charAt i == c
  let mut blocks := #[]
  let mut modelLine := none
  let mut verified := false
  let mut i := 0
  while i < chars.size do
    let char := charAt i
    if char == '/' && next (i + 1) '/' then
      i := i + 2
      while i < chars.size && charAt i != '\n' do i := i + 1
    else if char == '"' || char == '\'' then
      i := i + 1
      while i < chars.size && charAt i != '\n' do
        let c := charAt i
        i := i + 1
        if c == char then break
        if c == '\\' then i := i + 1
    else if char == '/' && next (i + 1) '*' then
      let line := chars[i]!.line
      let star := chars[i + 1]!
      let start := star.offset + 1
      i := i + 2
      while i < chars.size && !(charAt i == '*' && next (i + 1) '/') do i := i + 1
      let stop := if i < chars.size then chars[i]!.offset else source.size
      if let some block ← blockAt file line star.line (String.ofList (source.extract start stop).toList) then
        if i == chars.size then failAt file line "unterminated Lean block"
        blocks := blocks.push block
      i := i + 2
    else if char.isAlphanum || char == '_' then
      let start := i
      while i < chars.size && ((charAt i).isAlphanum || charAt i == '_') do i := i + 1
      let word := String.ofList ((chars.extract start i).toList.map (·.char))
      if modelLine.isNone && word == "LF_STRUCT" then
        modelLine := some chars[start]!.line
      if word == "LF_MODEL" then verified := true
    else
      i := i + 1
  return (blocks, modelLine, verified)

def scan (root : FilePath) (config : Config) : IO (Array Block × Array ModelSource × Array FilePath) := do
  let mut blocks := #[]
  let mut models := #[]
  let mut verified := #[]
  for path in ← filesFor root config.out config.sources do
    let file := FilePath.mk ((path.toString.drop (root.toString.length + 1)).toString)
    let (found, modelLine, model) ← scanC file (← IO.FS.readFile path)
    blocks := blocks ++ found
    if let some line := modelLine then models := models.push {path, line}
    if model then verified := verified.push path
  for path in ← filesFor root config.out config.leanFiles do
    let file := FilePath.mk ((path.toString.drop (root.toString.length + 1)).toString)
    let name := path.fileStem.getD ""
    unless path.extension == some "lean" && validBlockName name do
      failAt file 1 s!"expected a .lean file with a valid block name, got '{path}'"
    blocks := blocks.push {name, file, line := 1, bodyLine := 1, source := ← IO.FS.readFile path}
  let mut seen : Std.HashMap String Block := {}
  for block in blocks do
    if let some first := seen[block.name]? then
      failAt block.file block.line s!"duplicate Lean block '{block.name}' (first at {first.file}:{first.line})"
    seen := seen.insert block.name block
  for block in blocks do
    for name in block.imports do
      unless seen.contains name do
        failAt block.file (block.bodyLine - 1) s!"unknown Lean block import '{name}'"
  return (blocks.qsort (·.name < ·.name), models, verified)

end LeanC.Embed
