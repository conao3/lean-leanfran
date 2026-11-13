import LeanRustGen.Obligation.leanfran_verify_test.effects
open Aeneas Aeneas.Std Result

namespace leanfran_verify_test.effects

theorem guarded.proof.same : guarded.obligation.same := by
  intro x
  unfold guarded _root_.specs.unchanged
  simp [_root_.effects.check_ok]

end leanfran_verify_test.effects
