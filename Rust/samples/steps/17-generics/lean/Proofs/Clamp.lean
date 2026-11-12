import LeanRustGen.Obligation.step_17_generics
open Aeneas Aeneas.Std Result LeanRust

namespace step_17_generics

theorem clamp.proof.within : clamp.obligation.within := by
  intro T _ ord _ copy x lo hi h
  simp [_root_.range.ordered] at h
  unfold clamp _root_.range.within
  step*

end step_17_generics
