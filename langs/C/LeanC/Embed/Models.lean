import LeanC.ClangAst
import LeanC.Embed.Scan

open Lean System
open LeanC.ClangAst

namespace LeanC.Embed

structure Models where
  source : String := ""
  blocks : Array String := #[]
  types : ExternalTypes := {}
  flags : Array String := #[]
  inputs : Array FilePath := #[]
  headers : Array (String × FilePath) := #[]

private def supportHeader := include_str "../../support/leanfran.h"

private def locationError (loc : Location) (message : String) : IO α := do
  let source ← IO.FS.readBinFile loc.file
  let line := 1 + (source.extract 0 loc.offset).data.countP (· == 10)
  throw <| IO.userError s!"{loc.file}:{line}:{loc.column}: error: {message}"

private def annotation (attr : Node) : Option (Array String) := do
  guard (attr.kind == "AnnotateAttr")
  attr.children.mapM fun expr => do
    let literal ← expr.walk.find? (·.kind == "StringLiteral")
    let .ok (.str value) := Json.parse (literal.string "value") | none
    return value

private def annotations (node : Node) (kind : String) : Array (Array String) :=
  node.children.filterMap fun attr => do
    let args ← annotation attr
    guard (args[0]? == some kind)
    return args.extract 1 args.size

private def fields (record : Node) : Array Node :=
  record.children.filter (·.kind == "FieldDecl")

private def tagId (node : Node) : Option String := do
  let info ← node.get? "ownedTagDecl" <|> node.get? "decl"
  guard ((info.getObjValAs? String "kind").toOption == some "RecordDecl")
  (info.getObjValAs? String "id").toOption

private def recordIndex (nodes : Array Node) : Std.HashMap String Node := Id.run do
  let mut records : Std.HashMap String Node := {}
  let mut byId : Std.HashMap String Node := {}
  for node in nodes do
    if node.kind != "RecordDecl" || (node.get? "completeDefinition") != some (.bool true) then continue
    byId := byId.insert (node.string "id") node
    let tag := node.string "name"
    unless tag.isEmpty do records := records.insert s!"struct {tag}" node
  for node in nodes do
    if node.kind != "TypedefDecl" then continue
    let ids := node.walk.filterMap tagId
    let some record := ids.findSome? (fun id => byId[id]?) <|> records[node.typeName]? | continue
    records := records.insert (node.string "name") record
  return records

private structure ModelRecord where
  block : String
  name : String
  external : ExternalType
  node : Node
  records : Std.HashMap String Node
  deriving Inhabited

private def validIdentifier (name : String) : Bool :=
  cIdentifier name && name.toList.all (fun c => c.toNat < 128)

private def leanIdent (name : String) : String := s!"«{name}»"

private def relativePath (dir file : FilePath) : String :=
  let base := dir.normalize.components
  let target := file.normalize.components
  let common := (base.zip target).takeWhile (fun (a, b) => a == b) |>.length
  "/".intercalate ((base.drop common).map (fun _ => "..") ++ target.drop common)

private def checkedHeader (out file : FilePath) (loc : Location) : IO String := do
  let header := relativePath out file
  if header.toList.any (fun c => c == '"' || c == '\\' || c == '\n' || c == '\r') then
    locationError loc s!"unsupported path in generated C header: '{header}'"
  return header

private def readRecords (command : CompileCommand) (extra : Array String) (file out : FilePath)
    (blocks : Array Block) : IO (Array ModelRecord) := do
  let nodes := (← dump command extra).walk
  let records := recordIndex nodes
  let mut result := #[]
  for node in nodes do
    if node.kind != "RecordDecl" || absolute command.directory node.location.file != file then continue
    let node := {node with location := {node.location with file}}
    let attrs := annotations node "struct"
    if attrs.isEmpty then continue
    let #[#[block]] := attrs | locationError node.location "expected one LF_STRUCT(block) on the struct definition"
    unless blocks.any (·.name == block) do
      locationError node.location s!"LF_STRUCT refers to unknown Lean block '{block}'"
    unless (node.get? "completeDefinition") == some (.bool true) && node.string "tagUsed" == "struct" do
      locationError node.location "LF_STRUCT requires a complete struct definition"
    unless file.extension == some "h" do
      locationError node.location "declare LF_STRUCT in a C header so the generated API can include it"
    let tag := node.string "name"
    let aliases := records.toArray.filterMap fun (name, record) =>
      if record.string "id" == node.string "id" && validIdentifier name then some name else none
    let name := if validIdentifier tag then tag else (aliases.qsort (· < ·))[0]?.getD ""
    unless validIdentifier name do
      locationError node.location "LF_STRUCT requires a struct tag or a typedef name"
    let cType := if validIdentifier tag then s!"struct {tag}" else name
    result := result.push {block, name, node, records, external := {header := ← checkedHeader out file node.location, cType}}
  return result

