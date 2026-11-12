import Aeneas
import LeanRustGen.Extern.lean_rust_verify_test.effects
namespace calls

open Aeneas Aeneas.Std

/-- Runs the Rust function `guarded`: `false` when it panics. -/
def runs (x : Std.U32) : Bool :=
  match (lean_rust_verify_test.effects.guarded.rs x).match with
  | .ok _ => true
  | _ => false

end calls
