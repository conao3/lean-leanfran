import LeanC.Desc

open Lean Lean.Compiler.LCNF

namespace LeanC

def CType.converter : CType → String
  | .char => "lf_char"
  | .string => "lf_str"
  | .named name => name
  | .nat => "lf_nat"
  | .int => "lf_int"
  | .bytes => "lf_byte_array"
  | .floats => "lf_float_array"
  | .unit => "lf_unit"
  | ty => s!"lf_{ty.cName}"

def CType.ownsMemory : CType → Bool
  | .string | .named _ | .nat | .int | .bytes | .floats => true
  | _ => false

def CType.box (abi : String) (expr : String) : String :=
  let fn := match abi with
    | "uint32_t" => "lean_box_uint32"
    | "uint64_t" => "lean_box_uint64"
    | "size_t" => "lean_box_usize"
    | "float" => "lean_box_float32"
    | "double" => "lean_box_float"
    | _ => "lean_box"
  s!"{fn}({expr})"

def CType.unboxAbi (abi : String) (expr : String) : String :=
  let fn := match abi with
    | "uint32_t" => "lean_unbox_uint32"
    | "uint64_t" => "lean_unbox_uint64"
    | "size_t" => "lean_unbox_usize"
    | "float" => "lean_unbox_float32"
    | "double" => "lean_unbox_float"
    | _ => "lean_unbox"
  s!"({abi}){fn}({expr})"

def CType.free (ty : CType) (ptr : String) : String :=
  if ty.ownsMemory then s!"{ty.converter}_free({ptr});\n" else ""

def Field.declaration (field : Field) : String :=
  s!"    {field.type.cName} {if field.indirect then "*" else ""}{field.name};\n"

def cStringLiteral (value : String) : String :=
  "\"" ++ String.join (value.toList.map fun c =>
    if c == '"' || c == '\\' then s!"\\{c}" else c.toString) ++ "\""

def Field.leanDeclaration (field : Field) : String :=
  s!"    {field.type.cName} {if field.indirect then "*" else ""}{field.name} LF_LEAN({cStringLiteral field.leanName});\n"

def Constructor.payload (ctor : Constructor) (desc : Desc) : String :=
  s!"{desc.name}_{ctor.name}_fields"

def Constructor.tag (ctor : Constructor) (desc : Desc) : String :=
  s!"{desc.name}_{ctor.name}"

def Desc.freePrototype (desc : Desc) : String :=
  s!"void {desc.name}_free({desc.name} *value)"

def Desc.tagType (desc : Desc) : String :=
  if desc.shape == .enum then desc.name else s!"{desc.name}_tag"

