import LeanCModel.Fixture

open LeanCModel.«fixture»

abbrev P := StateM (List String)

def word : P String := do
  match ← get with
  | w :: rest => set rest; return w
  | [] => return "0"

def int : P Int := return (← word).toInt!
def nat : P Nat := return (← word).toNat!
def i8 : P Int8 := return Int8.ofInt (← int)
def i32 : P Int32 := return Int32.ofInt (← int)
def i64 : P Int64 := return Int64.ofInt (← int)
def u16 : P UInt16 := return UInt16.ofNat (← nat)
def u32 : P UInt32 := return UInt32.ofNat (← nat)
def u64 : P UInt64 := return UInt64.ofNat (← nat)
def usize : P USize := return USize.ofNat (← nat)
def flagArg : P Bool := return (← nat) != 0
def double : P Float := return Float.ofBits (← u64)
def point : P Geo.Point := return {x := ← i32, y := ← i32}

def itemArg : P «item» := do
  let qty ← u32
  let price ← i64
  let weight ← usize
  if h : Int.ofNat qty.toNat ≥ (1 : Int) then return ⟨qty, h, price, weight⟩
  else return ⟨1, by decide, price, weight⟩

def array (elem : P α) : P (Array α) := do
  let n ← nat
  let mut xs := #[]
  for _ in [0:n] do xs := xs.push (← elem)
  return xs

def exc : C.Exc → String
  | .signedOverflow => "signedOverflow"
  | .divByZero => "divByZero"
  | .shiftOutOfRange => "shiftOutOfRange"
  | .floatToIntOutOfRange => "floatToIntOutOfRange"
  | .indexOutOfRange => "indexOutOfRange"
  | .diverged => "diverged"
  | .missingReturn => "missingReturn"

def result (fmt : α → String) : C.M α → String
  | .ok value => fmt value
  | .error e => "!" ++ exc e

def bits (x : Float) : String := if x.isNaN then "nan" else toString x.toBits

def flag (b : Bool) : String := if b then "1" else "0"

def status : C.Status → Nat
  | .ok => 0
  | .invalid => 1
  | .except => 2
  | .io => 3
  | .notInitialized => 4

def outcome (fmt : α → String) : C.Status × Option α → String
  | (.ok, some v) => s!"0 {fmt v}"
  | (s, _) => s!"{status s} -"

def evaluate (name : String) : P String := do
  match name with
  | "clamp" => return toString («clamp» (← i32) (← i32) (← i32))
  | "add_i32" => return result toString («add_i32» (← i32) (← i32))
  | "twice" => return result toString («twice» (← i32))
  | "clamp_plus" => return result toString («clamp_plus» (← i32))
  | "arith_u32" => return toString («arith_u32» (← u32) (← u32))
  | "div_mod" => return result toString («div_mod» (← i32) (← i32))
  | "shifts" => return result toString («shifts» (← i32) (← i32))
  | "ushift" => return result toString («ushift» (← u64) (← i32))
  | "narrow" => return result toString («narrow» (← i8) (← u16))
  | "conv" => return result toString («conv» (← i64))
  | "logic" => return result toString («logic» (← i32) (← i32))
  | "ternary" => return result toString («ternary» (← i32) (← i32))
  | "bools" => return result toString («bools» (← flagArg) (← flagArg) (← i32))
  | "doubles" => return bits («doubles» (← double) (← double))
  | "d2i" => return result toString («d2i» (← double))
  | "i2d" => return bits («i2d» (← i64) (← u64))
  | "dcmp" => return flag («dcmp» (← double) (← double))
  | "loop_while" => return result toString («loop_while» (← u32))
  | "loop_do" => return result toString («loop_do» (← i32))
  | "loop_for" => return result toString («loop_for» (← i32))
  | "nested_loops" => return result toString («nested_loops» (← i32))
  | "choose" => return result toString («choose» (← i32))
  | "switch_loop" => return result toString («switch_loop» (← i32))
  | "sum" => return result toString («sum» (← array i64))
  | "at" => return result toString («at» (← array i32) (← i32))
  | "total" => return result toString («total» (← array itemArg))
  | "item_value" => return result toString («item_value» (← itemArg))
  | "dot" => return result toString («dot» (← point) (← point))
  | "pick" =>
    let p := «pick» (← point) (← point) (← flagArg)
    return s!"{p.x} {p.y}"
  | "safe_div" =>
    return result (fun (s, out) => s!"{status s} {(out.map toString).getD "-"}")
      («safe_div» (← i32) (← i32))
  | "sum_twice" => return result toString («sum_twice» (← array i64))
  | "sum_prefix" => return result toString («sum_prefix» (← array i64) (← u32))
  | "div_sum" => return result (outcome toString) («div_sum» (← i32) (← i32) (← i32))
  | "forward" => return result (outcome toString) («forward» (← i32) (← i32))
  | "div_or" => return result toString («div_or» (← i32) (← i32) (← i32))
  | "countdown" => return result toString («countdown» (← i32) (← i32))
  | "checked_sum" => return result (outcome toString) («checked_sum» (← array i64))
  | "total_or" => return result toString («total_or» (← array i64))
  | "count_pos" => return result (outcome toString) («count_pos» (← array i32))
  | "count_or" => return result toString («count_or» (← array i32))
  | "size_ops" => return toString («size_ops» (← usize) (← u64))
  | "use_helper" => return result toString («use_helper» (← i32))
  | "uneg" => return toString («uneg» (← u32))
  | "lmix" => return result toString («lmix» (← i64) (← u32))
  | "lits" => return bits «lits»
  | "compare" => return result toString («compare» (← i32) (← i32))
  | "negate" => return result toString («negate» (← i32) (← double))
  | "compound" => return result toString («compound» (← i32) (← i32))
  | "nested_ternary" => return result toString («nested_ternary» (← i32) (← i32))
  | "and_ternary" => return result toString («and_ternary» (← i32) (← i32))
  | "bool_literal" => return result toString «bool_literal»
  | "shadow" => return result toString («shadow» (← i32))
  | "lit_pick" => return bits («lit_pick» (← i32))
  | _ => return s!"unknown function {name}"

partial def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let line := line.trimAsciiEnd.toString
    match line.splitOn " " with
    | name :: _ :: args =>
      let (value, _) := (evaluate name).run args
      stdout.putStrLn s!"{line} = {value}"
    | _ => pure ()
