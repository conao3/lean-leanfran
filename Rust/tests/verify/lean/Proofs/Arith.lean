import LeanRustGen.Obligation.leanfran_verify_test.arith
open Aeneas Aeneas.Std Result

namespace leanfran_verify_test.arith

theorem bigger.proof.refines : bigger.obligation.refines := by
  intro a b
  unfold bigger _root_.specs.bigger
  by_cases h : a.val ≤ b.val <;> simp [UScalar.le_equiv, h, _root_.effects.trace]

theorem double.proof.refines : double.obligation.refines := by
  sorry

theorem succ.proof.pos : True := trivial

end leanfran_verify_test.arith