def Desc.declaration (desc : Desc) : String := Id.run do
  if let some external := desc.externalType then
    return s!"typedef {external.cType} {desc.name};\n"
  if desc.shape == .subtype then
    return s!"typedef {desc.ctors[0]!.fields[0]!.type.cName} {desc.name};\n"
  if desc.shape == .array || desc.shape == .list then
    return s!"struct {desc.name} \{\n    {desc.item.cName} *items;\n    size_t len;\n};\n"
  if desc.shape == .option then
    let field := { desc.ctors[1]!.fields[0]! with name := "value" }
    return s!"struct {desc.name} \{\n    bool has_value;\n{field.declaration}};\n"
  if desc.shape == .record then
    let fields := desc.ctors[0]!.fields
    let members := if fields.isEmpty then "    uint8_t unused;\n"
      else String.join (fields.toList.map Field.leanDeclaration)
    return s!"struct LF_LEAN({cStringLiteral desc.sourceName.toString}) {desc.name} \{\n{members}};\n"
  if desc.shape == .pair then
    let fields := desc.ctors[0]!.fields
    return s!"struct {desc.name} \{\n{String.join (fields.toList.map Field.declaration)}};\n"
  let lean := fun (name : String) => s!"LF_LEAN({cStringLiteral name})"
  let tags := desc.ctors.toList.map fun ctor =>
    let annotation := if desc.shape == .enum then s!" {lean ctor.leanName}" else ""
    s!"    {ctor.tag desc}{annotation} = {ctor.layout.ctorInfo.cidx}"
  let enumName := if desc.shape == .enum then s!"{lean desc.sourceName.toString} {desc.tagType}" else desc.tagType
  let enumDecl := s!"typedef enum {enumName} \{\n{String.intercalate ",\n" tags}\n} {desc.tagType};\n"
  if desc.shape == .enum then return enumDecl
  let payloads := desc.ctors.filter (!·.fields.isEmpty)
  let payloadField := fun (ctor : Constructor) (field : Field) =>
    let leanName := if ctor.positional then s!"#{field.index}" else field.leanName
    s!"    {field.type.cName} {if field.indirect then "*" else ""}{field.name} {lean leanName};\n"
  let structs := payloads.toList.map fun ctor =>
    s!"typedef struct {ctor.payload desc} \{\n{String.join (ctor.fields.toList.map (payloadField ctor))}} {ctor.payload desc};\n"
  let members := payloads.toList.map fun ctor => s!"        {ctor.payload desc} {ctor.name} {lean ctor.leanName};\n"
  return enumDecl ++ String.join structs ++
    s!"struct {lean desc.sourceName.toString} {desc.name} \{\n    {desc.tagType} tag;\n    union \{\n{String.join members}    } as;\n};\n"

def Desc.names (desc : Desc) : List String :=
  [desc.name, s!"{desc.name}_free", s!"{desc.name}_to_lean", s!"{desc.name}_from_lean"] ++
    (if desc.shape == .variant || desc.shape == .enum then
      desc.ctors.toList.map (·.tag desc) else []) ++
    (if desc.shape == .variant then
      desc.tagType :: (desc.ctors.filter (!·.fields.isEmpty)).toList.map (·.payload desc) else [])

def emitTypeDeclarations (descs : Array Desc) : String :=
  let forwards := descs.toList.filter (fun d => d.externalType.isNone && d.shape != .enum && d.shape != .subtype) |>.map fun desc =>
    s!"typedef struct {desc.name} {desc.name};\n"
  String.join forwards ++ "\n" ++
    String.join (descs.toList.map fun desc => desc.declaration ++ desc.freePrototype ++ ";\n\n")

def CType.toPrototype (ty : CType) : String :=
  s!"lf_status {ty.converter}_to_lean(const {ty.cName} *in, lean_object **out, lf_error *err)"

def CType.fromPrototype (ty : CType) : String :=
  s!"lf_status {ty.converter}_from_lean(b_lean_obj_arg in, {ty.cName} *out, lf_error *err)"

def invalidChar (value : String) : String :=
  s!"{value} > 0x10ffff || ({value} >= 0xd800 && {value} <= 0xdfff)"

def emitPrimitive (ty : CType) : String := Id.run do
  let mut toBody := s!"    (void)err;\n    *out = {CType.box ty.abiName s!"({ty.abiName})*in"};\n    return LF_OK;\n"
  let unboxed := CType.unboxAbi ty.abiName "in"
  let mut fromBody := if ty.isSignedInt then
      s!"    {ty.abiName} bits = {unboxed};\n    memcpy(out, &bits, sizeof(bits));\n"
    else s!"    *out = {unboxed};\n"
  fromBody := "    (void)err;\n" ++ fromBody ++ "    return LF_OK;\n"
  match ty with
  | .string =>
    toBody := "    if (in->ptr == NULL && in->len != 0) {\n" ++
      "        return lf_set_error(err, LF_INVALID, \"String buffer is null\");\n    }\n" ++
      "    *out = lean_mk_string_from_bytes(in->ptr == NULL ? \"\" : in->ptr, in->len);\n    return LF_OK;\n"
    fromBody := "    return lf_copy_string(in, out, err);\n"
  | .char =>
    toBody := s!"    if ({invalidChar "(*in)"}) \{\n" ++
      "        return lf_set_error(err, LF_INVALID, \"Invalid Unicode scalar value\");\n    }\n" ++
      "    *out = lean_box_uint32(*in);\n    return LF_OK;\n"
  | .unit =>
    toBody := "    (void)in;\n    (void)err;\n    *out = lean_box(0);\n    return LF_OK;\n"
    fromBody := "    (void)in;\n    (void)err;\n    *out = (lf_unit){0};\n    return LF_OK;\n"
  | _ => pure ()
  return s!"LF_INLINE {ty.toPrototype} \{\n{toBody}}\n\nLF_INLINE {ty.fromPrototype} \{\n{fromBody}}\n\n"

