import LeanC.Export

open Lean

namespace LeanC

def CType.cName : CType → String
  | .bool => "bool"
  | .uint8 => "uint8_t"
  | .uint16 => "uint16_t"
  | .uint32 | .char => "uint32_t"
  | .uint64 => "uint64_t"
  | .int8 => "int8_t"
  | .int16 => "int16_t"
  | .int32 => "int32_t"
  | .int64 => "int64_t"
  | .usize => "size_t"
  | .float => "double"
  | .float32 => "float"
  | .string => "lf_str"
  | .unit => "void"

def CType.abiName : CType → String
  | .bool | .int8 => "uint8_t"
  | .int16 => "uint16_t"
  | .int32 => "uint32_t"
  | .int64 => "uint64_t"
  | .string | .unit => "lean_object *"
  | ty => ty.cName

def CType.isSignedInt : CType → Bool
  | .int8 | .int16 | .int32 | .int64 => true
  | _ => false

def CType.unbox (ty : CType) (value : String) : String :=
  let op := match ty with
    | .uint32 | .int32 | .char => "lean_unbox_uint32"
    | .uint64 | .int64 => "lean_unbox_uint64"
    | .usize => "lean_unbox_usize"
    | .float => "lean_unbox_float"
    | .float32 => "lean_unbox_float32"
    | _ => "lean_unbox"
  if ty == .string then value else s!"({ty.abiName}){op}({value})"

def Export.prototype (entry : Export) : String :=
  let params := entry.args.toList.zipIdx.map fun (ty, i) => s!"{ty.cName} a{i}"
  let params := if entry.result == .unit then params else params ++ [s!"{entry.result.cName} *out"]
  s!"lf_status {entry.symbol}({String.intercalate ", " (params ++ ["lf_error *err"])})"

def emitHeader (cPrefix : String) (exports : Array Export) : String :=
  let guard := s!"LEANFRAN_{cPrefix}_H"
  s!"#ifndef {guard}\n#define {guard}\n\n#include \"leanfran.h\"\n\n" ++
    "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n" ++
    s!"lf_status {cPrefix}_init(lf_error *err);\n" ++
    String.join (exports.toList.map fun entry => entry.prototype ++ ";\n") ++
    "\n#ifdef __cplusplus\n}\n#endif\n\n#endif\n"

def emitWrapper (entry : Export) : String := Id.run do
  let resultType := if entry.io then "lean_object *" else entry.result.abiName
  let params := if entry.args.isEmpty then #["uint8_t"] else entry.args.map CType.abiName
  let mut lines := #[s!"extern {resultType} lf_{entry.symbol}({String.intercalate ", " params.toList});",
    entry.prototype ++ " {",
    "    if (!atomic_load(&initialized)) {",
    "        return lf_set_error(err, LF_NOT_INITIALIZED, \"Call the module initializer first\");",
    "    }"]
  if entry.result != .unit then
    lines := lines ++ #["    if (out == NULL) {",
      "        return lf_set_error(err, LF_INVALID, \"Output pointer is null\");", "    }"]
  for i in [:entry.args.size] do
    match entry.args[i]! with
    | .string =>
      lines := lines ++ #[s!"    if (a{i}.ptr == NULL && a{i}.len != 0) \{",
        "        return lf_set_error(err, LF_INVALID, \"String buffer is null\");", "    }"]
    | .char =>
      lines := lines ++ #[s!"    if (a{i} > 0x10ffff || (a{i} >= 0xd800 && a{i} <= 0xdfff)) \{",
        "        return lf_set_error(err, LF_INVALID, \"Invalid Unicode scalar value\");", "    }"]
    | _ => pure ()
  let mut args := #[]
  for i in [:entry.args.size] do
    let ty := entry.args[i]!
    if ty == .string then
      lines := lines.push s!"    lean_object *arg{i} = lean_mk_string_from_bytes(a{i}.ptr == NULL ? \"\" : a{i}.ptr, a{i}.len);"
      args := args.push s!"arg{i}"
    else
      args := args.push s!"({ty.abiName})a{i}"
  if args.isEmpty then args := #["0"]
  lines := lines.push s!"    {resultType} result = lf_{entry.symbol}({String.intercalate ", " args.toList});"
  if entry.io then
    lines := lines ++ #["    if (lean_io_result_is_error(result)) {",
      "        lf_status status = lf_copy_io_error(result, err);",
      "        lean_dec(result);",
      "        return status;",
      "    }"]
  let value := if entry.io then entry.result.unbox "lean_io_result_get_value(result)" else "result"
  if entry.result == .string then
    lines := lines.push s!"    lf_status status = lf_copy_string({value}, out, err);"
  else if entry.result.isSignedInt then
    if entry.io then lines := lines.push s!"    {entry.result.abiName} bits = {value};"
    let bits := if entry.io then "bits" else "result"
    lines := lines.push s!"    memcpy(out, &{bits}, sizeof(*out));"
  else if entry.result != .unit then
    lines := lines.push s!"    *out = ({entry.result.cName}){value};"
  if entry.io || entry.result == .string then
    lines := lines.push "    lean_dec(result);"
  let status := if entry.result == .string then "status" else "LF_OK"
  return String.intercalate "\n" (lines.toList ++ [s!"    return {status};", "}", ""])

def emitSource (mod : Name) (cPrefix : String) (exports : Array Export) : String :=
  let init := Lean.mkModuleInitializationFunctionName (exportModule mod)
  s!"#include \"{cPrefix}.h\"\n" ++
    "#include <lean/lean.h>\n#include <pthread.h>\n#include <stdatomic.h>\n#include <string.h>\n\n" ++
    "extern lf_status lf_set_error(lf_error *, lf_status, const char *);\n" ++
    "extern lf_status lf_copy_string(b_lean_obj_arg, lf_str *, lf_error *);\n" ++
    "extern lf_status lf_copy_io_error(b_lean_obj_arg, lf_error *);\n" ++
    "extern void lf_initialize(lean_object *(*)(void), lf_error *);\n" ++
    s!"extern lean_object *{init}(uint8_t);\n\n" ++
    "static pthread_once_t once = PTHREAD_ONCE_INIT;\n" ++
    "static atomic_bool initialized;\n" ++
    "static lf_error init_error;\n\n" ++
    s!"lean_object *lf_{cPrefix}_initialize(void) \{\n    return {init}(1);\n}\n\n" ++
    "static void initialize_once(void) {\n" ++
    s!"    lf_initialize(lf_{cPrefix}_initialize, &init_error);\n" ++
    "    atomic_store(&initialized, init_error.status == LF_OK);\n}\n\n" ++
    s!"lf_status {cPrefix}_init(lf_error *err) \{\n" ++
    "    pthread_once(&once, initialize_once);\n" ++
    "    if (init_error.status != LF_OK) {\n" ++
    "        const char *message = init_error.message == NULL ? \"Lean initialization failed\" : init_error.message;\n" ++
    "        return lf_set_error(err, init_error.status, message);\n" ++
    "    }\n    return LF_OK;\n}\n\n" ++
    String.intercalate "\n" (exports.toList.map emitWrapper)

end LeanC
