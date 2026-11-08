import Aeneas
import LeanRustGen.Lib.Instances
namespace generic_specs

open Aeneas Aeneas.Std

def max_ge {α : Type} [LinearOrder α] (a b r : α) : Bool := decide (a ≤ r ∧ b ≤ r)

rust_instances max_ge [Std.U32, Std.I64]

def larger {α : Type} [LinearOrder α] (a b : α) : α := max a b

rust_instances larger [Std.U32, Std.I64]

end generic_specs
