import LeanRustGen.Obligation.step_16_opaque
open Aeneas Aeneas.Std Result

namespace step_16_opaque

theorem bar_width.proof.fits : bar_width.obligation.fits := by
  intro p
  unfold bar_width percent _root_.bar.fits
  split <;> step*

end step_16_opaque
