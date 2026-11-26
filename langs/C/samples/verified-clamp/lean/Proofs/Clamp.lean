import LeanCModel.clamp

namespace LeanCModel.clamp

theorem clamp.proof.refines : clamp.obligation.refines := by
  intro lo hi x _
  simp only [clamp, spec, Id.run]
  split <;> (try split) <;> rfl

end LeanCModel.clamp
