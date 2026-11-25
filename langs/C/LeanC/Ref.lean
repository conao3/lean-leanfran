import LeanC.Export

namespace LeanC

def refTypes (exports : Array Export) (descs : Array Desc) : List CType :=
  let direct := exports.toList.flatMap fun entry =>
    entry.args.toList ++ (if entry.result == .unit then [] else [entry.result]) ++ entry.exception.toList
  let nested := descs.toList.flatMap fun desc =>
    let items := if desc.shape == .array || desc.shape == .list then [desc.item] else []
    .named desc.name :: items ++ desc.ctors.toList.flatMap fun ctor =>
      ctor.fields.toList.map (·.type)
  (direct ++ nested).foldl (fun types ty => if types.contains ty then types else ty :: types) [] |>.reverse

def CType.refName (ty : CType) (cPrefix : String) : String :=
  match ty with
  | .named name => s!"{name}_ref"
  | _ => s!"{cPrefix}_type_{ty.typeStem cPrefix}_ref"

def refNames (cPrefix : String) (ty : CType) : List String :=
  let name := ty.refName cPrefix
  name :: (["from", "get", "retain", "release", "share"].map fun suffix => s!"{name}_{suffix}")

private def refPrototypes (cPrefix : String) (ty : CType) : List String :=
  let name := ty.refName cPrefix
  [s!"lf_status {name}_from(const {ty.cName} *value, {name} *out, lf_error *err)",
    s!"lf_status {name}_get({name} value, {ty.cName} *out, lf_error *err)",
    s!"{name} {name}_retain({name} value)",
    s!"void {name}_release({name} value)",
    s!"void {name}_share({name} value)"]

def emitRefDeclaration (cPrefix : String) (ty : CType) : String :=
  "typedef struct { void *obj; } " ++ s!"{ty.refName cPrefix};\n" ++
    String.join ((refPrototypes cPrefix ty).map (· ++ ";\n")) ++ "\n"

private def checkInitialized : String :=
  "if (!atomic_load(&initialized)) return lf_set_error(err, LF_NOT_INITIALIZED, \"Call the module initializer first\");\n"

def emitRefType (cPrefix : String) (ty : CType) : String :=
  let bodies := [
    checkInitialized ++
      "if (value == NULL || out == NULL) return lf_set_error(err, LF_INVALID, \"Value or output pointer is null\");\n" ++
      s!"lean_object *obj = NULL;\nlf_status status = {ty.converter}_to_lean(value, &obj, err);\n" ++
      "if (status == LF_OK) out->obj = obj;\nreturn status;\n",
    checkInitialized ++
      "if (value.obj == NULL || out == NULL) return lf_set_error(err, LF_INVALID, \"Handle or output pointer is null\");\n" ++
      s!"return {ty.converter}_from_lean(value.obj, out, err);\n",
    "if (value.obj != NULL) lean_inc(value.obj);\nreturn value;\n",
    "if (value.obj != NULL) lean_dec(value.obj);\n",
    "if (value.obj != NULL) lean_mark_mt(value.obj);\n"]
  String.join ((refPrototypes cPrefix ty).zipWith
    (fun prototype body => prototype ++ " {\n" ++ body ++ "}\n\n") bodies)

def Export.refSymbol (entry : Export) (take : Bool) : String :=
  entry.symbol ++ (if take then "_ref_take" else "_ref")

def Export.refPrototype (entry : Export) (cPrefix : String) (take : Bool) : String :=
  let params := entry.args.toList.zipIdx.map fun (ty, i) => s!"{ty.refName cPrefix} a{i}"
  let params := if entry.result == .unit then params else params ++ [s!"{entry.result.refName cPrefix} *out"]
  s!"lf_status {entry.refSymbol take}({String.intercalate ", " (params ++ ["lf_error *err"])})"

def emitRefWrapper (cPrefix : String) (entry : Export) (take : Bool) : String := Id.run do
  let mut code := entry.refPrototype cPrefix take ++ " {\n" ++ checkInitialized
  if entry.result != .unit then
    code := code ++ "if (out == NULL) return lf_set_error(err, LF_INVALID, \"Output pointer is null\");\n"
  for i in [:entry.args.size] do
    code := code ++ s!"if (a{i}.obj == NULL) return lf_set_error(err, LF_INVALID, \"Handle argument {i} is null\");\n"
  let mut args := #[]
  for (ty, i) in entry.args.toList.zipIdx do
    let obj := s!"a{i}.obj"
    if ty.byPointer then
      unless take do code := code ++ s!"lean_inc({obj});\n"
      code := code ++ s!"lean_object *arg{i} = lean_alloc_ctor(0, 2, 0);\n" ++
        s!"lean_ctor_set(arg{i}, 0, {obj});\nlean_ctor_set(arg{i}, 1, lean_box(0));\n"
      args := args.push s!"arg{i}"
    else if ty == .string then
      unless take do code := code ++ s!"lean_inc({obj});\n"
      args := args.push obj
    else
      code := code ++ s!"{ty.abiName} arg{i} = {CType.unboxAbi ty.abiName obj};\n"
      if take then code := code ++ s!"lean_dec({obj});\n"
      args := args.push s!"arg{i}"
  if args.isEmpty then args := #["0"]
  let hasError := entry.io || entry.exception.isSome
  let resultAbi := if hasError then "lean_object *" else entry.result.abiName
  code := code ++ s!"{resultAbi} result = lf_{entry.symbol}({String.intercalate ", " args.toList});\n"
  if hasError then code := code ++ "lf_status status = LF_OK;\n"
  if entry.io then
    code := code ++ "if (lean_io_result_is_error(result)) { status = lf_copy_io_error(result, err); goto done; }\n"
  let value := if entry.io then "lean_io_result_get_value(result)"
    else if entry.boxResult then "lean_ctor_get(result, 0)" else "result"
  if let some ty := entry.exception then
    code := code ++ s!"if (lean_obj_tag({value}) == 0) \{\n{emitExcept (ty.jsonName cPrefix) value}}\n"
  let value := if entry.exception.isSome then s!"lean_ctor_get({value}, 0)" else value
  let container := hasError || entry.boxResult
  if entry.result != .unit then
    if container then
      code := code ++ s!"lean_object *value = {value};\nlean_inc(value);\nout->obj = value;\n"
    else
      let obj := if entry.result == .string then value else CType.box entry.result.abiName value
      code := code ++ s!"out->obj = {obj};\n"
  if hasError then code := code ++ "done:\n"
  if container then code := code ++ "lean_dec(result);\n"
  return code ++ (if hasError then "return status;\n}\n\n" else "return LF_OK;\n}\n\n")

end LeanC
