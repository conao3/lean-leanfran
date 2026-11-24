import Lean.Data.Json

namespace LeanGoTest.Public

structure Range where
  lo : Nat
  hi : Nat
  ok : lo ≤ hi

inductive Discount where
  | none
  | percent (p : Nat) (h : p ≤ 100)
  | fixed (amount : Nat)

def total (prices : List Nat) (d : Discount) : Nat :=
  let sum := prices.foldl (· + ·) 0
  match d with
  | .none => sum
  | .percent p _ => sum - sum * p / 100
  | .fixed amount => sum - amount

def Small := {val : Nat // val < 10}
def smallEcho (n : Small) : Small := n
def anonymousEcho (n : {val : Nat // val < 10}) : Nat := n.val

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

structure Bigger extends Packed where
  extra : Nat

def packedEcho (p : Packed) : Packed := p
def packedRead (p : Packed) : UInt64 := p.u64 + p.usize.toUInt64
def biggerEcho (b : Bigger) : Bigger := b
def uintEcho (n : UInt64) : UInt64 := n
def unitEcho (_ : Unit) : Unit := ()
def listEcho (n : List UInt32) : List UInt32 := n
def byteEcho (b : ByteArray) : ByteArray := b
def rangeEcho (r : Range) : Range := r
def arrEcho (r : Array Range) : Array Range := r

structure Choices where
  fit : Fin (2 ^ 64)
  large : Fin (2 ^ 80)
  pair : String × Bool
  result : Except String Nat
  maybe : Option (Option Nat)

def choicesEcho (c : Choices) : Choices := c

def exceptEcho (success : Bool) : Except UInt32 String :=
  if success then .ok "success" else .error 17
def ioEcho (s : String) : IO String := pure (s ++ "!")
def ioFail (_ : Unit) : IO Nat := throw (IO.userError "nope")
set_option compiler.extract_closed false in
@[noinline] def unreachableValue (value : Empty) : Nat := nomatch value

set_option compiler.extract_closed false in
@[noinline] unsafe def executeUnreachable (value : Nat) : Nat :=
  if value == 0 then value else unreachableValue (unsafeCast value)


structure String where
  type : Nat
  func : Nat
  validate : Nat

def lowerCase (x : Nat) : Nat := x
def lower_case (x : Nat) : Nat := x + 1

structure Generic (α : Type) where
  item : α

def genericEcho (x : Generic Nat) : Generic Nat := x

inductive Indexed : Nat → Type
  | z : Indexed 0

class AClass where
  value : Nat

inductive AProp : Prop
  | here : AProp

inductive HasType
  | mk (α : Type) (value : α)

axiom undecidable : Nat → Prop

structure NoDecider where
  value : Nat
  proof : undecidable value

private def secret (x : Nat) : Nat := x

def thunkEcho (x : Thunk Nat) : Thunk Nat := x
def taskEcho (x : Task Nat) : Task Nat := x
def leanEcho (x : Lean.Name) : Lean.Name := x
def stdEcho (x : Std.TreeMap Nat Nat) : Std.TreeMap Nat Nat := x
def ioRefEcho (x : IO.Ref Nat) : IO.Ref Nat := x
def systemEcho (x : System.FilePath) : System.FilePath := x

end LeanGoTest.Public
