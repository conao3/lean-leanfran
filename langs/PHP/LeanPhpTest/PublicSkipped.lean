import Lean

namespace LeanPhpTest.PublicSkipped

def nested (x : Option (Option Nat)) := x

def nullable (x : Option Unit) := x

inductive Indexed : Nat → Type where
  | zero : Indexed 0

def indexed (x : Indexed 0) := x

class Witness where
  p : Nat

def aClass (x : Witness) := x.p

inductive Proof : Prop where
  | trivial

private def hidden (n : Nat) := n

private structure Hidden where
  n : Nat

def hiddenType : Hidden := ⟨hidden 0⟩

inductive TypeField where
  | mk (α : Type) (a : α)

opaque untested : Nat → Prop

structure Undecidable where
  n : Nat
  ok : untested n

def bytes (b : ByteArray) := b

def thunk (t : Thunk Nat) := t

def task (t : Task Nat) := t

def library (v : Std.HashMap Nat Nat) := v

def metaprogram (n : Lean.Name) := n

def path (p : System.FilePath) := p

def ioError (e : IO.Error) := e

def generic (x : α) := x

def higher (f : Nat → Nat) := f 1

def proofArg (n : Nat) (_ : n < 10) := n

end LeanPhpTest.PublicSkipped