def emitMarshalSupport (cPrefix : String) : String :=
  "#if defined(__GNUC__) || defined(__clang__)\n" ++
  "#define LF_INLINE static inline __attribute__((unused))\n" ++
  "#else\n#define LF_INLINE static inline\n#endif\n\n" ++
  "LF_INLINE void lf_str_free(lf_str *value) { lf_free(value->ptr); *value = (lf_str){0}; }\n\n" ++
  s!"extern lean_object *lf_{cPrefix}_nat_decimal(lean_object *);\n" ++
  s!"extern lean_object *lf_{cPrefix}_int_decimal(lean_object *);\n" ++
  "extern bool lf_nat_from_lean_u64(b_lean_obj_arg, uint64_t *);\n" ++
  "extern bool lf_int_from_lean_i64(b_lean_obj_arg, int64_t *);\n" ++
  String.join ([CType.nat, .int].map fun ty =>
    let (width, stem) := if ty == .nat then ("u64", "nat") else ("i64", "int")
    s!"extern {ty.toPrototype};\nLF_INLINE {ty.fromPrototype} \{\n" ++
      s!"    {ty.cName} value = \{0};\n" ++
      s!"    if (!{ty.cName}_from_lean_{width}(in, &value.value)) \{\n" ++
      s!"        lean_inc(in);\n        lean_object *decimal = lf_{cPrefix}_{stem}_decimal(in);\n" ++
      "        lf_str copy;\n        lf_status status = lf_copy_string(decimal, &copy, err);\n" ++
      "        lean_dec(decimal);\n        if (status != LF_OK) return status;\n" ++
      "        value.decimal = copy.ptr;\n    }\n    *out = value;\n    return LF_OK;\n}\n\n") ++
  String.join ([CType.bytes, .floats].map fun ty =>
    s!"extern {ty.toPrototype};\nextern {ty.fromPrototype};\n") ++ "\n" ++
  String.join ([CType.bool, .uint8, .uint16, .uint32, .uint64, .int8, .int16, .int32, .int64,
    .usize, .float, .float32, .char, .string, .unit].map emitPrimitive)

def Field.path (field : Field) (desc : Desc) (ctor : Constructor) (value : String) : String :=
  if desc.shape == .subtype then s!"(*{value})"
  else if desc.shape == .option then s!"{value}->value"
  else if desc.shape == .variant then s!"{value}->as.{ctor.name}.{field.name}"
  else s!"{value}->{field.name}"

def Field.emitFree (field : Field) (path : String) : String :=
  if field.indirect then
    s!"if ({path} != NULL) \{\n{field.type.free path}lf_free({path});\n}\n"
  else field.type.free s!"&{path}"

