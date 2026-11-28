import LeanC.Export
import LeanC.Link
import LeanC.Embed.Verify

open Lean System
open LeanC.Verify (Param ParamKind Ty)

namespace LeanC.Embed

def modelTestSupport : String := include_str "../../support/leanfran_model_test.h"
def modelTestSource := "leanfran_model_test.c"
def modelTestBinary := "leanfran_model_test"

private def boundaryType (boundary : String) : Option CType :=
  match CType.ofName boundary.toName with
  | some .char | some .float32 | some .string | some .unit | some .nat | some .int | some .bytes | some .floats => none
  | ty => ty

private def arrayType (cPrefix : String) (elem : CType) : CType :=
  .named (escapeIdentifier s!"{cPrefix}_array_{elem.typeStem cPrefix}")

private def width : CType → Nat
  | .int8 | .uint8 => 8
  | .int16 | .uint16 => 16
  | .int32 | .uint32 => 32
  | _ => 64

private def cString (text : String) : String :=
  "\"" ++ ((text.replace "\\" "\\\\").replace "\"" "\\\"") ++ "\""

private inductive VTy where
  | scalar (ty : CType)
  | enum (desc : Desc)
  | variant (desc : Desc)
  deriving Inhabited

private def VTy.cName : VTy → String
  | .scalar ty => ty.cName
  | .enum desc | .variant desc => desc.name

private def VTy.cType : VTy → CType
  | .scalar ty => ty
  | .enum desc | .variant desc => .named desc.name

private def VTy.byPointer (ty : VTy) : Bool := ty.cType.byPointer

private def VTy.generator (ty : VTy) (rng pick : String) : String :=
  match ty with
  | .scalar .bool => s!"lf_model_bool({rng}, {pick})"
  | .scalar .float => s!"lf_model_double({rng}, {pick})"
  | .scalar ty => if ty.isSignedInt then s!"({ty.cName})lf_model_signed({rng}, {width ty}, {pick})"
    else s!"({ty.cName})lf_model_unsigned({rng}, {width ty}, {pick})"
  | .enum desc | .variant desc => s!"lf_model_gen_{desc.name}({rng}, {pick})"

private def VTy.caseCount : VTy → String
  | .scalar .bool => "LF_MODEL_BOOL_CASES"
  | .scalar .float => "LF_MODEL_DOUBLE_CASES"
  | .scalar ty => if ty.isSignedInt then "LF_MODEL_SIGNED_CASES" else "LF_MODEL_UNSIGNED_CASES"
  | .enum desc | .variant desc => s!"LF_MODEL_CASES_{desc.name}"

private def VTy.print (ty : VTy) (value : String) : String :=
  match ty with
  | .scalar .bool => s!"fprintf(stderr, \"%s\", {value} ? \"true\" : \"false\");"
  | .scalar .float => s!"fprintf(stderr, \"%.17g\", {value});"
  | .scalar ty => if ty.isSignedInt then s!"fprintf(stderr, \"%\" PRId64, (int64_t){value});"
    else s!"fprintf(stderr, \"%\" PRIu64, (uint64_t){value});"
  | .enum desc | .variant desc => s!"lf_model_print_{desc.name}({value});"

private def VTy.same (ty : VTy) (a b : String) : String :=
  match ty with
  | .scalar .float => s!"lf_model_same_double({a}, {b})"
  | .variant desc => s!"lf_model_same_{desc.name}({a}, {b})"
  | _ => s!"{a} == {b}"

private def VTy.ref (ty : VTy) (value : String) : String :=
  if ty.byPointer then s!"&{value}" else value

private abbrev Types := Std.HashMap String Desc

private def stripTag (name : String) : String :=
  if name.startsWith "struct " then (name.drop 7).toString
  else if name.startsWith "enum " then (name.drop 5).toString
  else name