private def primitiveType (ty : String) : Option String :=
  [("bool", "Bool"), ("_Bool", "Bool"), ("uint8_t", "UInt8"), ("uint16_t", "UInt16"),
    ("uint32_t", "UInt32"), ("uint64_t", "UInt64"), ("int8_t", "Int8"), ("int16_t", "Int16"),
    ("int32_t", "Int32"), ("int64_t", "Int64"), ("size_t", "USize"), ("float", "Float32"),
    ("double", "Float"), ("lf_str", "String"), ("lf_nat", "Nat"), ("lf_int", "Int"),
    ("lf_byte_array", "ByteArray"), ("lf_float_array", "FloatArray")].lookup ty

private structure FieldType where
  lean : String
  dependency : Option String := none
  array : Option (Name × ExternalType × String) := none

private def typeOf (models : Array ModelRecord) (records : Std.HashMap String Node) (ty : String) :
    Option FieldType := do
  if let some lean := primitiveType ty then return {lean}
  let decl ← records[ty]?
  let tag := decl.string "name"
  let model ← models.find? fun model =>
    model.name == tag || (tag.isEmpty && model.external.cType == ty)
  return {lean := leanIdent model.name, dependency := some model.name}

private def sourceType (models : Array ModelRecord) (model : ModelRecord) (field : Node) :
    IO FieldType := do
  let ty := field.typeName
  if let some type := typeOf models model.records ty <|>
    typeOf models model.records (field.typeName "desugaredQualType") then
    return type
  let unsupported := s!"unsupported LF_STRUCT field type '{ty}'"
  let some record := model.records[ty]? <|> model.records[field.typeName "desugaredQualType"]?
    | locationError field.location unsupported
  let arrayFields := fields record
  let some items := arrayFields.find? (·.string "name" == "items")
    | locationError field.location unsupported
  let some len := arrayFields.find? (·.string "name" == "len")
    | locationError field.location unsupported
  let itemPtr := items.typeName
  unless arrayFields.size == 2 && len.typeName == "size_t" && itemPtr.endsWith "*" &&
      record.string "tagUsed" == "struct" do locationError field.location unsupported
  let item := (itemPtr.dropEnd 1).trimAscii.toString
  let some type := typeOf models model.records item | locationError field.location unsupported
  let alias := if validIdentifier ty then ty else record.string "name"
  unless validIdentifier alias do locationError field.location unsupported
  let alias := s!"{model.name}_{alias}"
  return {
    lean := s!"LeanfranArrays.{leanIdent alias}", dependency := type.dependency,
    array := some (Name.mkSimple alias, {model.external with cType := ty}, s!"Array {type.lean}") }

private def constraint (field : String) (ty : FieldType) (text : String) :
    Except String (String × String) := do
  let [key, value] := text.splitOn "=" | throw s!"expected LF_FIELD(\"key=value\"), got '{text}'"
  let some number := value.toInt? | throw s!"'{text}' requires a decimal integer"
  let id := leanIdent field
  if let some rel := [("ge", "≥"), ("gt", ">"), ("le", "≤"), ("lt", "<")].lookup key then
    let lhs ←
      if ty.lean == "Nat" then pure s!"Int.ofNat {id}"
      else if ty.lean == "Int" then pure id
      else if ["UInt8", "UInt16", "UInt32", "UInt64", "USize"].contains ty.lean then
        pure s!"Int.ofNat {id}.toNat"
      else if ["Int8", "Int16", "Int32", "Int64"].contains ty.lean then pure s!"{id}.toInt"
      else throw s!"'{key}' requires an integer field"
    return (s!"{field}_{key}", s!"{lhs} {rel} ({number} : Int)")
  if key == "min_len" || key == "max_len" then
    let projection ← if ty.lean == "String" then pure "length"
      else if ty.lean == "ByteArray" || ty.lean == "FloatArray" || ty.array.isSome then pure "size"
      else throw s!"'{key}' requires a string or array field"
    if number < 0 then throw s!"'{key}' requires a nonnegative length"
    let rel := if key == "min_len" then "≥" else "≤"
    return (s!"{field}_{key}", s!"{id}.{projection} {rel} {number}")
  throw s!"unsupported LF_FIELD constraint '{key}'"

private structure ModelDeclaration where
  model : ModelRecord
  source : String
  dependencies : Array String
  arrays : Array (Name × ExternalType × String)
  deriving Inhabited

private def declare (models : Array ModelRecord) (model : ModelRecord) : IO ModelDeclaration := do
  let mut source := s!"structure {leanIdent model.name} where\n"
  let mut names := Std.HashSet.ofList ((fields model.node).toList.map (·.string "name"))
  let mut dependencies := #[]
  let mut arrays := #[]
  for field in fields model.node do
    let field := {field with location := {field.location with file := model.node.location.file}}
    let name := field.string "name"
    unless validIdentifier name && (field.get? "isBitfield") != some (.bool true) do
      locationError field.location "LF_STRUCT requires named fields with addressable C types"
    let type ← sourceType models model field
    source := source ++ s!"  {leanIdent name} : {type.lean}\n"
    if let some dep := type.dependency then dependencies := dependencies.push dep
    if let some arr := type.array then arrays := arrays.push arr
    for text in (annotations field "field").flatten do
      let (proof, prop) ← match constraint name type text with
        | .ok value => pure value
        | .error message => locationError field.location message
      if names.contains proof then locationError field.location s!"duplicate LF_FIELD proof '{proof}'"
      names := names.insert proof
      source := source ++ s!"  {leanIdent proof} : {prop}\n"
  return {model, source, dependencies, arrays}

