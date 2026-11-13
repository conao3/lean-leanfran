import Aeneas
import LeanRustGen.Lib.Instances
namespace range

open Aeneas Aeneas.Std

def ordered {α : Type} [LinearOrder α] (_x lo hi : α) : Bool := decide (lo ≤ hi)

def within {α : Type} [LinearOrder α] (_x lo hi r : α) : Bool := decide (lo ≤ r ∧ r ≤ hi)

rust_instances ordered [Std.U32, Std.I64]

rust_instances within [Std.U32, Std.I64]

end range
