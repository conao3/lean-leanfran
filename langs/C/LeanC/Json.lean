import LeanC.Marshal

namespace LeanC

private def CType.primitiveLeanType (ty : CType) : String :=
  match ty with
  | .uint8 => "UInt8"
  | .uint16 => "UInt16"
  | .uint32 => "UInt32"
  | .uint64 => "UInt64"
  | .usize => "USize"
  | .int8 => "Int8"
  | .int16 => "Int16"
  | .int32 => "Int32"
  | .int64 => "Int64"
  | .bool => "Bool"
  | .string => "String"
  | .nat => "Nat"
  | .int => "Int"
  | .char => "Char"
  | .bytes => "ByteArray"
  | .floats => "FloatArray"
  | .float => "Float"
  | .float32 => "Float32"
  | .unit => "Unit"
  | .named _ => ""

def CType.jsonName (ty : CType) (cPrefix : String) : String :=
  if let .named name := ty then name else s!"{cPrefix}_{ty.typeStem cPrefix}"

structure JsonApi where
  name : String
  type : CType
  leanType : String

def jsonApis (cPrefix : String) (descs : Array Desc) (primitives : Array CType) : Array JsonApi :=
  descs.map (fun d => ⟨d.name, .named d.name, d.typeSource⟩) ++
    primitives.map (fun ty => ⟨ty.jsonName cPrefix, ty, ty.primitiveLeanType⟩)

private def CType.encodeJson (ty : CType) (value : String) : String :=
  match ty with
  | .named name => s!"encode_{name} {value}"
  | .bool => s!"Json.bool {value}"
  | .string => s!"Json.str {value}"
  | .nat => s!"Json.nat {value}"
  | .int => s!"Json.int {value}"
  | .char => s!"Json.char {value}"
  | .bytes => s!"Json.bytes {value}"
  | .floats => s!"Json.floats {value}"
  | .float => s!"Json.float {value}"
  | .float32 => s!"Json.float (Float32.toFloat {value})"
  | .unit => "Json.obj []"
  | .uint64 | .usize => s!"Json.str (toString ({ty.primitiveLeanType}.toNat {value}))"
  | .uint8 | .uint16 | .uint32 => s!"Json.nat ({ty.primitiveLeanType}.toNat {value})"
  | .int8 | .int16 | .int32 | .int64 => s!"Json.int ({ty.primitiveLeanType}.toInt {value})"

private def CType.decodeJson (ty : CType) (value : String) : String :=
  match ty with
  | .named name => s!"decode_{name} {value}"
  | .bool => s!"Json.getBool {value}"
  | .string => s!"Json.getString {value}"
  | .nat => s!"Json.getNat {value}"
  | .int => s!"Json.getInt {value}"
  | .char => s!"Json.getChar {value}"
  | .bytes => s!"Json.getBytes {value}"
  | .floats => s!"Json.getFloats {value}"
  | .float => s!"Json.getFloat {value}"
  | .float32 => s!"Float.toFloat32 <$> Json.getFloat {value}"
  | .unit => s!"(fun _ : Unit => ⟨⟩) <$> Json.getUnit {value}"
  | .uint64 | .usize | .uint8 | .uint16 | .uint32 =>
    let quoted := ty == .uint64 || ty == .usize
    let type := ty.primitiveLeanType
    s!"{type}.ofNat <$> Json.boundedNat {value} {type}.size {quoted}"
  | .int8 | .int16 | .int32 | .int64 =>
    let type := ty.primitiveLeanType
    s!"{type}.ofInt <$> Json.boundedInt {value} ({type}.maxValue.toInt + 1)"

def Field.jsonOptional (field : Field) (descs : Array Desc) : Bool :=
  descs.any (fun d => d.name == field.type.cName && d.shape == .option)

def Field.jsonKey (field : Field) (descs : Array Desc) (record : Bool) : String :=
  if record && field.jsonOptional descs && field.leanName.endsWith "?" then
    (field.leanName.dropEndWhile (· == '?')).toString
  else field.leanName