private def fieldType (types : Types) (field : Field) : Option VTy :=
  if field.indirect then none else
  match field.type with
  | .named name => types[name]?.bind fun desc => if desc.shape == .enum then some (.enum desc) else none
  | .char | .float32 | .string | .unit | .nat | .int | .bytes => none
  | ty => some (.scalar ty)

private def resolve (types : Types) (cName boundary : String) : Option VTy :=
  match boundaryType boundary with
  | some ty => some (.scalar ty)
  | none => types[stripTag cName]?.bind fun desc =>
    if desc.externalType.isSome then none
    else if desc.shape == .enum then some (.enum desc)
    else if desc.shape == .variant &&
        desc.ctors.all fun c => c.fields.all fun f => (fieldType types f).isSome then some (.variant desc)
    else none

private def generated (desc : Desc) : Array Constructor :=
  desc.ctors.filter (·.invariants.isEmpty)

private def ctorCases (types : Types) (ctor : Constructor) : String :=
  ctor.fields.foldl (init := "UINT64_C(1)") fun acc f =>
    s!"{acc} * {((fieldType types f).get!).caseCount}"

private def typeSupport (types : Types) (ty : VTy) : String :=
  match ty with
  | .scalar _ => ""
  | .enum desc =>
    let n := desc.ctors.size
    let tags := ", ".intercalate (desc.ctors.toList.map (·.tag desc))
    s!"#define LF_MODEL_CASES_{desc.name} {n}\n\n" ++
    s!"static inline {desc.name} lf_model_gen_{desc.name}(lf_model_rng *lf_rng, uint64_t *lf_pick) \{\n" ++
    s!"    static const {desc.name} lf_values[{n}] = \{{tags}};\n" ++
    "    uint64_t lf_index;\n" ++
    s!"    if (!lf_model_pick(lf_pick, {n}, &lf_index))\n" ++
    s!"        lf_index = lf_model_next(lf_rng) % {n};\n" ++
    "    return lf_values[lf_index];\n}\n\n" ++
    s!"static inline void lf_model_print_{desc.name}({desc.name} lf_value) \{\n" ++
    "    switch (lf_value) {\n" ++
    String.join (desc.ctors.toList.map fun c =>
      s!"    case {c.tag desc}:\n        fprintf(stderr, \"{c.tag desc}\");\n        return;\n") ++
    "    }\n    fprintf(stderr, \"%d\", (int)lf_value);\n}\n\n"
  | .variant desc =>
    let ctors := generated desc
    let field := fun (c : Constructor) (f : Field) => s!"lf_value.as.{c.name}.{f.name}"
    let total := if ctors.isEmpty then "UINT64_C(1)"
      else " + ".intercalate (ctors.toList.map fun c => s!"({ctorCases types c})")
    let gen := if ctors.isEmpty then "" else
      s!"static inline {desc.name} lf_model_gen_{desc.name}(lf_model_rng *lf_rng, uint64_t *lf_pick) \{\n" ++
      s!"    static const uint64_t lf_counts[{ctors.size}] = \{{", ".intercalate (ctors.toList.map (ctorCases types))}};\n" ++
      s!"    {desc.name} lf_value;\n" ++
      "    memset(&lf_value, 0, sizeof lf_value);\n" ++
      "    uint64_t lf_index;\n    uint64_t *lf_sub = NULL;\n    size_t lf_ctor = 0;\n" ++
      s!"    if (lf_model_pick(lf_pick, LF_MODEL_CASES_{desc.name}, &lf_index)) \{\n" ++
      "        while (lf_index >= lf_counts[lf_ctor])\n            lf_index -= lf_counts[lf_ctor++];\n" ++
      "        lf_sub = &lf_index;\n" ++
      s!"    } else \{\n        lf_ctor = (size_t)(lf_model_next(lf_rng) % {ctors.size});\n    }\n" ++
      "    switch (lf_ctor) {\n" ++
      String.join (ctors.toList.zipIdx.map fun (c, i) =>
        s!"    case {i}:\n        lf_value.tag = {c.tag desc};\n" ++
        String.join (c.fields.toList.map fun f =>
          s!"        {field c f} = {((fieldType types f).get!).generator "lf_rng" "lf_sub"};\n") ++
        "        break;\n") ++
      "    }\n    (void)lf_sub;\n    return lf_value;\n}\n\n"
    s!"#define LF_MODEL_CASES_{desc.name} ({total})\n\n" ++ gen ++
    s!"static inline void lf_model_print_{desc.name}({desc.name} lf_value) \{\n" ++
    "    switch (lf_value.tag) {\n" ++
    String.join (desc.ctors.toList.map fun c =>
      s!"    case {c.tag desc}:\n        fprintf(stderr, \"{c.tag desc}\");\n" ++
      (if c.fields.isEmpty then "" else
        "        fprintf(stderr, \"{\");\n" ++
        String.join (c.fields.toList.zipIdx.map fun (f, i) =>
          s!"        fprintf(stderr, \"{if i == 0 then "" else ", "}{f.name}=\");\n" ++
          s!"        {((fieldType types f).get!).print (field c f)}\n") ++
        "        fprintf(stderr, \"}\");\n") ++
      "        return;\n") ++
    "    }\n    fprintf(stderr, \"tag=%d\", (int)lf_value.tag);\n}\n\n" ++
    s!"static inline bool lf_model_same_{desc.name}({desc.name} lf_a, {desc.name} lf_b) \{\n" ++
    "    if (lf_a.tag != lf_b.tag)\n        return false;\n" ++
    "    switch (lf_a.tag) {\n" ++
    String.join (desc.ctors.toList.map fun c =>
      let checks := c.fields.toList.map fun f =>
        let ty := (fieldType types f).get!
        ty.same s!"lf_a.as.{c.name}.{f.name}" s!"lf_b.as.{c.name}.{f.name}"
      s!"    case {c.tag desc}:\n        return {if checks.isEmpty then "true" else " && ".intercalate (checks.map (s!"({·})"))};\n") ++
    "    }\n    return true;\n}\n\n"

