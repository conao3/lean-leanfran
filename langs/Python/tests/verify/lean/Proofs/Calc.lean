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

theorem foldl_abs_nonneg (xs : List Int) (init : Int) (h : 0 ≤ init) :
    0 ≤ xs.foldl (fun acc x => acc + Py.abs x) init := by
  induction xs generalizing init with
  | nil => simpa
  | cons x xs ih =>
    apply ih
    show 0 ≤ init + Py.abs x
    unfold Py.abs; split <;> omega

/-- The `for` loop is a `List.foldl` (`simp` rewrites it with `forIn_pure_yield_eq_foldl`). -/
theorem sum_abs.proof.nonneg : sum_abs.obligation.nonneg := by
  intro xs
  simp [LeanPythonEmbed.calc.spec.spec.nonneg, sum_abs]
  exact foldl_abs_nonneg xs 0 (Int.le_refl 0)

end LeanPythonModel.«calc».«calc»
