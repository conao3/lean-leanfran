import Lean.Data.Json

/-! Values printed as JSON by `oracle-json` (Lean's `deriving ToJson`) and by the generated
pydantic models (`tests/test_json.py`); both must give the same JSON. -/

namespace LeanPythonTest.Json

open Lean

structure Inner where
  label : String
  weight : Nat
  deriving ToJson, FromJson

structure Outer where
  name : String
  inner : Inner
  note : Option String
  tags : List String
  pair : Nat × Bool
  scores : Array Int
  deriving ToJson, FromJson

inductive Shape where
  | circle (radius : Nat)
  | rect (width height : Nat)
  | dot
  deriving ToJson, FromJson

inductive Token where
  | num : Nat → Token
  | pair : Nat → String → Token
  | single (only : String)
  deriving ToJson, FromJson

inductive Color where
  | red | green | blue
  deriving ToJson, FromJson

inductive Tree where
  | leaf
  | node (l : Tree) (v : Nat) (r : Tree)
  deriving ToJson, FromJson

structure Names where
  note? : Option String
  lambda : Nat
  x' : Nat
  deriving ToJson, FromJson

def names : List Names := [{ note? := some "n", lambda := 1, x' := 2 }, { note? := none, lambda := 3, x' := 4 }]

def outers : List Outer :=
  [{ name := "a", inner := ⟨"x", 1⟩, note := some "n", tags := ["t1", "t2"], pair := (3, true), scores := #[-1, 2] },
   { name := "é日", inner := ⟨"", 0⟩, note := none, tags := [], pair := (0, false), scores := #[] }]

def shapes : List Shape := [.circle 3, .rect 1 2, .dot]

def tokens : List Token := [.num 7, .pair 1 "x", .single "s"]

def colors : List Color := [.red, .green, .blue]

def trees : List Tree := [.leaf, .node (.node .leaf 1 .leaf) 2 .leaf]

def lines : List String :=
  (outers.map fun o => (toJson o).compress) ++ (shapes.map fun s => (toJson s).compress) ++
  (tokens.map fun t => (toJson t).compress) ++ (colors.map fun c => (toJson c).compress) ++
  (trees.map fun t => (toJson t).compress) ++ (names.map fun n => (toJson n).compress)

end LeanPythonTest.Json