def Desc.emitFree (desc : Desc) : String := Id.run do
  let mut body := "if (value == NULL) return;\n"
  if desc.shape == .list || desc.shape == .array then
    if desc.item.ownsMemory then
      body := body ++ s!"for (size_t i = 0; i < value->len; ++i) \{\n{desc.item.free "&value->items[i]"}}\n"
    body := body ++ "lf_free(value->items);\n"
  else if desc.shape == .option then
    body := body ++ s!"if (value->has_value) \{\n{desc.ctors[1]!.fields[0]!.emitFree "value->value"}}\n"
  else if desc.shape == .variant then
    body := body ++ "switch (value->tag) {\n"
    for ctor in desc.ctors do
      body := body ++ s!"case {ctor.tag desc}:\n"
      body := body ++ String.join (ctor.fields.toList.map fun f => f.emitFree (f.path desc ctor "value"))
      body := body ++ "break;\n"
    body := body ++ "}\n"
  else if desc.shape != .enum then
    let ctor := desc.ctors[0]!
    body := body ++ String.join (ctor.fields.toList.map fun f => f.emitFree (f.path desc ctor "value"))
  return desc.freePrototype ++ s!" \{\n{body}*value = ({desc.name})\{0};\n}\n\n"

def Field.scalarAccess (field : Field) (ctor : Constructor) : String × String × String :=
  match field.layout with
  | .usize i => ("usize", "size_t", toString i)
  | .scalar n off expr =>
    let (kind, abi) := if expr == ImpureType.float then ("float", "double")
      else if expr == ImpureType.float32 then ("float32", "float")
      else (s!"uint{n * 8}", s!"uint{n * 8}_t")
    let words := ctor.layout.ctorInfo.size + ctor.layout.ctorInfo.usize
    (kind, abi, s!"(sizeof(void *) * {words} + {off})")
  | _ => ("", "", "")

def Field.emitTo (field : Field) (path : String) (ctor : Constructor) (trivial : Bool) : String :=
  let ptr := if field.indirect then path else s!"&{path}"
  let check := if field.indirect then
      s!"if ({path} == NULL) \{ status = lf_set_error(err, LF_INVALID, \"Recursive field {field.name} is null\"); goto fail; }\n"
    else ""
  let call := s!"status = {field.type.converter}_to_lean({ptr}, &field, err);\nif (status != LF_OK) goto fail;\n"
  let set := if trivial then "value = field;\n" else match field.layout with
    | .object i _ => s!"lean_ctor_set(value, {i}, field);\n"
    | _ =>
      let (kind, abi, pos) := field.scalarAccess ctor
      s!"lean_ctor_set_{kind}(value, {pos}, {CType.unboxAbi abi "field"});\nlean_dec(field);\n"
  check ++ call ++ set

def Field.emitFrom (field : Field) (path : String) (ctor : Constructor) (trivial : Bool) : String :=
  let ptr := if field.indirect then path else s!"&{path}"
  let alloc := if field.indirect then
      s!"{path} = calloc(1, sizeof(*{path}));\n" ++
        s!"if ({path} == NULL) \{ status = lf_set_error(err, LF_IO, \"Could not allocate recursive field {field.name}\"); goto fail; }\n"
    else ""
  let (get, dec) := if trivial then ("field = in;\n", "") else match field.layout with
    | .object i _ => (s!"field = lean_ctor_get(in, {i});\n", "")
    | _ =>
      let (kind, abi, pos) := field.scalarAccess ctor
      (s!"field = {CType.box abi s!"lean_ctor_get_{kind}(in, {pos})"};\n", "lean_dec(field);\n")
  alloc ++ get ++ s!"status = {field.type.converter}_from_lean(field, {ptr}, err);\n" ++ dec ++
    "if (status != LF_OK) goto fail;\n"

def Constructor.emitTo (ctor : Constructor) (desc : Desc) : String := Id.run do
  let info := ctor.layout.ctorInfo
  let validate := fun value =>
    if desc.hasInvariants then s!"status = {desc.name}_check({value}, err);\nif (status != LF_OK) goto fail;\n"
    else ""
  if ctor.fields.isEmpty then
    let tag := s!"lean_box({info.cidx})"
    return validate tag ++ s!"*out = {tag};\nreturn LF_OK;\n"
  let mut code := ""
  if !desc.trivial then
    code := s!"value = lean_alloc_ctor({info.cidx}, {info.size}, sizeof(size_t) * {info.usize} + {info.ssize});\n"
    for i in [:info.size] do
      code := code ++ s!"lean_ctor_set(value, {i}, lean_box(0));\n"
  code := code ++ String.join (ctor.fields.toList.map fun f => f.emitTo (f.path desc ctor "in") ctor desc.trivial)
  return code ++ validate "value" ++ "*out = value;\nreturn LF_OK;\n"

