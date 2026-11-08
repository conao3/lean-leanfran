module
public import Aeneas
public import LeanRustGen.Model.step_16_opaque.Types
@[expose] public section
open Aeneas Aeneas.Std Result
open step_16_opaque

/-- `percent` caps at 100. -/
def percent (x : Std.U32) : Result Std.U32 := if x.val ≤ 100 then ok x else ok 100#u32
