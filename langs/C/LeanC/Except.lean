import LeanC.Marshal

namespace LeanC

private def jsonLiteral (value : String) : String :=
  s!"lf_json_literal(out, {reprStr value})"

private def jsonKey (value : String) : String :=
  s!"lf_json_string(out, {reprStr value}, {value.utf8ByteSize})"

private def jsonCheck (expr : String) : String :=
  s!"if (!({expr})) return false;\n"

private def CType.emitJson (ty : CType) (ptr : String) (buffer := "out") : String :=
  let value := s!"(*({ptr}))"
  match ty with
  | .bool => s!"lf_json_literal({buffer}, {value} ? \"true\" : \"false\")"
  | .float => s!"lf_json_float({buffer}, {value}, 17)"
  | .float32 => s!"lf_json_float({buffer}, {value}, 9)"
  | .uint64 | .usize => s!"lf_json_unsigned({buffer}, {value}, true)"
  | .uint8 | .uint16 | .uint32 => s!"lf_json_unsigned({buffer}, {value}, false)"
  | .int8 | .int16 | .int32 | .int64 => s!"lf_json_signed({buffer}, {value})"
  | .nat =>
    s!"({value}.decimal == NULL ? lf_json_unsigned({buffer}, {value}.value, false) : lf_json_literal({buffer}, {value}.decimal))"
  | .int =>
    s!"({value}.decimal == NULL ? lf_json_signed({buffer}, {value}.value) : lf_json_literal({buffer}, {value}.decimal))"
  | .char => s!"lf_json_char({buffer}, {value})"
  | .string => s!"lf_json_string({buffer}, {value}.ptr, {value}.len)"
  | .unit => s!"lf_json_literal({buffer}, \"\{}\")"
  | .bytes => s!"lf_json_bytes({ptr}, {buffer})"
  | .named name => s!"lf_json_{name}({ptr}, {buffer})"

private def Field.emitJson (field : Field) (path : String) : String :=
  field.type.emitJson (if field.indirect then path else s!"&{path}")

private def Constructor.emitJson (ctor : Constructor) (desc : Desc) (descs : Array Desc) : String := Id.run do
  let fields := ctor.fields
  let variant := desc.shape == .variant
  if fields.isEmpty && variant then return s!"return {jsonKey ctor.leanName};\n"
  let mut code := ""
  if variant then
    code := jsonCheck (jsonLiteral "{") ++ jsonCheck (jsonKey ctor.leanName) ++ jsonCheck (jsonLiteral ":")
  if desc.shape == .pair || (variant && ctor.positional) then
    let array := fields.size != 1
    if array then code := code ++ jsonCheck (jsonLiteral "[")
    for i in [:fields.size] do
      if i != 0 then code := code ++ jsonCheck (jsonLiteral ",")
      let field := fields[i]!
      code := code ++ jsonCheck (field.emitJson (field.path desc ctor "in"))
    if array then code := code ++ jsonCheck (jsonLiteral "]")
  else
    code := code ++ jsonCheck (jsonLiteral "{")
    if !fields.isEmpty then code := code ++ "bool first = true;\n"
    for field in fields.qsort (fun a b => a.leanName < b.leanName) do
      let path := field.path desc ctor "in"
      let optional := desc.shape == .record && field.leanName.endsWith "?" &&
        descs.any (fun d => d.name == field.type.cName && d.shape == .option)
      let key := if optional then (field.leanName.dropEnd 1).toString else field.leanName
      if optional then
        let access := if field.indirect then s!"{path}->has_value" else s!"{path}.has_value"
        code := code ++ s!"if ({access}) \{\n"
      code := code ++ "if (!first && !lf_json_literal(out, \",\")) return false;\nfirst = false;\n" ++
        jsonCheck (jsonKey key) ++ jsonCheck (jsonLiteral ":") ++ jsonCheck (field.emitJson path)
      if optional then code := code ++ "}\n"
    code := code ++ jsonCheck (jsonLiteral "}")
  if variant then code := code ++ jsonCheck (jsonLiteral "}")
  return code ++ "return true;\n"

private def Desc.jsonPrototype (desc : Desc) : String :=
  s!"LF_INLINE bool lf_json_{desc.name}(const {desc.name} *in, lf_json_buffer *out)"

private def Desc.emitJson (desc : Desc) (descs : Array Desc) : String := Id.run do
  let mut code := ""
  if desc.shape == .array || desc.shape == .list then
    code := jsonCheck (jsonLiteral "[") ++
      "for (size_t i = 0; i < in->len; ++i) {\n" ++
      "if (i != 0 && !lf_json_literal(out, \",\")) return false;\n" ++
      jsonCheck (desc.item.emitJson "&in->items[i]") ++ "}\n" ++ s!"return {jsonLiteral "]"};\n"
  else if desc.shape == .option then
    let field := desc.ctors[1]!.fields[0]!
    code := s!"return in->has_value ? {field.emitJson "in->value"} : {jsonLiteral "null"};\n"
  else if desc.shape == .variant || desc.shape == .enum then
    let value := if desc.shape == .variant then "in->tag" else "*in"
    code := s!"switch ({value}) \{\n"
    for ctor in desc.ctors do
      let body := if desc.shape == .enum then s!"return {jsonKey ctor.leanName};\n" else ctor.emitJson desc descs
      code := code ++ s!"case {ctor.tag desc}: \{\n{body}}\n"
    code := code ++ "default: return false;\n}\n"
  else
    let ctor := desc.ctors[0]!
    let unused := if ctor.fields.isEmpty then "(void)in;\n" else ""
    code := unused ++ ctor.emitJson desc descs
  return s!"{desc.jsonPrototype} \{\n{code}}\n\n"

def emitExceptSupport (descs : Array Desc) : String :=
  (include_str "../support/except.inc") ++ "\n" ++
  ("LF_INLINE bool lf_json_bytes(const lf_byte_array *in, lf_json_buffer *out) {\n" ++
    jsonCheck (jsonLiteral "[") ++ "for (size_t i = 0; i < in->len; ++i) {\n" ++
    "if (i != 0 && !lf_json_literal(out, \",\")) return false;\n" ++
    jsonCheck (CType.uint8.emitJson "&in->items[i]") ++ "}\n" ++ s!"return {jsonLiteral "]"};\n}\n\n") ++
  String.join (descs.toList.map (·.jsonPrototype ++ ";\n")) ++ "\n" ++
  String.join (descs.toList.map (·.emitJson descs))

def emitExcept (ty : CType) (value : String) : String :=
  "if (err == NULL) { status = LF_EXCEPT; goto done; }\n" ++
  s!"{ty.cName} payload;\nstatus = {ty.converter}_from_lean(lean_ctor_get({value}, 0), &payload, err);\n" ++
  "if (status != LF_OK) goto done;\n" ++
  "lf_json_buffer json = {0};\n" ++
  s!"bool encoded = {ty.emitJson "&payload" "&json"};\n" ++
  ty.free "&payload" ++
  "if (!encoded) {\nlf_free(json.ptr);\nstatus = lf_set_error(err, LF_IO, \"Could not encode Except payload\");\n" ++
  "} else {\nlf_error_clear(err);\n*err = (lf_error){LF_EXCEPT, json.ptr};\nstatus = LF_EXCEPT;\n}\ngoto done;\n"

end LeanC
