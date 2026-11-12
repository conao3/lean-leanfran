module
public import Aeneas
public import LeanRustGen.Model.lean_rust_verify_test.Types
@[expose] public section
open Aeneas Aeneas.Std Result

/-- `trace` only counts its calls. -/
def effects.trace : Result Unit := ok ()

/-- `check` panics on 7; the model assumes that it returns. -/
axiom effects.check : Std.U32 → Result Unit

axiom effects.check_ok : ∀ x, effects.check x = ok ()

/-- `clamp` caps at 100. -/
def effects.clamp (x : Std.U32) : Result Std.U32 := if x.val ≤ 100 then ok x else ok 100#u32

/-- `Meter.lesser` is the smaller of the reading and the limit. -/
def effects.Meter.lesser (self : lean_rust_verify_test.effects.Meter) (limit : Std.U32) : Result Std.U32 :=
  if self.value.val ≤ limit.val then ok self.value else ok limit
