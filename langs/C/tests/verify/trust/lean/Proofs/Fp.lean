import LeanCModel.fp

namespace LeanCModel.fp

theorem muladd.proof.refines : muladd.obligation.refines := by
  intro a b c
  rfl

theorem widen.proof.refines : widen.obligation.refines := by
  intro x
  rfl

end LeanCModel.fp
