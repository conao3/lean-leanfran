import LeanRustGen.Obligation.lean_rust_verify_test.effects
open Aeneas Aeneas.Std Result

namespace lean_rust_verify_test.effects

theorem guarded.proof.same : guarded.obligation.same := by
  intro x
  unfold guarded _root_.specs.unchanged
  simp [_root_.effects.check_ok]

end lean_rust_verify_test.effects
