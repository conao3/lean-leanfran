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

def unsupported (f : Nat → Nat) : Nat := f 1

end Typed

namespace Collision

def fooBar : Bool := true

def foo_bar : Bool := false

structure Fields where
  fooBar : Bool
  foo_bar : UInt64

def echo (value : Fields) : Fields := value

end Collision
