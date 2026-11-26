namespace Typed

inductive Color where
  | red
  | brightBlue
  deriving BEq

structure Single (α : Type) where
  data : α
  deriving BEq

inductive Tree where
  | empty
  | leaf (text : String)
  | fork (left right : Tree)
  deriving BEq

structure Mixed (α : Type) where
  switch : Bool
  short : Int16
  text : String
  count : UInt64
  index : USize
  smallFloat : Float32
  weight : Float
  color : Color
  single : Single Int64
  holder : Single α
  flag : True
  deriving BEq

private def sample : Mixed Nat := {
  switch := true
  short := -1234
  text := "雪\x00é"
  count := 18446744073709551615
  index := 191
  smallFloat := 0.25
  weight := -8.5
  color := .brightBlue
  single := ⟨-9223372036854775808⟩
  holder := ⟨123456789012345678901234567890⟩
  flag := trivial
}

def mixed : Mixed Nat := sample

def checkMixed (value : Mixed Nat) : Bool := value == sample

def tree : Tree := .fork (.leaf "木") (.fork .empty (.leaf "葉"))

def checkTree (value : Tree) : Bool := value == tree

def color (value : Color) : Color := value

def single (value : Single UInt64) : Single UInt64 := value

abbrev Count := Nat

private def arraySample : Array (Option (Nat × String)) := #[some (17, "値"), none]

def arrays (values : Array (Option (Count × String))) : Array (Option (Nat × String)) :=
  if values.isEmpty || values == arraySample then values else #[]

def sampleArray : Array (Option (Nat × String)) := arraySample

structure Empty where

def empty : Empty := ⟨⟩

def lists (values : List Int) : IO (List Int) := pure values

def bytes (values : ByteArray) : ByteArray := values

def naturals (value : Nat) : Nat := value

def integers (value : Int) : Int := value

def options (value : Option (Option Bool)) : Option (Option Bool) := value

def multiple (text : String) (value : Tree) : Option String :=
  match value with
  | .empty => none
  | _ => some text

inductive Problem where
  | noValue
  | invalid (code : Nat) (message : String)

def checked (code : Nat) : IO (Except Problem (Option Nat)) :=
  if code == 0 then pure (.error .noValue)
  else if code == 1 then pure (.error (.invalid 123456789012345678901234567890 "雪\n\"\x00"))
  else if code == 2 then throw (IO.userError "runtime error")
  else pure (.ok (some code))

inductive Positional where
  | item : UInt16 → Bool → Positional

def positional (ok : Bool) : Except Positional UInt8 :=
  if ok then .ok 13 else .error (.item 42 true)

def checkUnit (ok : Bool) : Except String Unit :=
  if ok then .ok () else .error "unit error"

inductive WrapText where
  | mk (text : String)
  deriving BEq

inductive WrapByte where
  | mk (byte : UInt8)
  deriving BEq

inductive WrapNat where
  | mk : Nat → WrapNat
  deriving BEq

inductive WrapFloat where
  | mk (value : Float)
  deriving BEq

structure Point where
  x : UInt32
  label : String
  deriving BEq

inductive WrapPoint where
  | mk (point : Point)
  deriving BEq

inductive Bounded where
  | mk (byte : UInt8) (small : byte < 10)
  deriving BEq

structure Wrapped where
  text : WrapText
  byte : WrapByte
  nat : WrapNat
  weight : WrapFloat
  point : WrapPoint
  bounded : Bounded
  deriving BEq

def wrapText (value : WrapText) : WrapText :=
  match value with | .mk text => .mk (text ++ "!")

def wrapByte (value : WrapByte) : WrapByte :=
  match value with | .mk byte => .mk (byte + 1)

def wrapNat (value : WrapNat) : WrapNat :=
  match value with | .mk n => .mk (n * 2)

def wrapFloat (value : WrapFloat) : WrapFloat :=
  match value with | .mk x => .mk (x + 0.5)

def wrapPoint (value : WrapPoint) : WrapPoint :=
  match value with | .mk p => .mk { p with x := p.x + 1, label := p.label ++ "?" }

def bounded (byte : UInt8) : Option Bounded :=
  if h : byte < 10 then some (.mk byte h) else none

def boundedByte (value : Bounded) : UInt8 :=
  match value with | .mk byte _ => byte

def wrapped (value : Wrapped) : Array Wrapped :=
  #[value, { value with
    text := wrapText value.text, byte := wrapByte value.byte, nat := wrapNat value.nat,
    weight := wrapFloat value.weight, point := wrapPoint value.point }]

def unsupported (f : Nat → Nat) : Nat := f 1

def floats (values : FloatArray) : FloatArray := values

def floatSum (values : FloatArray) : Float := values.foldl (· + ·) 0

def floatMake (n : UInt8) : FloatArray := (FloatArray.empty.push 1.5).push n.toFloat

structure Samples where
  values : FloatArray
  label : String
  deriving BEq

def samples (value : Samples) : Samples := { value with values := value.values.push value.values.size.toFloat }

def taskGet (task : Task UInt8) : UInt8 := task.get

def taskPure (n : UInt8) : Task UInt8 := Task.pure n

def thunkGet (thunk : Thunk UInt8) : UInt8 := thunk.get

structure Pending where
  label : String
  task : Task UInt8

def pendingGet (value : Pending) : UInt8 := value.task.get

end Typed

namespace Collision

def fooBar : Bool := true

def foo_bar : Bool := false

structure Fields where
  fooBar : Bool
  foo_bar : UInt64

def echo (value : Fields) : Fields := value

end Collision

namespace Checked

abbrev Small := { n : UInt16 // n.toNat < 20 }

structure Range where
  low : Nat
  high : Nat
  limit : Fin 8
  capacity : Small
  ordered : low ≤ high
  nonzero : high > 0

def echo (value : Range) : Range := value

def batch (values : Array Range) : Array Range := values

opaque secret : Prop := True

structure Undecidable where
  value : Nat
  proof : secret

def bad (value : Undecidable) : Nat := value.value

end Checked

namespace Schema

structure Base where
  title : String
  huge : Nat

structure Record extends Base where
  tree : Typed.Tree
  pair : Int × Bool
  count : UInt64
  ratio : Float
  values : List (Option Nat)
  omitted? : Option String

def sample : Record := {
  title := "雪\x00😀\n\t\r\""
  huge := 123456789012345678901234567890
  tree := Typed.tree
  pair := (-123456789012345678901234567890, true)
  count := 18446744073709551615
  ratio := -8.5
  values := [some 3, none]
  omitted? := none
}

end Schema
