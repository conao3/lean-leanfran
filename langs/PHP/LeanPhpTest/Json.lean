import Lean.Data.Json

namespace LeanPhpTest.Json

open Lean

structure Big where
  n : Nat
  deriving ToJson, FromJson

structure Parent where
  label : String
  deriving ToJson, FromJson

structure Data extends Parent where
  amount : UInt64
  word : USize
  f : Float
  note? : Option String
  normal : Option Nat
  u : Unit
  deriving ToJson, FromJson

inductive Shape where
  | none
  | fixed (amount : Nat)
  | positional : Nat → Shape
  | pair : Nat → String → Shape
  deriving ToJson, FromJson

inductive Color where
  | red
  | blue
  deriving ToJson, FromJson

inductive Tree where
  | leaf
  | node (l : Tree) (n : Nat) (r : Tree)
  deriving ToJson, FromJson

def big : Big := ⟨2 ^ 100⟩

def bigEcho (b : Big) : Big := b

def data : List Data :=
  [⟨⟨"é日"⟩, 2 ^ 64 - 1, 2 ^ 64 - 1, 0.0 / 0.0, none, none, ()⟩,
   ⟨⟨"Infinity"⟩, 17, 19, 1.0 / 0.0, some "1234567890123456789012345", some 0, ()⟩,
   ⟨⟨"負"⟩, 0, 0, -1.0 / 0.0, none, none, ()⟩,
   ⟨⟨"finite"⟩, 0, 0, 1.0 / 3.0, none, none, ()⟩,
   ⟨⟨"large"⟩, 0, 0, 1.0e30, none, none, ()⟩,
   ⟨⟨"negative zero"⟩, 0, 0, -0.0, none, none, ()⟩]

def shapes : List Shape := [.none, .fixed 5, .positional 6, .pair 7 "♥"]

def colors : List Color := [.red, .blue]

def trees : List Tree := [.leaf, .node .leaf 1 (.node .leaf (2 ^ 65) .leaf)]

def lines : List String :=
  [(toJson big).compress] ++ data.map (Json.compress ∘ toJson) ++
    shapes.map (Json.compress ∘ toJson) ++ colors.map (Json.compress ∘ toJson) ++
    trees.map (Json.compress ∘ toJson)

end LeanPhpTest.Json
