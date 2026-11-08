import Aeneas
namespace sorting

open Aeneas Aeneas.Std

def sorted (xs : List Std.I64) : Bool := decide (xs.Pairwise (·.val ≤ ·.val))

def input_sorted (_x : Std.I64) (xs : Slice Std.I64) : Bool := sorted xs.val

def output_sorted (_x : Std.I64) (_xs : Slice Std.I64) (out : alloc.vec.Vec Std.I64) : Bool :=
  sorted out.val

def OutputPerm (x : Std.I64) (xs : Slice Std.I64) (out : alloc.vec.Vec Std.I64) : Prop :=
  out.val.Perm (x :: xs.val)

end sorting
