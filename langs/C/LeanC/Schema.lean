import LeanC.Export
import Lean.Data.Json

open Lean

namespace LeanC

private def obj := Json.mkObj

private def jsType (name : String) : Json :=
  obj [("type", toJson name)]

private def integer (value : Int) : Json :=
  toJson value

private def schemaNumber (value : Int) : Json := Id.run do
  let n := value.natAbs
  if n <= 2 ^ 53 then return integer value
  let binary : Float := OfScientific.ofScientific n false 0
  if binary.isInf then return integer value
  let sign : Int := if value < 0 then -1 else 1
  let bits := binary.toBits.toNat
  let significand := (bits % (2 ^ 52)) + 2 ^ 52
  let exact := significand * 2 ^ (bits / (2 ^ 52) - 1075)
  let digits := (toString exact).length
  for i in [:digits] do
    let scale := digits - i - 1
    let base := 10 ^ scale
    let whole := exact / base
    let remainder := exact % base
    let rounded := whole + if 2 * remainder > base || (2 * remainder == base && whole % 2 != 0)
      then 1 else 0
    if (OfScientific.ofScientific rounded false scale : Float) == binary then
      return integer (sign * Int.ofNat (rounded * base))
  return integer (sign * Int.ofNat exact)

private def withBounds (schema : Json) (bounds : Array (String × Int)) : Json :=
  if bounds.isEmpty then schema else
    let fields := bounds.toList.map fun (key, value) => (key, schemaNumber value)
    if ["$ref", "anyOf", "oneOf", "allOf"].any (fun key => (schema.getObjVal? key).isOk) then
      obj [("allOf", .arr #[schema, obj fields])]
    else
      fields.foldl (fun s (key, value) => s.setObjVal! key value) schema

private def record (properties : Array (String × Json)) (required : Array String) : Json :=
  obj [("type", "object"), ("properties", obj properties.toList),
    ("required", toJson required), ("additionalProperties", toJson false)]

private def tagged (key : String) (schema : Json) : Json :=
  record #[(key, schema)] #[key]

private def tuple (items : Array Json) : Json :=
  obj [("type", "array"), ("prefixItems", .arr items),
    ("minItems", toJson items.size), ("maxItems", toJson items.size)]

private def array (items : Json) : Json :=
  obj [("type", "array"), ("items", items)]

private def sanitize (value : String) : String :=
  value.foldl (fun acc c => acc ++ match c with
    | '?' => "_q"
    | '!' => "_bang"
    | '\'' => "_prime"
    | c => if (c.isAlphanum && c.toNat < 128) || c == '_' then c.toString else "_") ""

private def goTypeName (mod : Name) (desc : Desc) : String :=
  let name := desc.sourceName
  let name := if mod.isPrefixOf name && mod != name then name.replacePrefix mod .anonymous else name
  let parts := name.components.map lastComponent ++ desc.params.toList
  let base := String.join <| parts.flatMap fun p =>
    ((sanitize p).splitOn "_").filterMap fun s => if s.isEmpty then none else some s.capitalize
  if base.isEmpty || base.front.isDigit then "X" ++ base
  else if base == "Handle" || base == "Value" then "Lean" ++ base
  else base

private structure SchemaContext where
  descs : Array Desc
  names : Std.HashMap String String
  refPrefix : String

private structure SchemaState where
  active : Std.HashSet String := {}
  referenced : Std.HashSet String := {}
  definitions : Std.TreeMap String Json := {}

private abbrev SchemaM := ReaderT SchemaContext (StateM SchemaState)

private def primitive (ty : CType) : Json :=
  let unsigned := fun (bits : Nat) => withBounds (jsType "integer")
    #[("minimum", 0), ("maximum", Int.ofNat (2 ^ bits - 1))]
  let signed := fun (bits : Nat) =>
    let limit := Int.ofNat (2 ^ (bits - 1))
    withBounds (jsType "integer")
      (if bits == 64 then #[("minimum", -limit), ("exclusiveMaximum", limit)]
       else #[("minimum", -limit), ("maximum", limit - 1)])
  match ty with
  | .nat => withBounds (jsType "integer") #[("minimum", 0)]
  | .int => jsType "integer"
  | .bool => jsType "boolean"
  | .string => jsType "string"
  | .char => withBounds (jsType "string") #[("minLength", 1), ("maxLength", 1)]
  | .float | .float32 => jsType "number"
  | .uint8 => unsigned 8
  | .uint16 => unsigned 16
  | .uint32 => unsigned 32
  | .uint64 | .usize => obj [("type", "string"), ("pattern", "^(0|[1-9][0-9]*)$")]
  | .int8 => signed 8
  | .int16 => signed 16
  | .int32 => signed 32
  | .int64 => signed 64
  | .bytes => array (unsigned 8)
  | .unit => obj [("type", "object"), ("additionalProperties", toJson false)]
  | .named _ => obj []

mutual

private partial def generateType (ty : CType) : SchemaM Json := do
  let .named key := ty | return primitive ty
  let ctx ← read
  let some desc := ctx.descs.find? (·.name == key) | return obj []
  if let some bound := desc.finBound then
    return withBounds (primitive .nat) #[("exclusiveMaximum", Int.ofNat bound)]
  match desc.shape with
  | .subtype =>
    let field := desc.ctors[0]!.fields[0]!
    return withBounds (← generateType field.type) field.bounds
  | .list | .array => return array (← generateType desc.item)
  | .option =>
    let item ← generateType desc.ctors[1]!.fields[0]!.type
    return obj [("anyOf", .arr #[item, jsType "null"])]
  | .pair => return tuple (← desc.ctors[0]!.fields.mapM fun f => generateType f.type)
  | _ => generateNamed desc

private partial def generateNamed (desc : Desc) : SchemaM Json := do
  let ctx ← read
  let name := ctx.names[desc.name]!
  let reference := obj [("$ref", toJson (ctx.refPrefix ++ name))]
  let st ← get
  if st.active.contains name then
    modify fun s => { s with referenced := s.referenced.insert name }
    return reference
  if st.definitions.contains name then return reference
  modify fun s => { s with active := s.active.insert name }
  let result ← match desc.shape with
    | .record =>
      let (props, keys) ← generateFields desc.ctors[0]! true
      pure (record props keys)
    | .enum =>
      if desc.ctors.size == 1 then
        pure (obj [("oneOf", .arr #[obj [("const", toJson desc.ctors[0]!.leanName)]])])
      else
        pure (obj [("type", "string"), ("enum", toJson (desc.ctors.map (·.leanName)))])
    | _ =>
      let variants ← desc.ctors.mapM fun ctor => do
        if ctor.fields.isEmpty then return obj [("const", toJson ctor.leanName)]
        let payload ← if !ctor.positional then do
            let (props, keys) ← generateFields ctor false
            pure (record props keys)
          else do
            let items ← ctor.fields.mapM fun f => return withBounds (← generateType f.type) f.bounds
            pure (if items.size == 1 then items[0]! else tuple items)
        return tagged ctor.leanName payload
      pure (obj [("oneOf", .arr variants)])
  modify fun s => { s with active := s.active.erase name }
  if (← get).referenced.contains name then
    modify fun s => { s with definitions := s.definitions.insert name result }
    return reference
  return result

private partial def generateFields (ctor : Constructor) (isRecord : Bool) :
    SchemaM (Array (String × Json) × Array String) := do
  let descs := (← read).descs
  let mut props := #[]
  let mut keys := #[]
  for field in ctor.fields do
    if field.flat then
      if let some parent := descs.find? (·.name == field.type.cName) then
        let (fields, required) ← generateFields parent.ctors[0]! true
        props := props ++ fields
        keys := keys ++ required
    else
      let key := field.jsonKey descs isRecord
      props := props.push (key, withBounds (← generateType field.type) field.bounds)
      unless field.jsonOptional descs do keys := keys.push key
  return (props, keys)

end

private def schemaDocument (ctx : SchemaContext) (ty : CType) : Json :=
  let (root, st) := ((generateType ty).run ctx).run {}
  if st.definitions.isEmpty then root
  else root.setObjVal! "$defs" (obj st.definitions.toList)

def emitSchema (mod : Name) (cPrefix : String) (descs : Array Desc) (exports : Array Export) : String := Id.run do
  let roots := apiTypes exports
  let mut names : Std.HashMap String String := {}
  let mut used : Std.HashSet String := {}
  for desc in descs do
    let base := goTypeName mod desc
    let mut name := base
    let mut index := 2
    while used.contains name do
      name := base ++ toString index
      index := index + 1
    names := names.insert desc.name name
    used := used.insert name
  let context : SchemaContext := {descs, names, refPrefix := "#/$defs/"}
  let root := if roots.size == 1 then schemaDocument context roots[0]!
    else
      let definitions := roots.toList.map fun ty =>
        let key := ty.jsonName cPrefix
        let schema := schemaDocument {context with refPrefix := s!"#/$defs/{key}/$defs/"} ty
        (key, schema)
      obj [("$defs", obj definitions)]
  return (root.setObjVal! "$schema" "https://json-schema.org/draft/2020-12/schema").compress ++ "\n"

end LeanC
