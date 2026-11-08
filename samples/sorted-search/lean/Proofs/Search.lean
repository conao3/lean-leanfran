import LeanRustGen.Obligation.sorted_search.search
open Aeneas Aeneas.Std Result

namespace sorted_search.search

theorem eq_ok_of_spec {α : Type} {m : Result α} {v : α} (h : m ⦃ r => r = v ⦄) : m = ok v := by
  cases m with
  | ret r => simp_all [WP.spec_ok]
  | vis i k => simp [WP.spec_vis] at h
  | div => simp [WP.spec_div] at h

/-- Below `k`, the elements are less than `x`; from `k` on, they are not. -/
theorem countP_split (l : List Std.I64) (x : Std.I64) (k : Nat) (hk : k ≤ l.length)
    (hl : ∀ j (hj : j < l.length), j < k → l[j].val < x.val)
    (hr : ∀ j (hj : j < l.length), k ≤ j → x.val ≤ l[j].val) :
    l.countP (fun y => decide (y.val < x.val)) = k := by
  rw [← List.take_append_drop k l, List.countP_append]
  have h1 : (l.take k).countP (fun y => decide (y.val < x.val)) = k := by
    rw [List.countP_eq_length.mpr]
    · simp; omega
    intro a ha
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem ha
    simp only [List.length_take] at hi
    simp only [List.getElem_take, decide_eq_true_eq]
    exact hl i (by omega) (by omega)
  have h2 : (l.drop k).countP (fun y => decide (y.val < x.val)) = 0 := by
    rw [List.countP_eq_zero]
    intro a ha
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem ha
    simp only [List.length_drop] at hi
    simp only [List.getElem_drop, decide_eq_true_eq, not_lt]
    exact hr (k + i) (by omega) (by omega)
  omega

theorem halve_spec (xs : Slice Std.I64) (x : Std.I64) (lo hi : Std.Usize)
    (hs : xs.val.Pairwise (fun a b => a.val ≤ b.val))
    (hlo : lo.val ≤ hi.val) (hhi : hi.val ≤ xs.val.length)
    (hl : ∀ j (hj : j < xs.val.length), j < lo.val → xs.val[j].val < x.val)
    (hr : ∀ j (hj : j < xs.val.length), hi.val ≤ j → x.val ≤ xs.val[j].val) :
    lower_bound.halve xs x lo hi ⦃ r =>
      r.val = xs.val.countP (fun y => decide (y.val < x.val)) ∧ r.val ≤ xs.val.length ∧
      (∀ j (hj : j < xs.val.length), j < r.val → xs.val[j].val < x.val) ∧
      (∀ j (hj : j < xs.val.length), r.val ≤ j → x.val ≤ xs.val[j].val) ⦄ := by
  unfold lower_bound.halve
  rw [lower_bound_loop]
  split
  · rename_i hlt
    step as ⟨d, hd⟩
    step as ⟨h2, hh2⟩
    step as ⟨mid, hmid⟩
    step as ⟨y, hy⟩
    split
    · rename_i hyx
      step as ⟨lo1, hlo1⟩
      have ih := halve_spec xs x lo1 hi hs (by scalar_tac) hhi (by
        intro j hj hjl
        by_cases hjm : j = mid.val
        · subst hjm; simp_all [IScalar.lt_equiv]
        · have := List.pairwise_iff_getElem.mp hs j mid.val hj (by scalar_tac) (by scalar_tac)
          simp_all [IScalar.lt_equiv]; omega) hr
      unfold lower_bound.halve at ih
      exact ih
    · rename_i hyx
      have ih := halve_spec xs x lo mid hs (by scalar_tac) (by scalar_tac) hl (by
        intro j hj hjm
        by_cases hjm' : j = mid.val
        · subst hjm'; simp_all [IScalar.lt_equiv]
        · have := List.pairwise_iff_getElem.mp hs mid.val j (by scalar_tac) hj (by omega)
          simp_all [IScalar.lt_equiv]; omega)
      unfold lower_bound.halve at ih
      exact ih
  · rename_i hge
    simp only [WP.spec_ok]
    refine ⟨?_, by scalar_tac, hl, fun j hj hj' => hr j hj (by scalar_tac)⟩
    rw [countP_split xs.val x lo.val (by scalar_tac) hl (fun j hj hj' => hr j hj (by scalar_tac))]
termination_by hi.val - lo.val
decreasing_by all_goals scalar_tac

theorem lower_bound_spec (xs : Slice Std.I64) (x : Std.I64)
    (hs : xs.val.Pairwise (fun a b => a.val ≤ b.val)) :
    lower_bound xs x ⦃ r =>
      r.val = xs.val.countP (fun y => decide (y.val < x.val)) ∧ r.val ≤ xs.val.length ∧
      (∀ j (hj : j < xs.val.length), j < r.val → xs.val[j].val < x.val) ∧
      (∀ j (hj : j < xs.val.length), r.val ≤ j → x.val ≤ xs.val[j].val) ⦄ := by
  unfold lower_bound
  exact halve_spec xs x 0#usize (Slice.len xs) hs (by simp) (by simp) (by simp)
    (fun j hj hj' => by simp at hj'; omega)

theorem lower_bound.proof.refines : lower_bound.obligation.refines := by
  intro xs x h
  simp [_root_.search.sorted] at h
  apply eq_ok_of_spec
  refine WP.spec_mono (lower_bound_spec xs x h) ?_
  intro r ⟨hr, _⟩
  obtain ⟨bv⟩ := r
  simp only [_root_.search.lower_bound, UScalar.val] at hr ⊢
  rw [← hr, BitVec.ofNat_toNat, BitVec.setWidth_eq]

theorem contains.proof.refines : contains.obligation.refines := by
  intro xs x h
  simp [_root_.search.sorted] at h
  apply eq_ok_of_spec
  unfold contains
  step with lower_bound_spec xs x h as ⟨i, hc, hlen, hl, hr⟩
  split
  · rename_i hi
    have hi' : i.val < xs.val.length := by scalar_tac
    step as ⟨y, hy⟩
    simp only [_root_.search.mem, hy]
    apply Bool.eq_iff_iff.mpr
    simp only [decide_eq_true_eq, List.any_eq_true, beq_iff_eq]
    constructor
    · intro he
      exact ⟨_, List.getElem_mem hi', he⟩
    · rintro ⟨a, ha, rfl⟩
      obtain ⟨j, hj, rfl⟩ := List.getElem_of_mem ha
      by_cases hji : j < i.val
      · have := hl j hj hji
        omega
      · have h1 := hr i.val hi' le_rfl
        have h2 : xs.val[i.val].val ≤ xs.val[j].val := by
          by_cases hij : i.val = j
          · simp [hij]
          · exact List.pairwise_iff_getElem.mp h _ _ hi' hj (by omega)
        exact IScalar.eq_of_val_eq (by omega)
  · rename_i hi
    have hi' : i.val = xs.val.length := by scalar_tac
    simp only [WP.spec_ok, _root_.search.mem]
    symm
    simp only [List.any_eq_false, beq_iff_eq]
    intro a ha he
    obtain ⟨j, hj, rfl⟩ := List.getElem_of_mem ha
    have := hl j hj (by omega)
    simp_all

end sorted_search.search
