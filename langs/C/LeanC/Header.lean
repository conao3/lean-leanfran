import LeanC.Export
import LeanC.Ref

open Lean

namespace LeanC

def CType.unbox (ty : CType) (value : String) : String :=
  if ty == .string then value else CType.unboxAbi ty.abiName value

def Export.prototype (entry : Export) : String :=
  let params := entry.args.toList.zipIdx.map fun (ty, i) =>
    if ty.byPointer then s!"const {ty.cName} *a{i}" else s!"{ty.cName} a{i}"
  let params := if entry.result == .unit then params else params ++ [s!"{entry.result.cName} *out"]
  s!"lf_status {entry.symbol}({String.intercalate ", " (params ++ ["lf_error *err"])})"

def emitHeader (cPrefix : String) (exports : Array Export) (descs : Array Desc) (apis : Array JsonApi) : String :=
  let guard := s!"LEANFRAN_{cPrefix}_H"
  let headers := ((descs.filterMap (·.externalType.map (·.header))).toList.eraseDups).mergeSort
  s!"#ifndef {guard}\n#define {guard}\n\n#include \"leanfran.h\"\n\n" ++
    String.join (headers.map (fun header => s!"#include \"{header}\"\n")) ++
    (if headers.isEmpty then "" else "\n") ++
    "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n" ++
    emitTypeDeclarations descs ++
    String.join (apis.toList.map fun api => api.validPrototype ++ ";\n" ++
      api.toJsonPrototype ++ ";\n" ++ api.fromJsonPrototype ++ ";\n") ++
    String.join ((refTypes exports descs).map (emitRefDeclaration cPrefix)) ++
    s!"lf_status {cPrefix}_init(lf_error *err);\n" ++
    String.join (exports.toList.map fun entry => entry.prototype ++ ";\n" ++
      entry.refPrototype cPrefix false ++ ";\n" ++ entry.refPrototype cPrefix true ++ ";\n") ++
    "\n#ifdef __cplusplus\n}\n#endif\n\n#endif\n"

def emitScalarWrapper (entry : Export) : String := Id.run do
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

def Export.usesMarshalling (entry : Export) : Bool :=
  entry.args.any CType.byPointer || entry.result.byPointer || entry.exception.isSome

def emitWrapper (cPrefix : String) (entry : Export) : String := Id.run do
  unless entry.usesMarshalling do return emitScalarWrapper entry
  let resultAbi := if entry.io || entry.exception.isSome then "lean_object *" else entry.result.abiName
  let abi := if entry.args.isEmpty then #["uint8_t"] else entry.args.map CType.abiName
  let mut code := s!"extern {resultAbi} lf_{entry.symbol}({String.intercalate ", " abi.toList});\n" ++
    entry.prototype ++ " {\n" ++
    "if (!atomic_load(&initialized)) return lf_set_error(err, LF_NOT_INITIALIZED, \"Call the module initializer first\");\n"
  if entry.result != .unit then
    code := code ++ "if (out == NULL) return lf_set_error(err, LF_INVALID, \"Output pointer is null\");\n"
  let mut owned := #[]
  let mut args := #[]
  for (ty, i) in entry.args.toList.zipIdx do
    if ty.byPointer then
      code := code ++ s!"if (a{i} == NULL) return lf_set_error(err, LF_INVALID, \"Argument {i} is null\");\n"
    else if ty == .char then
      code := code ++ s!"if ({invalidChar s!"a{i}"}) return lf_set_error(err, LF_INVALID, \"Invalid Unicode scalar value\");\n"
    if ty.byPointer || ty == .string then
      code := code ++ s!"lean_object *arg{i} = NULL;\n"
      owned := owned.push (ty, i)
      args := args.push s!"arg{i}"
    else
      args := args.push s!"({ty.abiName})a{i}"
  code := code ++ "lf_status status = LF_OK;\n"
  for (ty, i) in owned do
    let arg := if ty.byPointer then s!"a{i}" else s!"&a{i}"
    code := code ++ s!"status = {ty.converter}_to_lean({arg}, &arg{i}, err);\nif (status != LF_OK) goto bad_arg;\n"
    if ty.byPointer then
      code := code ++ s!"lean_object *box{i} = lean_alloc_ctor(0, 2, 0);\n" ++
        s!"lean_ctor_set(box{i}, 0, arg{i});\nlean_ctor_set(box{i}, 1, lean_box(0));\narg{i} = box{i};\n"
  if args.isEmpty then args := #["0"]
  code := code ++ s!"{resultAbi} result = lf_{entry.symbol}({String.intercalate ", " args.toList});\n"
  if entry.io then
    code := code ++ "if (lean_io_result_is_error(result)) { status = lf_copy_io_error(result, err); goto done; }\n"
  let value := if entry.io then "lean_io_result_get_value(result)"
    else if entry.boxResult then "lean_ctor_get(result, 0)" else "result"
  if let some error := entry.exception then
    code := code ++ s!"if (lean_obj_tag({value}) == 0) \{\n{emitExcept (error.jsonName cPrefix) value}}\n"
  let value := if entry.exception.isSome then s!"lean_ctor_get({value}, 0)" else value
  if entry.result != .unit then
    if resultAbi == "lean_object *" then
      code := code ++ s!"status = {entry.result.converter}_from_lean({value}, out, err);\n"
    else if entry.result.isSignedInt then
      code := code ++ "memcpy(out, &result, sizeof(*out));\n"
    else
      code := code ++ s!"*out = ({entry.result.cName})result;\n"
  if resultAbi == "lean_object *" then
    if entry.io || entry.exception.isSome then code := code ++ "done:\n"
    code := code ++ "lean_dec(result);\n"
  code := code ++ "return status;\n"
  unless owned.isEmpty do
    code := code ++ "bad_arg:\n" ++
      String.join (owned.toList.map fun (_, i) => s!"if (arg{i} != NULL) lean_dec(arg{i});\n") ++ "return status;\n"
  return code ++ "}\n"