private def emitModels (records : Array ModelRecord) : IO Models := do
  let mut models : Models := {}
  let mut pending ← records.mapM (declare records)
  let mut emitted : Std.HashSet String := {}
  while !pending.isEmpty do
    let some i := pending.findIdx? (fun decl => decl.dependencies.all emitted.contains)
      | locationError pending[0]!.model.node.location "recursive LF_STRUCT fields are unsupported"
    let decl := pending[i]!
    pending := pending.eraseIdxIfInBounds i
    let model := decl.model
    if emitted.contains model.name then
      locationError model.node.location s!"duplicate LF_STRUCT type '{model.name}'"
    emitted := emitted.insert model.name
    for (name, external, body) in decl.arrays do
      let qualified := `LeanfranArrays ++ name
      unless models.types.contains qualified do
        models := {models with
          source := models.source ++ s!"abbrev LeanfranArrays.{leanIdent name.toString} := {body}\n",
          types := models.types.insert qualified external}
    models := {models with
      blocks := models.blocks.push model.block
      source := models.source ++ decl.source ++ "\n"
      types := models.types.insert (Name.mkSimple model.name) model.external
      headers := models.headers.push (model.external.header, model.node.location.file)}
  return models

private def wrapperFlags (command : CompileCommand) (out : FilePath) : Array String := Id.run do
  let mut flags := #[]
  let mut args := command.flags.toList
  let paths := ["-isystem", "-iquote", "-idirafter", "-I"]
  while let flag :: tail := args do
    args := tail
    if let some p := paths.find? (flag.startsWith ·) then
      let value := (flag.drop p.length).toString
      let value := if value.isEmpty then tail.headD "" else value
      if flag == p then args := tail.drop 1
      let dir := absolute command.directory ⟨value⟩
      unless value.isEmpty || dir == absolute out "." do flags := flags ++ #[p, dir.toString]
    else if flag == "-D" || flag == "-U" then
      if let arg :: rest := tail then
        flags := flags.push (flag ++ arg)
        args := rest
    else if flag.startsWith "-D" || flag.startsWith "-U" then
      flags := flags.push flag
  return flags

private def readModelsAt (root : FilePath) (config : Config) (blocks : Array Block)
    (sources : Array ModelSource) : IO Models := do
  let clang ← (IO.Process.output {cmd := "clang", args := #["--version"]}).toBaseIO
  unless clang.toOption.any (·.exitCode == 0) do
    let src := sources[0]!
    throw <| IO.userError s!"{src.path}:{src.line}:1: error: LF_STRUCT requires clang on PATH"
  let db ← readDatabase root
  IO.FS.withTempDir fun tmp => do
    IO.FS.writeFile (tmp / "leanfran.h") supportHeader
    let extra := #["-I", tmp.toString]
    let mut records := #[]
    let mut flags := #[]
    let mut inputs := #[]
    let mut dependenciesByCommand : Std.HashMap FilePath (Array FilePath) := {}
    for src in sources do
      let mut command := db.find? (·.file == src.path)
      if command.isNone && src.path.extension == some "h" then
        for candidate in db do
          let deps ← match dependenciesByCommand[candidate.file]? with
            | some deps => pure deps
            | none => dependencies candidate extra
          dependenciesByCommand := dependenciesByCommand.insert candidate.file deps
          if deps.contains src.path then
            command := some {candidate with file := src.path}
            break
      let selected := command.getD {directory := root, file := src.path, flags := config.cflags}
      let found ← readRecords selected (extra ++ #["-x", "c"]) src.path config.out blocks
      if found.isEmpty then continue
      records := records ++ found
      flags := flags ++ wrapperFlags selected config.out
      inputs := inputs ++ (← dependencies selected extra).filter (fun path => !path.toString.startsWith (tmp.toString ++ "/"))
      inputs := inputs.push src.path
    if ← (root / "compile_commands.json").pathExists then
      inputs := inputs.push (root / "compile_commands.json")
    let models ← emitModels records
    return {models with flags, inputs := inputs.toList.eraseDups.toArray}

def readModels (root : FilePath) (config : Config) (blocks : Array Block)
    (sources : Array ModelSource) : IO Models := do
  if sources.isEmpty then return {}
  try
    readModelsAt root config blocks sources
  catch error =>
    let message := toString error
    let rootPrefix := s!"{root}/"
    throw <| IO.userError (if message.startsWith rootPrefix then (message.drop rootPrefix.length).toString else message)

end LeanC.Embed
