import Aeneas
import LeanRustGen.Model.step_15_structs_enums.Types
namespace counter

open Aeneas Aeneas.Std step_15_structs_enums

def apply (c : Counter) (a : Action) : Counter :=
  match a with
  | .Add n => { c with count := if c.max.val - c.count.val ≤ n.val then c.max else ⟨c.count.bv + n.bv⟩ }
  | .Reset => { c with count := 0#u32 }

def within (c : Counter) (_a : Action) : Bool := decide (c.count.val ≤ c.max.val)

end counter
