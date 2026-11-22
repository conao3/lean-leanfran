import LeanPhpModel.App.Negative

namespace LeanPhpModel.App.Negative

theorem mismatch.proof.refines : True := trivial

axiom additional : withAxiom.obligation.refines
theorem withAxiom.proof.refines : withAxiom.obligation.refines := additional

theorem withSorry.proof.refines : withSorry.obligation.refines := by
  sorry

end LeanPhpModel.App.Negative
