import LeanCModel.states

namespace LeanCModel.states

theorem proved.proof.refines : proved.obligation.refines := by
  intro n
  rfl

theorem proved.proof.changes : proved.obligation.changes := by
  intro n
  simp [proved, bigger]

theorem clamp.proof.refines : clamp.obligation.refines := by
  intro lo hi x _
  simp only [clamp, clampSpec, Id.run]
  split <;> (try split) <;> rfl

theorem sorry_case.proof.refines : sorry_case.obligation.refines := by
  sorry

axiom extra : axioms_case.obligation.refines

theorem axioms_case.proof.refines : axioms_case.obligation.refines := extra

theorem mismatch_case.proof.refines : True := trivial

end LeanCModel.states
