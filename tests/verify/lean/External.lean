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
