import Aeneas
namespace bar

open Aeneas Aeneas.Std

def fits (_p r : Std.U32) : Bool := decide (r.val ≤ 20)

end bar