private def dependencies (types : Types) : VTy → Array VTy
  | .variant desc => (desc.ctors.flatMap fun c => c.fields.filterMap (fieldType types)) |>.push (.variant desc)
  | ty => #[ty]

private structure Input where
  param : Param
  ty : VTy
  array : Bool

private def findExport (exports : Std.HashMap String (Array Export)) (blocks : Array String)
    (name : String) : Option (String × Export) :=
  blocks.findSome? fun block =>
    ((exports[block]?.getD #[]).find? (·.name.toString (escape := false) == name)).map (block, ·)

private def checkExport (blocks : Array String) (exports : Std.HashMap String (Array Export))
    (name : String) (args : String → Array CType) (result : CType) : Except String (String × Export) := do
  let some (block, entry) := findExport exports blocks name
    | throw s!"'{name}' is not a public function of the Lean blocks"
  if entry.io || entry.exception.isSome || entry.args != args block || entry.result != result then
    throw s!"the C signature of '{name}' does not match the C function"
  return (block, entry)

private def leanArgs (inputs : Array Input) (cPrefix : String) : Array CType :=
  inputs.map fun input => if input.array then arrayType cPrefix input.ty.cType else input.ty.cType

private def testFunction (m : ModelFunction) (fn : Verify.Function) (blocks : Array String)
    (exports : Std.HashMap String (Array Export)) (types : Types) :
    Except String (String × String × Array String × Array VTy) := do
  if m.isStatic then throw "static functions are not visible to the model test"
  let .value _ resultBoundary := fn.result | throw "lf_status results are not generated"
  let some result := resolve types fn.resultType resultBoundary | throw s!"unsupported result type {resultBoundary}"
  let mut inputs : Array Input := #[]
  for p in fn.params do
    match p.kind with
    | .value =>
      let some ty := resolve types p.cType p.boundary | throw s!"unsupported parameter type {p.boundary} of '{p.name}'"
      if let .variant desc := ty then
        if (generated desc).isEmpty then
          throw s!"every constructor of {p.boundary} of '{p.name}' has proof fields"
      inputs := inputs.push {param := p, ty, array := false}
    | .array _ boundary _ =>
      let some ty := boundaryType boundary | throw s!"unsupported element type {boundary} of '{p.name}'"
      inputs := inputs.push {param := p, ty := .scalar ty, array := true}
    | .length _ => pure ()
    | .out => throw "out parameters are not generated"
  let mut headers := #[]
  let display := s!"{m.block}.{m.name}"
  let argName := fun (p : Param) => s!"lf_arg_{p.name}"
  let call := fun (block symbol : String) (extra : Array String) (out : String) =>
    let args := inputs.map fun i =>
      if i.array then
        let name := argName i.param
        s!"&({(arrayType block i.ty.cType).cName})\{{name}, {name}_len}"
      else i.ty.ref (argName i.param)
    s!"{symbol}({", ".intercalate (args ++ extra ++ #[out, "&lf_err"]).toList})"
  let mut body := ""
  let mut requiresCode := ""
  if let some name := m.requires then
    let (block, entry) ← checkExport blocks exports name (leanArgs inputs) .bool
    headers := headers.push block
    requiresCode := s!"        bool lf_allowed = false;\n" ++
      s!"        if ({call block entry.symbol #[] "&lf_allowed"} != LF_OK)\n" ++
      s!"            return lf_model_lean_error({cString display}, {cString name}, &lf_err);\n" ++
      "        if (!lf_allowed)\n            continue;\n"
  let printInput := String.join (inputs.toList.zipIdx.map fun (i, n) =>
    let sep := if n == 0 then "" else "fprintf(stderr, \", \"); "
    let name := argName i.param
    if i.array then
      s!"            {sep}fprintf(stderr, \"{i.param.name}=[\");\n" ++
      s!"            for (size_t lf_i = 0; lf_i < {name}_len; lf_i++) \{\n" ++
      s!"                if (lf_i) fprintf(stderr, \", \");\n" ++
      s!"                {i.ty.print s!"{name}[lf_i]"}\n            }\n" ++
      "            fprintf(stderr, \"]\");\n"
    else s!"            {sep}fprintf(stderr, \"{i.param.name}=\"); {i.ty.print name}\n")
  let failure := fun (label message : String) (extra : String) =>
    s!"            fprintf(stderr, \"%s [%s]: {message} (seed %\" PRIu64 \", run %\" PRIu64 \")\\n  input: \", {cString display}, {cString label}, lf_seed, lf_run);\n" ++
    printInput ++ "            fprintf(stderr, \"\\n\");\n" ++ extra ++ "            return 1;\n"
  for check in m.checks do
    if check.label == "refines" then
      let (block, entry) ← checkExport blocks exports check.predicate (leanArgs inputs) result.cType
      headers := headers.push block
      body := body ++ s!"        {result.cName} lf_expected;\n" ++
        s!"        if ({call block entry.symbol #[] "&lf_expected"} != LF_OK)\n" ++
        s!"            return lf_model_lean_error({cString display}, {cString check.predicate}, &lf_err);\n" ++
        s!"        if (!({result.same "lf_expected" "lf_actual"})) \{\n" ++
        failure "refines" "mismatch"
          (s!"            fprintf(stderr, \"  expected: \"); {result.print "lf_expected"}\n" ++
           s!"            fprintf(stderr, \", got: \"); {result.print "lf_actual"}\n" ++
           "            fprintf(stderr, \"\\n\");\n") ++ "        }\n"
    else
      let (block, entry) ← checkExport blocks exports check.predicate
        (fun b => leanArgs inputs b |>.push result.cType) .bool
      headers := headers.push block
      body := body ++ "        {\n            bool lf_holds = false;\n" ++
        s!"            if ({call block entry.symbol #[result.ref "lf_actual"] "&lf_holds"} != LF_OK)\n" ++
        s!"                return lf_model_lean_error({cString display}, {cString check.predicate}, &lf_err);\n" ++
        "            if (!lf_holds) {\n" ++
        failure check.label s!"{check.predicate} does not hold"
          (s!"            fprintf(stderr, \"  result: \"); {result.print "lf_actual"}\n" ++
           "            fprintf(stderr, \"\\n\");\n") ++ "            }\n        }\n"
  let inputType := fun (p : Param) => (inputs.find? (·.param.name == p.name)).map (·.ty.cName)
  let cParams := fn.params.map fun p =>
    match p.kind with
    | .array .. => s!"const {(inputType p).get!} *"
    | _ => (inputType p).getD (((boundaryType p.boundary).map (·.cName)).getD "size_t")
  let prototype := s!"{result.cName} {m.name}({if cParams.isEmpty then "void" else ", ".intercalate cParams.toList});\n"
  let cArgs := fn.params.map fun p =>
    match p.kind with
    | .length array =>
      let owner := (fn.params.find? (·.lean == array)).get!
      s!"({((boundaryType p.boundary).map (·.cName)).getD "size_t"}){argName owner}_len"
    | _ => argName p
  let cases := inputs.filter (!·.array) |>.foldl (init := "1") fun acc i => s!"lf_model_cases({acc}, {i.ty.caseCount})"
  let generate := String.join (inputs.toList.map fun i =>
    let name := argName i.param
    if i.array then
      s!"        {i.ty.cName} {name}[LF_MODEL_MAX_LENGTH];\n" ++
      s!"        size_t {name}_len = lf_model_length(&lf_rng);\n" ++
      s!"        for (size_t lf_i = 0; lf_i < {name}_len; lf_i++)\n" ++
      s!"            {name}[lf_i] = {i.ty.generator "&lf_rng" "NULL"};\n"
    else s!"        {i.ty.cName} {name} = {i.ty.generator "&lf_rng" "lf_pick"};\n")
  let fnName := s!"lf_model_test_{m.block}_{m.name}"
  let source :=
    s!"static int {fnName}(uint64_t lf_runs, uint64_t lf_seed) \{\n" ++
    s!"    lf_model_rng lf_rng = lf_model_rng_new(lf_seed, {cString display});\n" ++
    s!"    uint64_t lf_cases = {cases};\n    uint64_t lf_accepted = 0;\n" ++
    "    for (uint64_t lf_run = 0; lf_run < lf_runs; lf_run++) {\n" ++
    "        uint64_t lf_index = lf_run;\n" ++
    "        uint64_t *lf_pick = lf_run < lf_cases && lf_run < lf_runs / 2 ? &lf_index : NULL;\n" ++
    "        (void)lf_pick;\n" ++
    "        lf_error lf_err = {0};\n" ++
    generate ++ requiresCode ++
    "        lf_accepted++;\n" ++
    s!"        {result.cName} lf_actual = {m.name}({", ".intercalate cArgs.toList});\n" ++
    body ++ "    }\n" ++
    "    if (lf_accepted == 0) {\n" ++
    s!"        fprintf(stderr, \"%s: no input satisfied requires\\n\", {cString display});\n" ++
    "        return 1;\n    }\n" ++
    s!"    printf(\"%s: %\" PRIu64 \" inputs passed (seed %\" PRIu64 \")\\n\", {cString display}, lf_accepted, lf_seed);\n" ++
    "    return 0;\n}\n"
  let used := (inputs.filter (!·.array) |>.map (·.ty)).push result
  return (prototype, source, headers, used.flatMap (dependencies types))

def modelTest (models : Array ModelFunction) (allBlocks : Array Block)
    (exports : Std.HashMap String (Array Export)) (descs : Array Desc) : String × Array FilePath := Id.run do
  let types : Types := descs.foldl (init := {}) fun acc d => acc.insert d.name d
  let mut support := ""
  let mut supported : Std.HashSet String := {}
  let mut sources : Array FilePath := #[]
  let mut prototypes := ""
  let mut functions := ""
  let mut calls := ""
  let mut headers : Array String := #[]
  for m in models do
    let display := if m.block.isEmpty then m.name else s!"{m.block}.{m.name}"
    let blocks := if m.block.isEmpty then #[] else
      (m.block :: (allBlocks.filter (·.name != m.block) |>.toList.map (·.name))).toArray
    let result : Except String _ := do
      if let some error := m.error then throw (error.report m.name)
      let some fn := m.closure.find? (·.name == m.name) | throw "not translated"
      testFunction m fn blocks exports types
    match result with
    | .ok (prototype, source, used, tys) =>
      for ty in tys do
        unless supported.contains ty.cName do
          supported := supported.insert ty.cName
          support := support ++ typeSupport types ty
      prototypes := prototypes ++ prototype
      functions := functions ++ "\n" ++ source
      calls := calls ++ s!"    lf_failed |= lf_model_test_{m.block}_{m.name}(lf_runs, lf_seed);\n"
      for h in used do unless headers.contains h do headers := headers.push h
      unless sources.contains m.file do sources := sources.push m.file
    | .error reason =>
      calls := calls ++ s!"    printf(\"%s: skipped: %s\\n\", {cString display}, {cString reason});\n"
  let includes := String.join ((headers.qsort (· < ·)).toList.map (s!"#include \"{·}.h\"\n"))
  return (·, sources) <| "#include \"leanfran.h\"\n#include \"leanfran_model_test.h\"\n" ++ includes ++ "\n" ++
    prototypes ++ (if support.isEmpty then "" else "\n" ++ (support.dropEnd 1).toString) ++ functions ++
    "\nint main(void) {\n" ++
    "    uint64_t lf_runs = lf_model_env(\"LEANFRAN_RUNS\", 200);\n" ++
    "    uint64_t lf_seed = lf_model_env(\"LEANFRAN_SEED\", 1);\n" ++
    "    lf_error lf_err = {0};\n" ++
    "    if (leanfran_init(&lf_err) != LF_OK)\n" ++
    "        return lf_model_lean_error(\"leanfran_model_test\", \"leanfran_init\", &lf_err);\n" ++
    "    int lf_failed = 0;\n" ++ calls ++ "    return lf_failed;\n}\n"

def modelTestMake (out : FilePath) (config : Config) (sources : Array FilePath) : String :=
  let quote := fun (args : Array String) => (shellFlags args).replace "$" "$$" |>.replace "#" "\\#"
  let source := quote #[(out / modelTestSource).toString]
  let binary := quote #[(out / modelTestBinary).toString]
  "\nLEANFRAN_MODEL_SOURCES := " ++ quote (sources.map (·.toString)) ++ "\n" ++
  "LEANFRAN_MODEL_CFLAGS := " ++ quote config.cflags ++ "\n" ++
  "leanfran_default_goal := $(.DEFAULT_GOAL)\n" ++
  ".PHONY: leanfran-model-test\n" ++
  "leanfran-model-test:\n" ++
  "\t$(CC) -std=c11 -g -fno-wrapv -fsanitize=undefined,float-cast-overflow -fno-sanitize-recover=all " ++
  s!"$(CFLAGS) $(LEANFRAN_MODEL_CFLAGS) $(LEANFRAN_CFLAGS) {source} $(LEANFRAN_MODEL_SOURCES) " ++
  s!"$(LEANFRAN_LDLIBS) -o {binary}\n" ++
  s!"\t{binary}\n" ++
  ".DEFAULT_GOAL := $(leanfran_default_goal)\n"

end LeanC.Embed
