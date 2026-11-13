import Aeneas
namespace sums

open Aeneas Aeneas.Std

/-- `0 + 1 + … + n`, in closed form. -/
def sum_to (n : Std.U32) : Std.U64 := ⟨BitVec.ofNat 64 (n.val * (n.val + 1) / 2)⟩

end sums