def Constructor.emitFrom (ctor : Constructor) (desc : Desc) : String := Id.run do
  let tag := if desc.shape == .enum then s!"*out = {ctor.tag desc};\n"
    else if desc.shape == .variant then s!"out->tag = {ctor.tag desc};\n"
    else if desc.shape == .option && ctor.layout.ctorInfo.cidx == 1 then "out->has_value = true;\n"
    else ""
  return tag ++ String.join (ctor.fields.toList.map fun f => f.emitFrom (f.path desc ctor "out") ctor desc.trivial) ++
    "return LF_OK;\n"

def Desc.emitSequence (desc : Desc) : String := Id.run do
  let ty := CType.named desc.name
  let item := desc.item
  let array := desc.shape == .array
  let init := if array then
      "if (in->len > (SIZE_MAX - sizeof(lean_array_object)) / sizeof(lean_object *))\n" ++
      "    return lf_set_error(err, LF_INVALID, \"Array length is too large\");\n" ++
      "lean_object *value = lean_alloc_array(0, in->len);\n"
    else "lean_object *value = lean_box(0);\n"
  let loop := if array then "for (size_t i = 0; i < in->len; ++i) {\n"
    else "for (size_t i = in->len; i != 0; ) {\n--i;\n"
  let push := if array then "value = lean_array_push(value, field);\n"
    else "lean_object *cell = lean_alloc_ctor(1, 2, 0);\nlean_ctor_set(cell, 0, field);\nlean_ctor_set(cell, 1, value);\nvalue = cell;\n"
  let length := if array then "size_t len = lean_array_size(in);\n"
    else "size_t len = 0;\nfor (lean_object *cell = in; !lean_is_scalar(cell); cell = lean_ctor_get(cell, 1)) ++len;\n"
  let read := if array then "lean_array_get_core(in, out->len)" else "lean_ctor_get(in, 0)"
  let advance := if array then "" else "in = lean_ctor_get(in, 1);\n"
  return s!"LF_INLINE {ty.toPrototype} \{\n" ++
    "if (in->items == NULL && in->len != 0) return lf_set_error(err, LF_INVALID, \"Null item buffer\");\n" ++
    init ++ loop ++ "lean_object *field = lean_box(0);\n" ++
    s!"lf_status status = {item.converter}_to_lean(&in->items[i], &field, err);\n" ++
    "if (status != LF_OK) { lean_dec(value); return status; }\n" ++ push ++ "}\n*out = value;\nreturn LF_OK;\n}\n\n" ++
    s!"LF_INLINE {ty.fromPrototype} \{\n*out = ({desc.name})\{0};\n" ++
    length ++ "if (len == 0) return LF_OK;\n" ++
    "if (len > SIZE_MAX / sizeof(*out->items)) return lf_set_error(err, LF_IO, \"Output length is too large\");\n" ++
    "out->items = calloc(len, sizeof(*out->items));\n" ++
    "if (out->items == NULL) return lf_set_error(err, LF_IO, \"Could not allocate items\");\n" ++
    s!"for (; out->len < len; ++out->len) \{\nlf_status status = {item.converter}_from_lean({read}, &out->items[out->len], err);\n" ++
    s!"if (status != LF_OK) \{ {desc.name}_free(out); return status; }\n" ++ advance ++
    "}\nreturn LF_OK;\n}\n\n"

