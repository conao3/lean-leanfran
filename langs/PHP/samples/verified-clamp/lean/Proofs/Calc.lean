import LeanPhpModel.App.Calc

open LeanPhpEmbed.App.Calc
namespace LeanPhpModel.App.Calc

theorem clamp.proof.refines : clamp.obligation.refines := by
  intro x lo hi h
  simp only [ordered, decide_eq_true_eq] at h
  simp only [clamp, clampSpec]
  split <;> (try split) <;> simp_all <;> omega

theorem clamp.proof.in_range : clamp.obligation.in_range := by
  intro x lo hi h
  simp only [ordered, decide_eq_true_eq] at h
  simp only [clamp, inRange]
  split <;> (try split) <;> simp_all <;> omega

end LeanPhpModel.App.Calc
