import Leanfran.Embed.Types

open Lean System

namespace Leanfran.Embed.Manifest

def fileName := "leanfran.manifest.json"

structure BlockEntry where
  name : String
  source : String
  hash : String
  files : Array String
  deriving FromJson, ToJson, Inhabited

structure Section where
  compiler : String := ""
  require : Array Json := #[]
  inputs : String := ""
  support : String := ""
  blocks : Array BlockEntry := #[]
  files : Array String := #[]
  deriving FromJson, ToJson, Inhabited

structure Manifest where
  languages : Array (String × Json) := #[]
  deriving Inhabited

def Manifest.section? (manifest : Manifest) (lang : String) : Option Section :=
  (manifest.languages.find? (·.1 == lang)).bind fun (_, json) => (fromJson? json).toOption

def Manifest.files (manifest : Manifest) (lang : String) : Array String :=
  match manifest.section? lang with
  | some s => s.files ++ s.blocks.flatMap (·.files)
  | none => #[]

def read (root : FilePath) : IO Manifest := do
  let .ok text ← (IO.FS.readFile (root / fileName)).toBaseIO | return {}
  let parsed : Except String Manifest := do
    let json ← Json.parse text
    unless (json.getObjValAs? String "format").toOption == some "leanfran-manifest" do return {}
    let languages ← json.getObjVal? "languages"
    return {languages := objFields languages}
  return parsed.toOption.getD {}

def sectionDoc (s : Section) : Doc :=
  .obj [("compiler", .json (toJson s.compiler)), ("require", .json (toJson s.require)),
    ("inputs", .json (toJson s.inputs)), ("support", .json (toJson s.support)),
    ("blocks", .arr (s.blocks.map fun b => .obj [("name", .json (toJson b.name)),
      ("source", .json (toJson b.source)), ("hash", .json (toJson b.hash)), ("files", .json (toJson b.files))])),
    ("files", .json (toJson s.files))]

def render (manifest : Manifest) (lang : String) (s : Option Section) : String :=
  let others := manifest.languages.filter (·.1 != lang) |>.map fun (k, v) => (k, Doc.ofJson v)
  let mine := match s with
    | some s => #[(lang, sectionDoc s)]
    | none => #[]
  let languages := (others ++ mine).qsort (·.1 < ·.1)
  Doc.render (.obj [("format", .json (toJson "leanfran-manifest")), ("version", .json (toJson (1 : Nat))),
    ("languages", .obj languages.toList)]) ++ "\n"

def blockStatus (root : FilePath) (lang : String) (compiler support : String) (manifest : Manifest) (scan : Scan) :
    IO (Array String) := do
  let s := manifest.section? lang
  let sectionFresh := s.any fun s => s.compiler == compiler && s.require == scan.require &&
    s.inputs == scan.inputs && s.support == support
  let mut rows : Array (String × String) := #[]
  for block in scan.blocks do
    let entry := s.bind fun s => s.blocks.find? (·.name == block.name)
    match entry with
    | some entry =>
      if !sectionFresh || entry.hash != block.hash then
        rows := rows.push (block.name, s!"{block.name}: stale")
      else
        let missing ← entry.files.filterM fun (file : String) => return !(← (root / file).pathExists)
        if let some file := missing[0]? then rows := rows.push (block.name, s!"{block.name}: missing {file}")
    | none => rows := rows.push (block.name, s!"{block.name}: stale")
  if let some s := s then
    for file in s.files do
      unless ← (root / file).pathExists do
        rows := rows.push (lang, s!"{lang}: missing {file}")
    for entry in s.blocks do
      if inScope scan.scope entry.source && !scan.blocks.any (·.name == entry.name) then
        rows := rows.push (entry.name, s!"{entry.name}: removed")
  for path in scan.stray do
    if ← (root / path).pathExists then rows := rows.push (path, s!"{path}: removed")
  return (rows.qsort (·.1 < ·.1)).map (·.2)

end Leanfran.Embed.Manifest