def Desc.emitCtors (desc : Desc) : String := Id.run do
  let ty := CType.named desc.name
  let hasFields := desc.ctors.any (!·.fields.isEmpty)
  let cases := desc.shape == .variant || desc.shape == .enum || desc.shape == .option
  let mut toBody := if hasFields then "lean_object *value = NULL;\nlean_object *field = lean_box(0);\nlf_status status;\n"
    else if desc.hasInvariants then "lf_status status;\n"
    else "(void)err;\n"
  let mut fromBody := if hasFields then "lean_object *field;\nlf_status status;\n" else "(void)err;\n"
  if desc.shape != .enum then fromBody := fromBody ++ s!"*out = ({desc.name})\{0};\n"
  if cases then
    let selector := if desc.shape == .enum then "*in" else if desc.shape == .option then "(int)in->has_value" else "in->tag"
    let tag := if desc.shape == .enum then "lean_unbox(in)" else "lean_obj_tag(in)"
    toBody := toBody ++ s!"switch ({selector}) \{\n"
    fromBody := fromBody ++ s!"switch ({tag}) \{\n"
    for ctor in desc.ctors do
      let idx := toString ctor.layout.ctorInfo.cidx
      let label := if desc.shape == .option then idx else ctor.tag desc
      toBody := toBody ++ s!"case {label}:\n" ++ ctor.emitTo desc
      fromBody := fromBody ++ s!"case {idx}:\n" ++ ctor.emitFrom desc
    toBody := toBody ++ s!"default: return lf_set_error(err, LF_INVALID, \"Invalid {desc.name} tag\");\n}\n"
    fromBody := fromBody ++ s!"default: return lf_set_error(err, LF_IO, \"Invalid Lean {desc.name} tag\");\n}\n"
  else
    unless hasFields do
      toBody := toBody ++ "(void)in;\n"
      fromBody := fromBody ++ "(void)in;\n"
    toBody := toBody ++ desc.ctors[0]!.emitTo desc
    fromBody := fromBody ++ desc.ctors[0]!.emitFrom desc
  if hasFields then
    toBody := toBody ++ "fail:\nif (value != NULL) lean_dec(value);\nreturn status;\n"
    fromBody := fromBody ++ s!"fail:\n{desc.name}_free(out);\nreturn status;\n"
  else if desc.hasInvariants then
    toBody := toBody ++ "fail:\nreturn status;\n"
  return s!"LF_INLINE {ty.toPrototype} \{\n{toBody}}\n\n" ++
    s!"LF_INLINE {ty.fromPrototype} \{\n{fromBody}}\n\n"

private def Desc.emitCheck (desc : Desc) : String :=
  if !desc.hasInvariants then "" else
    s!"extern lean_object *lf_{desc.name}_decide(lean_object *);\n" ++
    s!"LF_INLINE lf_status {desc.name}_check(lean_object *value, lf_error *err) \{\n" ++
    "lean_object *box = lean_alloc_ctor(0, 2, 0);\n" ++
    "lean_inc(value);\nlean_ctor_set(box, 0, value);\nlean_ctor_set(box, 1, lean_box(0));\n" ++
    s!"lean_object *message = lf_{desc.name}_decide(box);\n" ++
    "if (lean_is_scalar(message)) return LF_OK;\n" ++
    "lf_status status = lf_set_error(err, LF_INVALID, lean_string_cstr(lean_ctor_get(message, 0)));\n" ++
    "lean_dec(message);\nreturn status;\n}\n\n"

def emitMarshalling (cPrefix : String) (descs : Array Desc) : String :=
  emitMarshalSupport cPrefix ++
    String.join (descs.toList.map fun desc =>
      let ty := CType.named desc.name
      s!"LF_INLINE {ty.toPrototype};\nLF_INLINE {ty.fromPrototype};\n") ++ "\n" ++
    String.join (descs.toList.map fun desc => desc.emitCheck ++ desc.emitFree ++
      if desc.shape == .list || desc.shape == .array then desc.emitSequence else desc.emitCtors)

end LeanC
