import LeanCModel.states

namespace LeanCModel.states

theorem failed_case.proof.refines : failed_case.obligation.refines := by
  intro n
  exact (rfl : n = n + 1)

end LeanCModel.states
