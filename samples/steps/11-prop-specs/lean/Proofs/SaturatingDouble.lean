import LeanRustGen.Obligation.step_11_prop_specs
open Aeneas Aeneas.Std Result

namespace step_11_prop_specs

theorem saturating_double.proof.exact : saturating_double.obligation.exact := by
  intro x
  unfold saturating_double _root_.double.IsSaturatingDouble
  step* <;> simp_all [core.num.U32.MAX, U32.rMax] <;> scalar_tac

end step_11_prop_specs
