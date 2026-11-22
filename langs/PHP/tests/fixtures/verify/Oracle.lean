import LeanPhpModel.App
import LeanPhpModel.App.Calc
import LeanPhpModel.App.Ops

open LeanPhpModel.App (increment)
open LeanPhpModel.App.Ops
open LeanPhpModel.App.Calc (clamp add)

def exc : Php.Exc → String
  | .overflow => "overflow"
  | .divisionByZero => "divisionByZero"
  | .arithmeticError => "arithmeticError"
  | .undefinedIndex => "undefinedIndex"
  | .unhandledMatch => "unhandledMatch"
  | .thrown name => "thrown:" ++ name

def output (display : α → String) (result : Php.M α) : IO Unit :=
  IO.println (match result with
    | .ok value => "ok:" ++ display value
    | .error error => "error:" ++ exc error)

def main : IO Unit := do
  for inputs in [([1, 2, 3], 5), ([1, -3, 4], 0), ([1, 5, 9], 2), ([], 4)] do
    output toString (loops inputs.1 inputs.2)
  output (fun (a, b) => s!"{a},{b}") (product (4, "é"))
  output toString (integers (-5) 3)
  output toString (integers 5 0)
  output toString (integers (-9223372036854775808) (-1))
  output (fun value => toString (value == (-6.0 : Float))) (floats 5.0 3.0)
  output (fun value => toString (value == (-6.0 : Float))) (floats 5.0 (-0.0))
  IO.println (words "A\x00é猫" "🌱")
  for a in [false, true] do
    for b in [false, true] do
      for x in [none, some (2 : Int)] do
        IO.println (logic a b x)
  output toString (choices .Red 2)
  output toString (choices .Red 0)
  output toString (choices .Blue 0)
  output toString (choices .Blue 1)
  output toString (indexing 2)
  output toString (indexing (-1))
  output toString (early 2)
  output toString (early 0)
  output toString (objects ⟨1⟩ ⟨-2, 5, by decide⟩)
  output toString (calls 12)
  output toString (increment 5)
  output toString (increment 9223372036854775807)
  IO.println (clamp 12 1 4)
  output toString (add 3 4)
  IO.println (order 2 4)
  IO.println (order 4 2)
  IO.println (nullable none == none)
  IO.println (nullable (some 1) == some 3)
  IO.println (countInput (-1))
  for x in [-2, 0, 2] do
    output toString (branchLocal x)
  output toString (generated 2 5)
  output toString (generated 5 2)
  output toString (standalone (-4))