private def emitInitializer (cPrefix init : String) : String :=
  "extern void lf_initialize(lean_object *(*)(void), lf_error *);\n" ++
    s!"extern lean_object *{init}(uint8_t);\n\n" ++
    "static pthread_once_t once = PTHREAD_ONCE_INIT;\n" ++
    (if cPrefix == "leanfran" then "atomic_bool lf_project_initialized;\n"
      else "static atomic_bool initialized;\n") ++
    "static lf_error init_error;\n\n" ++
    s!"lean_object *lf_{cPrefix}_initialize(void) \{\n    return {init}(1);\n}\n\n" ++
    "static void initialize_once(void) {\n" ++
    s!"    lf_initialize(lf_{cPrefix}_initialize, &init_error);\n" ++
    s!"    atomic_store(&{if cPrefix == "leanfran" then "lf_project_initialized" else "initialized"}, init_error.status == LF_OK);\n}\n\n" ++
    s!"lf_status {cPrefix}_init(lf_error *err) \{\n" ++
    "    lf_thread_attach();\n" ++
    "    pthread_once(&once, initialize_once);\n" ++
    "    if (init_error.status != LF_OK) {\n" ++
    "        const char *message = init_error.message == NULL ? \"Lean initialization failed\" : init_error.message;\n" ++
    "        return lf_set_error(err, init_error.status, message);\n" ++
    "    }\n    return LF_OK;\n}\n\n"

def emitProjectInitializer (init : String) : String :=
  "#include \"leanfran.h\"\n#include <lean/lean.h>\n#include <pthread.h>\n#include <stdatomic.h>\n\n" ++
    "extern lf_status lf_set_error(lf_error *, lf_status, const char *);\n" ++
    emitInitializer "leanfran" init

def emitSource (mod : Name) (cPrefix : String) (exports : Array Export) (descs : Array Desc)
    (apis : Array JsonApi) (projectInit : Bool := false) : String :=
  s!"#include \"{cPrefix}.h\"\n" ++
    "#include <lean/lean.h>\n#include <pthread.h>\n#include <stdatomic.h>\n#include <stdlib.h>\n#include <string.h>\n\n" ++
    "extern lf_status lf_set_error(lf_error *, lf_status, const char *);\n" ++
    "extern lf_status lf_copy_string(b_lean_obj_arg, lf_str *, lf_error *);\n" ++
    "extern lf_status lf_copy_io_error(b_lean_obj_arg, lf_error *);\n" ++
    (if projectInit then
      "extern atomic_bool lf_project_initialized;\n" ++
        "#define initialized lf_project_initialized\n\n" ++
        s!"lf_status {cPrefix}_init(lf_error *err) \{\n    return leanfran_init(err);\n}\n\n"
    else emitInitializer cPrefix (Lean.mkModuleInitializationFunctionName (exportModule mod))) ++
    (if exports.isEmpty then "" else emitMarshalling cPrefix descs) ++
    emitJsonWrappers apis ++
    String.join ((refTypes exports descs).map (emitRefType cPrefix)) ++
    String.intercalate "\n" (exports.toList.map fun entry =>
      emitWrapper cPrefix entry ++ emitRefWrapper cPrefix entry false ++ emitRefWrapper cPrefix entry true)

end LeanC
