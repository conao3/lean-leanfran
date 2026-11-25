module

import LeanCLib.C

namespace ModelOps

private def integer [C.IntType α] [Add α] [Sub α] [Mul α] [Neg α] [Complement α]
    [AndOp α] [OrOp α] [XorOp α] [LT α] [LE α] [DecidableLT α] [DecidableLE α]
    [BEq α] (op : String) (a b : α) (count : Int) : C.M UInt64 := do
  let result ← match op with
    | "add" => if C.IntType.signed α then C.addS a b else pure (a + b)
    | "sub" => if C.IntType.signed α then C.subS a b else pure (a - b)
    | "mul" => if C.IntType.signed α then C.mulS a b else pure (a * b)
    | "neg" => if C.IntType.signed α then C.negS a else pure (-a)
    | "div" => C.div a b
    | "mod" => C.mod a b
    | "shl" => C.shl a count
    | "shr" => C.shr a count
    | "and" => pure (a &&& b)
    | "or" => pure (a ||| b)
    | "xor" => pure (a ^^^ b)
    | "not" => pure (~~~a)
    | "eq" => pure (C.cast (a == b))
    | "ne" => pure (C.cast (a != b))
    | "lt" => pure (C.cast (decide (a < b)))
    | "le" => pure (C.cast (decide (a ≤ b)))
    | "gt" => pure (C.cast (decide (a > b)))
    | "ge" => pure (C.cast (decide (a ≥ b)))
    | _ => panic! "unknown integer operation"
  return C.cast result

private def floating (op : String) (a b : Float) : C.M UInt64 := do
  match op with
  | "add" => return (a + b).toBits
  | "sub" => return (a - b).toBits
  | "mul" => return (a * b).toBits
  | "div" => return (a / b).toBits
  | "neg" => return (-a).toBits
  | "eq" => return C.cast (a == b)
  | "ne" => return C.cast (a != b)
  | "lt" => return C.cast (decide (a < b))
  | "le" => return C.cast (decide (a ≤ b))
  | "gt" => return C.cast (decide (a > b))
  | "ge" => return C.cast (decide (a ≥ b))
  | "bool" => return C.cast (C.cast a : Bool)
  | "i8" => return C.cast (← C.floatToInt a : Int8)
  | "u8" => return C.cast (← C.floatToInt a : UInt8)
  | "i16" => return C.cast (← C.floatToInt a : Int16)
  | "u16" => return C.cast (← C.floatToInt a : UInt16)
  | "i32" => return C.cast (← C.floatToInt a : Int32)
  | "u32" => return C.cast (← C.floatToInt a : UInt32)
  | "i64" => return C.cast (← C.floatToInt a : Int64)
  | "u64" => return ← C.floatToInt a
  | "size" => return C.cast (← C.floatToInt a : USize)
  | _ => panic! "unknown floating-point operation"

private def convert (op : String) (signed : Int64) (unsigned : UInt64) : UInt64 :=
  match op with
  | "i8" => C.cast (C.cast unsigned : Int8)
  | "u8" => C.cast (C.cast signed : UInt8)
  | "i16" => C.cast (C.cast unsigned : Int16)
  | "u16" => C.cast (C.cast signed : UInt16)
  | "i32" => C.cast (C.cast unsigned : Int32)
  | "u32" => C.cast (C.cast signed : UInt32)
  | "i64" => C.cast (C.cast unsigned : Int64)
  | "u64" => C.cast signed
  | "size" => C.cast (C.cast signed : USize)
  | "bool" => C.cast (C.cast signed : Bool)
  | "double_s" => (C.cast signed : Float).toBits
  | "double_u" => (C.cast unsigned : Float).toBits
  | "double_bool" => (C.cast (C.cast signed : Bool) : Float).toBits
  | "promote" => C.cast ((C.cast (C.cast signed : Int8) : Int32) +
      (C.cast (C.cast unsigned : UInt16) : Int32))
  | _ => panic! "unknown conversion"

private def run (kind op : String) (a b : UInt64) : C.M UInt64 := do
  let x := a.toInt64
  let y := b.toInt64
  match kind with
  | "i32" => integer op a.toUInt32.toInt32 b.toUInt32.toInt32 y.toInt
  | "i64" => integer op x y y.toInt
  | "u32" => integer op a.toUInt32 b.toUInt32 y.toInt
  | "u64" => integer op a b y.toInt
  | "double" => floating op (Float.ofBits a) (Float.ofBits b)
  | "cast" => return convert op x a
  | "index" => C.index #[a, ~~~a] y.toInt
  | "bool" =>
    let left : Bool := C.cast x
    let right := fun () => (C.div x y).map (C.cast ·)
    match op with
    | "and" => return C.cast (← C.andThen left right)
    | "or" => return C.cast (← C.orElse left right)
    | "not" => return C.cast (!left)
    | _ => panic! "unknown logical operation"
  | _ => panic! "unknown type"

public def evaluate (kind op : @& String) (a b : UInt64) : IO UInt64 :=
  match run kind op a b with
  | .ok value => pure value
  | .error e => throw (IO.userError (match e with
    | .signedOverflow => "signedOverflow"
    | .divByZero => "divByZero"
    | .shiftOutOfRange => "shiftOutOfRange"
    | .floatToIntOutOfRange => "floatToIntOutOfRange"
    | .indexOutOfRange => "indexOutOfRange"
    | .diverged => "diverged"
    | .missingReturn => "missingReturn"))

end ModelOps