private def Constructor.application (ctor : Constructor) (desc : Desc) (keepProofs : Bool := false) : String :=
  let fields := ctor.fields.map fun f => (f.index, s!"lfv{f.index}")
  let proofs := ctor.invariants.map fun h => (h.index, if keepProofs then s!"lfh{h.index}" else "_")
  let args := (fields ++ proofs).qsort (fun a b => a.1 < b.1)
  let params := String.join (List.replicate desc.type.getAppNumArgs " _")
  s!"@_root_.{ctor.leanCtor}{params}{String.join (args.toList.map (fun (_, term) => " " ++ term))}"

private def Desc.emitEncoder (desc : Desc) (descs : Array Desc) : String := Id.run do
  let encode := fun (f : Field) => f.type.encodeJson s!"lfv{f.index}"
  let encodeRecord := fun (ctor : Constructor) =>
    let fragments := ctor.fields.toList.map fun f =>
      let value := encode f
      let key := f.jsonKey descs (desc.shape == .record)
      if f.flat then s!"(Json.getFields ({value})).toOption.getD []"
      else if key != f.leanName then s!"Json.omitNull {reprStr key} ({value})"
      else s!"[({reprStr key}, {value})]"
    if fragments.isEmpty then "Json.obj []"
    else "Json.obj (" ++ String.intercalate " ++ " (fragments.map ("(" ++ · ++ ")")) ++ ")"
  let body : String := match desc.shape with
    | .array => s!"  Json.arr (value.map (fun x => {desc.item.encodeJson "x"}))\n"
    | .list => s!"  Json.arr (value.toArray.map (fun x => {desc.item.encodeJson "x"}))\n"
    | _ => "  match value with\n" ++ String.join (desc.ctors.toList.map fun (ctor : Constructor) =>
      let fields := ctor.fields
      let tuple := s!"Json.arr #[{String.intercalate ", " (fields.toList.map encode)}]"
      let result := match desc.shape with
        | .enum => s!"Json.str {reprStr ctor.leanName}"
        | .record => encodeRecord ctor
        | .subtype => encode fields[0]!
        | .pair => tuple
        | .option => if fields.isEmpty then "Json.null" else encode fields[0]!
        | _ =>
          if fields.isEmpty then s!"Json.str {reprStr ctor.leanName}"
          else
            let payload := if !ctor.positional then encodeRecord ctor
              else if fields.size == 1 then encode fields[0]! else tuple
            s!"Json.obj [({reprStr ctor.leanName}, {payload})]"
      s!"  | {ctor.application desc} => {result}\n")
  return s!"private partial def encode_{desc.name} (value : {desc.typeSource}) : Json :=\n{body}\n"

private def Constructor.decodeFields (ctor : Constructor) (desc : Desc) (descs : Array Desc)
    (indent : String) (json : String) : String := Id.run do
  let fields := ctor.fields
  let tuple := desc.shape == .pair || (desc.shape == .variant && ctor.positional && fields.size > 1)
  let record := desc.shape == .record || (desc.shape == .variant && !ctor.positional && !fields.isEmpty)
  let mut code := ""
  if tuple then
    code := s!"{indent}let items ← Json.getTuple {json} {fields.size}\n"
  else if record && (fields.isEmpty || fields.all (·.flat)) then
    code := s!"{indent}discard (Json.getFields {json})\n"
  for i in [:fields.size] do
    let field := fields[i]!
    let arg := if tuple then s!"items[{i}]!" else
      if record && !field.flat then
        s!"(← Json.getField {json} {reprStr (field.jsonKey descs (desc.shape == .record))} {field.jsonOptional descs})"
      else json
    code := code ++ s!"{indent}let lfv{field.index} ← {field.type.decodeJson arg}\n"
  let mut padding := indent
  for inv in ctor.invariants do
    code := code ++ s!"{padding}let _ : Decidable ({inv.proposition}) := {inv.instanceTerm}\n" ++
      s!"{padding}if lfh{inv.index} : ({inv.proposition}) then\n"
    padding := padding ++ "  "
  code := code ++ s!"{padding}return {ctor.application desc true}\n"
  for (inv, i) in ctor.invariants.toList.zipIdx.reverse do
    let pad := indent ++ String.ofList (List.replicate (i * 2) ' ')
    code := code ++ s!"{pad}else throw {reprStr (desc.invariantMessage inv)}\n"
  return code

