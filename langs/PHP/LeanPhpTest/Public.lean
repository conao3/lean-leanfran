import Lean.Data.Json

namespace LeanPhpTest.Public

structure Range where
  lo : Nat
  hi : Nat
  ok : lo ≤ hi

inductive Discount where
  | none
  | percent (p : Nat) (h : p ≤ 100)
  | fixed (amount : Nat)
  | limited (n : Nat) : n < 4 → Discount

def total (prices : List Nat) (d : Discount) : Nat :=
  let sum := prices.foldl (· + ·) 0
  match d with
  | .none => sum
  | .percent p _ => sum - sum * p / 100
  | .fixed amount => sum - amount
  | .limited n _ => sum - n

structure Bounds where
  first : Range
  rest : Array Range

def ranges (xs : List Range) : List Range := xs

def rangeWidth (r : Range) : Nat := r.hi - r.lo

def discountEcho (d : Discount) : Discount := d

def small (n : {val : Nat // val < 10}) : Nat := n.val * 2

def Small := {val : Nat // val < 10}

def smallEcho (n : Small) : Small := n

structure Packed where
  flag : Bool
  u8 : UInt8
  u16 : UInt16
  u32 : UInt32
  u64 : UInt64
  usize : USize
  i8 : Int8
  i16 : Int16
  i32 : Int32
  i64 : Int64
  isize : ISize
  f64 : Float
  f32 : Float32
  c : Char
  s : String
  n : Nat
  i : Int
  unit : Unit
  deriving Inhabited

def packedEcho (p : Packed) : Packed := p

def packedRead (p : Packed) : UInt64 := p.u64 + p.usize.toUInt64

def unitEcho (_ : Unit) : Unit := ()

def containers (o : Option Nat) (a : Array Int) (p : String × Bool)
    (e : Except String Nat) : Option Nat × Array Int × (String × Bool) × Except String Nat :=
  (o, a, p, e)

structure Choices where
  fit : Fin 10
  large : Fin (2 ^ 80)
  pair : String × Bool
  result : Except String Nat
  maybe : Option Nat

def choicesEcho (c : Choices) : Choices := c

def finEcho (n : Fin (2 ^ 63)) : Fin (2 ^ 63) := n

def bigFinEcho (n : Fin (2 ^ 80)) : Fin (2 ^ 80) := n

def ioEcho (s : String) : IO String := pure (s ++ "!")

def ioFail (_ : Unit) : IO Nat := throw (IO.userError "nope")

structure Bigger extends Packed where
  extra : Nat

def biggerEcho (b : Bigger) : Bigger := b

structure Pair (α β : Type) where
  first : α
  second : β

inductive Single where
  | one (n : Nat)

def singleEcho (n : Single) : Single := n

def pairEcho (p : Pair Nat Bool) : Pair Nat Bool := p

structure Sized where
  tag : String
  items : List Nat
  tagOk : 0 < tag.length
  itemsOk : items.length ≤ 3

def sizedEcho (s : Sized) : Sized := s

end LeanPhpTest.Public
