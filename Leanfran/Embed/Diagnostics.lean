import Leanfran.Embed.Types

open Lean System

namespace Leanfran.Embed.Diagnostics

def unitLength (unit : ColumnUnit) (text : String) : Nat :=
  match unit with
  | .byte => text.utf8ByteSize
  | .codePoint => text.length
  | .utf16 => text.toList.foldl (fun n c => n + if c.val > 0xFFFF then 2 else 1) 0

private def lineStarts (bytes : ByteArray) : Array Nat := Id.run do
  let mut starts := #[0]
  for i in [0:bytes.size] do
    if bytes[i]! == 10 then starts := starts.push (i + 1)
  return starts

private def slice (bytes : ByteArray) (start stop : Nat) : String :=
  (String.fromUTF8? (bytes.extract start stop)).getD ""

structure Position where
  line : Nat
  column : Nat
  row : Nat

def locate (unit : ColumnUnit) (block : Block) (row col : Nat) : Position := Id.run do
  let r : Int := row - (block.prelude.toList.filter (· == '\n')).length
  let bytes := block.text.toUTF8
  let starts := lineStarts bytes
  if r < 1 || r.toNat > starts.size then
    return {line := block.origin.line, column := block.origin.column, row := r.toNat}
  let start := starts[r.toNat - 1]!
  let stop := starts[r.toNat]?.getD (bytes.size + 1) - 1
  let lineText := slice bytes start (min stop bytes.size)
  let o := start + (String.ofList (lineText.toList.take col)).utf8ByteSize
  let some entry := block.map.toList.reverse.find? (·.offset ≤ o)
    | return {line := block.origin.line, column := block.origin.column, row := r.toNat}
  return {line := entry.line, column := entry.column + unitLength unit (slice bytes entry.offset o), row := r.toNat}

private def severities : List String := ["error", "warning", "info"]

private structure Message where
  path : String
  row : Nat
  column : Nat
  severity : String
  text : String

private def parseLocated (rest : String) : Option (String × Nat × Nat × String) := do
  let path :: row :: column :: message := rest.splitOn ":" | none
  let row ← row.toNat?
  let column ← column.toNat?
  return (path, row, column, (":".intercalate message).trimAscii.toString)

private def parse (line : String) : Option Message := do
  if let some severity := severities.find? (line.startsWith s!"{·}: ") then
    let (path, row, column, text) ← parseLocated (line.drop (severity.length + 2)).toString
    return {path, row, column, severity, text}
  let (path, row, column, text) ← parseLocated line
  let some severity := severities.find? (text.startsWith s!"{·}: ") | none
  return {path, row, column, severity, text := (text.drop (severity.length + 2)).trimAscii.toString}

private partial def normalize (workspace : FilePath) (path : String) : String :=
  if path.startsWith "./" then normalize workspace (path.drop 2).toString
  else match relativeTo workspace path with
    | some relative => relative
    | none => path

private def duplicate (root : FilePath) (blocks : Array Block) (line : String) : IO (Option String) := do
  let [_, rest] := line.splitOn "import " | return none
  let [later, rest] := rest.splitOn " failed, environment already contains '" | return none
  let [name, earlier] := rest.splitOn "' from " | return none
  let some later := blocks.find? (·.module == later) | return none
  let some earlier := blocks.find? (·.module == earlier.trimAscii.toString) | return none
  return some (s!"{← display root later.origin.file}:{later.origin.line}:1: error: Lean blocks '{earlier.name}' " ++
    s!"({earlier.origin.file}:{earlier.origin.line}) and '{later.name}' both define '{name}'; " ++
    "the definitions of all Lean blocks share one namespace")

def remapLine (root workspace : FilePath) (unit : ColumnUnit) (blocks : Array Block) (files : Array WorkspaceFile)
    (line : String) : IO String := do
  if let some message ← duplicate root blocks line then return message
  let some message := parse line | return line
  let path := normalize workspace message.path
  if let some block := blocks.find? (·.path == path) then
    let pos := locate unit block message.row message.column
    return s!"{← display root block.origin.file}:{pos.line}:{pos.column}: {message.severity}: " ++
      s!"(lean block {block.name}, Lean {pos.row}:{message.column}) {message.text}"
  if let some file := files.find? (·.path == path) then
    if let some origin := file.origin then
      return s!"{← display root origin.file}:{origin.line}:{origin.column}: {message.severity}: " ++
        s!"(lean module {file.path}, Lean {message.row}:{message.column}) {message.text}"
  return line

def remap (root workspace : FilePath) (unit : ColumnUnit) (blocks : Array Block) (files : Array WorkspaceFile)
    (verbose : Bool) (output : String) : IO String := do
  let lines := (output.splitOn "\n").filter fun line => verbose || !line.startsWith "trace:"
  return "\n".intercalate (← lines.mapM (remapLine root workspace unit blocks files))

end Leanfran.Embed.Diagnostics
