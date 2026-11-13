import Aeneas
namespace specs

open Aeneas Aeneas.Std

def bigger (a b : Std.U32) : Std.U32 := if a.val ≤ b.val then b else a

def double (x : Std.U32) : Std.U32 := ⟨BitVec.ofNat 32 (x.val * 2)⟩

def halved (x r : Std.U32) : Bool := decide (r.val ≤ x.val)

def small (x : Std.U32) : Bool := decide (x.val < 1000)

def positive (_x r : Std.U32) : Bool := decide (0 < r.val)

def unchanged (x r : Std.U32) : Bool := r == x

def all_zero (_v : alloc.vec.Vec Std.U32) (r : alloc.vec.Vec Std.U32) : Bool :=
  r.val.all (·.val == 0)

def arr_sum (a : Std.Array Std.U32 3#usize) : Std.U64 := ⟨BitVec.ofNat 64 (a.val.map (·.val)).sum⟩

def arr_fill (x : Std.U32) : Std.Array Std.U32 3#usize := Std.Array.repeat 3#usize x

end specs
