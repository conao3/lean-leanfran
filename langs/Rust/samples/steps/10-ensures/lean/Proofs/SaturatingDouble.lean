import LeanRustGen.Obligation.step_10_ensures
open Aeneas Aeneas.Std Result

namespace step_10_ensures

theorem saturating_double.proof.ge : saturating_double.obligation.ge := by
  intro x
  unfold saturating_double _root_.double.ge
  step* <;> simp_all [core.num.U32.MAX, U32.rMax] <;> scalar_tac

end step_10_ensures
