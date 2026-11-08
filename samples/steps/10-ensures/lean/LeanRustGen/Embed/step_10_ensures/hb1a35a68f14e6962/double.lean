import Aeneas
namespace double

open Aeneas Aeneas.Std

/-- The result is not less than the argument. -/
def ge (x r : Std.U32) : Bool := decide (x.val ≤ r.val)

end double
