import Aeneas
namespace bits

open Aeneas Aeneas.Std

def popcount (x : Std.U64) : Std.U32 :=
  ⟨BitVec.ofNat 32 ((List.range 64).countP fun i => x.val.testBit i)⟩

def max (a b : Std.U32) : Std.U32 := if a.val ≤ b.val then b else a

def max_bound (a b : Std.U32) (r : Std.U32) : Bool := decide (a.val ≤ r.val ∧ b.val ≤ r.val)

end bits
