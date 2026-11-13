import LeanRustGen.Obligation.generic_search.search
open Aeneas Aeneas.Std Result LeanRust

namespace generic_search.search

theorem max_of.proof.max : max_of.obligation.max := by
  intro T _ ord _ copy a b
  unfold max_of
  step*
  · simp_all [_root_.search.is_max]
  · simp_all [_root_.search.is_max]
    exact le_of_lt (by simpa using ‹_›)

/-- The loop `'halve` keeps `lo ≤ hi ≤ len`, the elements below `lo` less than `x` and those
    from `hi` on not less than `x`. -/
theorem halve_spec {T : Type} [LinearOrder T] (ord : core.cmp.Ord T) [OrdModel ord]
    (xs : Slice T) (x : T) (lo hi : Std.Usize)
    (hs : xs.val.Pairwise (· ≤ ·))
    (hlo : lo.val ≤ hi.val) (hhi : hi.val ≤ xs.val.length)
    (hl : ∀ j (hj : j < xs.val.length), j < lo.val → xs.val[j] < x)
    (hr : ∀ j (hj : j < xs.val.length), hi.val ≤ j → x ≤ xs.val[j]) :
    contains.halve ord xs x lo hi ⦃ r =>
      r.val ≤ xs.val.length ∧
      (∀ j (hj : j < xs.val.length), j < r.val → xs.val[j] < x) ∧
      (∀ j (hj : j < xs.val.length), r.val ≤ j → x ≤ xs.val[j]) ⦄ := by
  unfold contains.halve
  rw [contains_loop]
  split
  · rename_i hlt
    step as ⟨d, hd⟩
    step as ⟨h2, hh2⟩
    step as ⟨mid, hmid⟩
    step as ⟨y, hy⟩
    step as ⟨b, hb⟩
    split
    · rename_i hyx
      step as ⟨lo1, hlo1⟩
      have ih := halve_spec ord xs x lo1 hi hs (by scalar_tac) hhi (by
        intro j hj hjl
        have hyx' : y < x := by simpa [hb] using hyx
        by_cases hjm : j = mid.val
        · simp only [hjm, ← hy]
          exact hyx'
        · exact lt_of_le_of_lt
            (List.pairwise_iff_getElem.mp hs j mid.val hj (by scalar_tac) (by scalar_tac)) (hy ▸ hyx')) hr
      unfold contains.halve at ih
      exact ih
    · rename_i hyx
      have ih := halve_spec ord xs x lo mid hs (by scalar_tac) (by scalar_tac) hl (by
        intro j hj hmj
        have hyx' : x ≤ y := by simpa [hb] using hyx
        by_cases hjm : j = mid.val
        · simp only [hjm, ← hy]
          exact hyx'
        · exact le_trans (hy ▸ hyx')
            (List.pairwise_iff_getElem.mp hs mid.val j (by scalar_tac) hj (by omega)))
      unfold contains.halve at ih
      exact ih
  · rename_i hge
    simp only [WP.spec_ok]
    exact ⟨by scalar_tac, hl, fun j hj hj' => hr j hj (by scalar_tac)⟩
termination_by hi.val - lo.val
decreasing_by all_goals scalar_tac

theorem contains.proof.refines : contains.obligation.refines := by
  intro T _ ord _ xs x h
  simp only [_root_.search.sorted, decide_eq_true_eq] at h
  apply eq_ok_of_spec
  unfold contains
  step with halve_spec ord xs x 0#usize (Slice.len xs) h (by simp) (by simp) (by simp)
    (fun j hj hj' => by simp at hj'; omega) as ⟨i, hlen, hl, hr⟩
  split
  · rename_i hi
    step as ⟨y, hy⟩
    step as ⟨b, hb⟩
    have hi' : i.val < xs.val.length := by scalar_tac
    rw [hb, hy, _root_.search.mem]
    apply decide_eq_decide.mpr
    constructor
    · intro he
      rw [← he]
      exact List.getElem_mem hi'
    · intro hm
      obtain ⟨j, hj, hjx⟩ := List.getElem_of_mem hm
      by_cases hji : j < i.val
      · exact absurd hjx (ne_of_lt (hl j hj hji))
      · have h2 : xs.val[i.val] ≤ xs.val[j] := by
          by_cases hij : i.val = j
          · simp [hij]
          · exact List.pairwise_iff_getElem.mp h _ _ hi' hj (by omega)
        exact le_antisymm (hjx ▸ h2) (hr i.val hi' le_rfl)
  · rename_i hi
    simp only [WP.spec_ok, _root_.search.mem]
    symm
    simp only [decide_eq_false_iff_not]
    intro hm
    obtain ⟨j, hj, hjx⟩ := List.getElem_of_mem hm
    exact absurd hjx (ne_of_lt (hl j hj (by scalar_tac)))

end generic_search.search
