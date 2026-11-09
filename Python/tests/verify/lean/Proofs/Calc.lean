import LeanPythonModel.calc.calc

open LeanPythonEmbed.calc.spec.spec

namespace LeanPythonModel.«calc».«calc»

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

theorem first_or.proof.refines : first_or.obligation.refines := by
  intro xs d
  cases xs with
  | nil => rfl
  | cons h t =>
    simp [first_or, Py.getItem, Py.len, firstOr]
    rfl

theorem sum_to.proof.refines : sum_to.obligation.refines := by
  sorry

end LeanPythonModel.«calc».«calc»
