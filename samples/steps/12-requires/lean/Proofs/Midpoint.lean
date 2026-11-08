import LeanRustGen.Obligation.step_12_requires
open Aeneas Aeneas.Std Result

namespace step_12_requires

theorem midpoint.proof.between : midpoint.obligation.between := by
  intro lo hi h
  simp [_root_.mid.ordered] at h
  unfold midpoint _root_.mid.between
  step*
  simp_all
  scalar_tac

end step_12_requires
