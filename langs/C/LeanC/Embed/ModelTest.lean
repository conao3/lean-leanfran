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

private def generator (ty : CType) (pick : String) : String :=
  match ty with
  | .bool => s!"lf_model_bool(&lf_rng, {pick})"
  | .float => s!"lf_model_double(&lf_rng, {pick})"
  | ty => if ty.isSignedInt then s!"({ty.cName})lf_model_signed(&lf_rng, {width ty}, {pick})"
    else s!"({ty.cName})lf_model_unsigned(&lf_rng, {width ty}, {pick})"

private def caseCount (ty : CType) : String :=
  match ty with
  | .bool => "LF_MODEL_BOOL_CASES"
  | .float => "LF_MODEL_DOUBLE_CASES"
  | ty => if ty.isSignedInt then "LF_MODEL_SIGNED_CASES" else "LF_MODEL_UNSIGNED_CASES"

private def cString (text : String) : String :=
  "\"" ++ ((text.replace "\\" "\\\\").replace "\"" "\\\"") ++ "\""

private def printValue (ty : CType) (value : String) : String :=
  match ty with
  | .bool => s!"fprintf(stderr, \"%s\", {value} ? \"true\" : \"false\");"
  | .float => s!"fprintf(stderr, \"%.17g\", {value});"
  | ty => if ty.isSignedInt then s!"fprintf(stderr, \"%\" PRId64, (int64_t){value});"
    else s!"fprintf(stderr, \"%\" PRIu64, (uint64_t){value});"

private def same (ty : CType) (a b : String) : String :=
  if ty == .float then s!"lf_model_same_double({a}, {b})" else s!"{a} == {b}"

private structure Input where
  param : Param
  ty : CType
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
  inputs.map fun input => if input.array then arrayType cPrefix input.ty else input.ty