private def Desc.emitDecoder (desc : Desc) (descs : Array Desc) : String := Id.run do
  let body : String := match desc.shape with
    | .array | .list =>
      let seq := s!"(← Json.getArray json).mapM (fun x => {desc.item.decodeJson "x"})"
      if desc.shape == .array then s!"  {seq}\n" else s!"  Array.toList <$> ({seq})\n"
    | .option =>
      s!"  match json with\n  | .null => pure none\n  | _ => some <$> ({desc.ctors[1]!.fields[0]!.type.decodeJson "json"})\n"
    | .variant | .enum =>
      s!"  let (tag, {if desc.shape == .enum then "_" else "payload"}) ← Json.getTag json\n  match tag with\n" ++
      String.join (desc.ctors.toList.map fun (ctor : Constructor) =>
        let branch := if ctor.fields.isEmpty then
            s!"    discard (Json.getString json)\n" ++
              ctor.decodeFields desc descs "    " "json"
          else
            "    discard (Json.getFields json)\n" ++
              ctor.decodeFields desc descs "    " "payload"
        s!"  | {reprStr ctor.leanName} => do\n{branch}") ++
      s!"  | _ => throw ({reprStr (s!"Unknown {desc.typeSource} constructor: ")} ++ tag)\n"
    | _ => desc.ctors[0]!.decodeFields desc descs "  " "json"
  return s!"private partial def decode_{desc.name} (json : Json) : Except String ({desc.typeSource}) := do\n{body}\n"

private def Desc.emitDecider (desc : Desc) : String :=
  if !desc.hasInvariants then "" else
    "set_option linter.unusedVariables false in\n" ++
    s!"@[export lf_{desc.name}_decide]\ndef check_{desc.name} (value : Prod ({desc.typeSource}) Bool) : Option String :=\n" ++
    "  match value.1 with\n" ++
    String.join (desc.ctors.toList.map fun (ctor : Constructor) =>
      s!"  | {ctor.application desc} =>\n" ++
        String.join (ctor.invariants.toList.map fun inv =>
          s!"    if @decide ({inv.proposition}) ({inv.instanceTerm}) == false then some {reprStr (desc.invariantMessage inv)} else\n") ++
        "    none\n") ++ "\n"

def emitJsonExports (descs : Array Desc) (apis : Array JsonApi) : String :=
  let codecs := if descs.isEmpty then "" else
    "mutual\n" ++ String.join (descs.toList.map (·.emitEncoder descs)) ++ "end\n\n" ++
    "mutual\n" ++ String.join (descs.toList.map (·.emitDecoder descs)) ++ "end\n\n"
  "namespace LeanfranC\n\n" ++ codecs ++ String.join (descs.toList.map Desc.emitDecider) ++
    String.join (apis.toList.map fun api =>
      s!"@[export lf_{api.name}_encode_json]\ndef toJson_{api.name} (value : Prod ({api.leanType}) Bool) : String :=\n" ++
      s!"  ({api.type.encodeJson "value.1"}).compress\n\n" ++
      s!"@[export lf_{api.name}_decode_json]\ndef fromJson_{api.name} (bytes : ByteArray) : Except String (Prod ({api.leanType}) Bool) := do\n" ++
      s!"  let json ← Json.parseBytes bytes\n  return (← {api.type.decodeJson "json"}, false)\n\n") ++
    "end LeanfranC\n"

def JsonApi.validPrototype (api : JsonApi) : String :=
  s!"bool {api.name}_valid(const {api.type.cName} *in, lf_error *err)"

def JsonApi.toJsonPrototype (api : JsonApi) : String :=
  s!"lf_status {api.name}_to_json(const {api.type.cName} *in, lf_str *out, lf_error *err)"

def JsonApi.fromJsonPrototype (api : JsonApi) : String :=
  s!"lf_status {api.name}_from_json(const char *data, size_t len, {api.type.cName} *out, lf_error *err)"

