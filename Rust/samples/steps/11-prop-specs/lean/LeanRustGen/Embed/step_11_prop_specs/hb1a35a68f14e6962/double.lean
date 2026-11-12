import Aeneas
namespace double

open Aeneas Aeneas.Std

/-- The result is `2 * x` cut at the largest `u32`. -/
def IsSaturatingDouble (x r : Std.U32) : Prop := r.val = min (2 * x.val) U32.max

end double
