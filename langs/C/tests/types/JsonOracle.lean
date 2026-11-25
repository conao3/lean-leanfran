import Lean.Data.Json
import LeanfranC.Json
import PublicTypes

deriving instance Lean.ToJson, Lean.FromJson for Typed.Tree
deriving instance Lean.ToJson, Lean.FromJson for Schema.Record

def main : IO Unit := do
  let cases := [
    "\"\\uD83D\\uDE03\\u0000\\n\\t\\b\\r\\f\\\\\\/\"",
    "\"\\uD800x\\uDC00\\uD800\\u0021\"",
    "[1e30,-3E+7,1.00e-10,-0,12.5e2,-25e-80,1e-9999]",
    "{\"雪\":[{},null,true],\"a\":1,\"a\":2}",
    String.ofList (List.replicate 500 '[') ++ "1" ++ String.ofList (List.replicate 500 ']'),
    "01", "1.", "1e+", "--1", "[1,]", "{\"a\": 3,}", "false!", "\"\\u00GG\"", "\"\n\"", ""
  ]
  for input in cases do
    let expected := (Lean.Json.parse input).map Lean.Json.compress
    let actual := (LeanfranC.Json.parse input).map LeanfranC.Json.compress
    match expected, actual with
    | .ok want, .ok got => unless want == got do
        throw (IO.userError s!"JSON parser mismatch for {reprStr input}: {want} ≠ {got}")
    | .error _, .error _ => pure ()
    | _, _ => throw (IO.userError s!"JSON parser acceptance mismatch for {reprStr input}")
  let json := Lean.toJson Schema.sample
  let decoded : Schema.Record ← IO.ofExcept (Lean.fromJson? json)
  unless (Lean.toJson decoded).compress == json.compress do
    throw (IO.userError "Native JSON did not roundtrip")
  IO.println json.compress
