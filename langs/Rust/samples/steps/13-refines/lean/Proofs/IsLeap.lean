import LeanRustGen.Obligation.step_13_refines
open Aeneas Aeneas.Std Result

namespace step_13_refines

theorem eq_ok_of_spec {α : Type} {m : Result α} {v : α} (h : m ⦃ r => r = v ⦄) : m = ok v := by
  cases m with
  | ret r => simp_all [WP.spec_ok]
  | vis i k => simp [WP.spec_vis] at h
  | div => simp [WP.spec_div] at h

theorem is_leap.proof.refines : is_leap.obligation.refines := by
  intro year
  apply eq_ok_of_spec
  unfold is_leap _root_.calendar.leap
  step*

end step_13_refines