private def testFunction (m : ModelFunction) (fn : Verify.Function) (blocks : Array String)
    (exports : Std.HashMap String (Array Export)) : Except String (String × String × Array String) := do
  if m.isStatic then throw "static functions are not visible to the model test"
  let .value _ resultBoundary := fn.result | throw "lf_status results are not generated"
  let some result := boundaryType resultBoundary | throw s!"unsupported result type {resultBoundary}"
  let mut inputs : Array Input := #[]
  for p in fn.params do
    match p.kind with
    | .value =>
      let some ty := boundaryType p.boundary | throw s!"unsupported parameter type {p.boundary} of '{p.name}'"
      inputs := inputs.push {param := p, ty, array := false}
    | .array _ boundary _ =>
      let some ty := boundaryType boundary | throw s!"unsupported element type {boundary} of '{p.name}'"
      inputs := inputs.push {param := p, ty, array := true}
    | .length _ => pure ()
    | .out => throw "out parameters are not generated"
  let mut headers := #[]
  let display := s!"{m.block}.{m.name}"
  let argName := fun (p : Param) => s!"lf_arg_{p.name}"
  let call := fun (block symbol : String) (extra : Array String) (out : String) =>
    let args := inputs.map fun i =>
      if i.array then
        let name := argName i.param
        s!"&({(arrayType block i.ty).cName})\{{name}, {name}_len}"
      else argName i.param
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
      s!"                {printValue i.ty s!"{name}[lf_i]"}\n            }\n" ++
      "            fprintf(stderr, \"]\");\n"
    else s!"            {sep}fprintf(stderr, \"{i.param.name}=\"); {printValue i.ty name}\n")
  let failure := fun (label message : String) (extra : String) =>
    s!"            fprintf(stderr, \"%s [%s]: {message} (seed %\" PRIu64 \", run %\" PRIu64 \")\\n  input: \", {cString display}, {cString label}, lf_seed, lf_run);\n" ++
    printInput ++ "            fprintf(stderr, \"\\n\");\n" ++ extra ++ "            return 1;\n"
  for check in m.checks do
    if check.label == "refines" then
      let (block, entry) ← checkExport blocks exports check.predicate (leanArgs inputs) result
      headers := headers.push block
      body := body ++ s!"        {result.cName} lf_expected;\n" ++
        s!"        if ({call block entry.symbol #[] "&lf_expected"} != LF_OK)\n" ++
        s!"            return lf_model_lean_error({cString display}, {cString check.predicate}, &lf_err);\n" ++
        s!"        if (!({same result "lf_expected" "lf_actual"})) \{\n" ++
        failure "refines" "mismatch"
          (s!"            fprintf(stderr, \"  expected: \"); {printValue result "lf_expected"}\n" ++
           s!"            fprintf(stderr, \", got: \"); {printValue result "lf_actual"}\n" ++
           "            fprintf(stderr, \"\\n\");\n") ++ "        }\n"
    else
      let (block, entry) ← checkExport blocks exports check.predicate
        (fun b => leanArgs inputs b |>.push result) .bool
      headers := headers.push block
      body := body ++ "        {\n            bool lf_holds = false;\n" ++
        s!"            if ({call block entry.symbol #["lf_actual"] "&lf_holds"} != LF_OK)\n" ++
        s!"                return lf_model_lean_error({cString display}, {cString check.predicate}, &lf_err);\n" ++
        "            if (!lf_holds) {\n" ++
        failure check.label s!"{check.predicate} does not hold"
          (s!"            fprintf(stderr, \"  result: \"); {printValue result "lf_actual"}\n" ++
           "            fprintf(stderr, \"\\n\");\n") ++ "            }\n        }\n"
  let cParams := fn.params.map fun p =>
    match p.kind with
    | .array .. => s!"const {(boundaryType p.boundary).get!.cName} *"
    | _ => ((boundaryType p.boundary).map (·.cName)).getD "size_t"
  let prototype := s!"{result.cName} {m.name}({if cParams.isEmpty then "void" else ", ".intercalate cParams.toList});\n"
  let cArgs := fn.params.map fun p =>
    match p.kind with
    | .length array =>
      let owner := (fn.params.find? (·.lean == array)).get!
      s!"({((boundaryType p.boundary).map (·.cName)).getD "size_t"}){argName owner}_len"
    | _ => argName p
  let cases := inputs.filter (!·.array) |>.foldl (init := "1") fun acc i => s!"lf_model_cases({acc}, {caseCount i.ty})"
  let generate := String.join (inputs.toList.map fun i =>
    let name := argName i.param
    if i.array then
      s!"        {i.ty.cName} {name}[LF_MODEL_MAX_LENGTH];\n" ++
      s!"        size_t {name}_len = lf_model_length(&lf_rng);\n" ++
      s!"        for (size_t lf_i = 0; lf_i < {name}_len; lf_i++)\n" ++
      s!"            {name}[lf_i] = {generator i.ty "NULL"};\n"
    else s!"        {i.ty.cName} {name} = {generator i.ty "lf_pick"};\n")
  let fnName := s!"lf_model_test_{m.block}_{m.name}"
  let source :=
    s!"static int {fnName}(uint64_t lf_runs, uint64_t lf_seed) \{\n" ++
    s!"    lf_model_rng lf_rng = lf_model_rng_new(lf_seed, {cString display});\n" ++
    s!"    uint64_t lf_cases = {cases};\n    uint64_t lf_accepted = 0;\n" ++
    "    for (uint64_t lf_run = 0; lf_run < lf_runs; lf_run++) {\n" ++
    "        uint64_t lf_index = lf_run;\n" ++
    "        uint64_t *lf_pick = lf_run < lf_cases && lf_run < lf_runs / 2 ? &lf_index : NULL;\n" ++
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
  return (prototype, source, headers)

def modelTest (models : Array ModelFunction) (allBlocks : Array Block)
    (exports : Std.HashMap String (Array Export)) : String × Array FilePath := Id.run do
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
      if let some error := m.error then throw error
      let some fn := m.closure.find? (·.name == m.name) | throw "not translated"
      testFunction m fn blocks exports
    match result with
    | .ok (prototype, source, used) =>
      prototypes := prototypes ++ prototype
      functions := functions ++ "\n" ++ source
      calls := calls ++ s!"    lf_failed |= lf_model_test_{m.block}_{m.name}(lf_runs, lf_seed);\n"
      for h in used do unless headers.contains h do headers := headers.push h
      unless sources.contains m.file do sources := sources.push m.file
    | .error reason =>
      calls := calls ++ s!"    printf(\"%s: skipped: %s\\n\", {cString display}, {cString reason});\n"
  let includes := String.join ((headers.qsort (· < ·)).toList.map (s!"#include \"{·}.h\"\n"))
  return (·, sources) <| "#include \"leanfran.h\"\n#include \"leanfran_model_test.h\"\n" ++ includes ++ "\n" ++
    prototypes ++ functions ++
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