def JsonApi.names (api : JsonApi) : List String :=
  [s!"{api.name}_valid", s!"{api.name}_to_json", s!"{api.name}_from_json",
    s!"lf_{api.name}_encode_json", s!"lf_{api.name}_decode_json"]

def Desc.deciderNames (desc : Desc) : List String :=
  if desc.hasInvariants then [s!"lf_{desc.name}_decide", s!"{desc.name}_check"] else []

private def requireInitialized : String :=
  "if (!atomic_load(&initialized)) return lf_set_error(err, LF_NOT_INITIALIZED, \"Call the module initializer first\");\n"

def emitJsonWrappers (apis : Array JsonApi) : String :=
  String.join (apis.toList.map fun api =>
    s!"extern lean_object *lf_{api.name}_encode_json(lean_object *);\n" ++
    s!"extern lean_object *lf_{api.name}_decode_json(lean_object *);\n" ++
    s!"{api.validPrototype} \{\n" ++
    "if (!atomic_load(&initialized)) { lf_set_error(err, LF_NOT_INITIALIZED, \"Call the module initializer first\"); return false; }\n" ++
    "if (in == NULL) { lf_set_error(err, LF_INVALID, \"Input pointer is null\"); return false; }\n" ++
    "lean_object *value = NULL;\n" ++
    s!"if ({api.type.converter}_to_lean(in, &value, err) != LF_OK) return false;\n" ++
    "lean_dec(value);\nreturn true;\n}\n\n" ++
    s!"{api.toJsonPrototype} \{\n" ++ requireInitialized ++
    "if (in == NULL || out == NULL) return lf_set_error(err, LF_INVALID, \"Input or output pointer is null\");\n" ++
    "lean_object *value = NULL;\n" ++
    s!"lf_status status = {api.type.converter}_to_lean(in, &value, err);\nif (status != LF_OK) return status;\n" ++
    "lean_object *boxed = lean_alloc_ctor(0, 2, 0);\nlean_ctor_set(boxed, 0, value);\nlean_ctor_set(boxed, 1, lean_box(0));\n" ++
    s!"lean_object *json = lf_{api.name}_encode_json(boxed);\n" ++
    "status = lf_copy_string(json, out, err);\nlean_dec(json);\nreturn status;\n}\n\n" ++
    s!"{api.fromJsonPrototype} \{\n" ++ requireInitialized ++
    "if (out == NULL || (data == NULL && len != 0)) return lf_set_error(err, LF_INVALID, \"Input or output pointer is null\");\n" ++
    "if (lean_alloc_sarray_would_overflow(1, len)) return lf_set_error(err, LF_INVALID, \"JSON buffer is too large\");\n" ++
    "lean_object *bytes = lean_alloc_sarray(1, len, len);\nif (len != 0) memcpy(lean_sarray_cptr(bytes), data, len);\n" ++
    s!"lean_object *result = lf_{api.name}_decode_json(bytes);\n" ++
    "lean_object *value = lean_ctor_get(result, 0);\n" ++
    "lf_status status;\nif (lean_obj_tag(result) == 0) status = lf_set_error(err, LF_INVALID, lean_string_cstr(value));\n" ++
    s!"else status = {api.type.converter}_from_lean(lean_ctor_get(value, 0), out, err);\n" ++
    "lean_dec(result);\nreturn status;\n}\n\n")

def emitExcept (name value : String) : String :=
  "if (err == NULL) { status = LF_EXCEPT; goto done; }\n" ++
  s!"lean_object *payload = lean_ctor_get({value}, 0);\n" ++
  "lean_inc(payload);\nlean_object *boxed = lean_alloc_ctor(0, 2, 0);\n" ++
  "lean_ctor_set(boxed, 0, payload);\nlean_ctor_set(boxed, 1, lean_box(0));\n" ++
  s!"lean_object *json = lf_{name}_encode_json(boxed);\n" ++
  "lf_str message;\nstatus = lf_copy_string(json, &message, err);\nlean_dec(json);\n" ++
  "if (status == LF_OK) { lf_error_clear(err); *err = (lf_error){LF_EXCEPT, message.ptr}; status = LF_EXCEPT; }\n" ++
  "goto done;\n"

end LeanC
