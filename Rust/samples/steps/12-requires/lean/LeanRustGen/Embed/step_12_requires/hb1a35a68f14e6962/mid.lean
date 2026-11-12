import Aeneas
namespace mid

open Aeneas Aeneas.Std

def ordered (lo hi : Std.U32) : Bool := decide (lo.val ≤ hi.val)

def between (lo hi r : Std.U32) : Bool := decide (lo.val ≤ r.val ∧ r.val ≤ hi.val)

end mid
