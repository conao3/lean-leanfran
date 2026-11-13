import LeanRustGen.Obligation.verified_rust.sort
import Mathlib.Data.List.Sort
open Aeneas Aeneas.Std Result

namespace verified_rust.sort

theorem next_eq {T : Type} (it : core.slice.iter.Iter T) :
    core.slice.iter.IteratorSliceIter.next it =
      match it.slice.val.drop it.i with
      | [] => ok (none, it)
      | y :: _ => ok (some y, { it with i := it.i + 1 }) := by
  unfold core.slice.iter.IteratorSliceIter.next
  split
  · rename_i h
    have h' : it.i < it.slice.val.length := by scalar_tac
    rw [List.drop_eq_getElem_cons h']
    simp only [ok.injEq, Prod.mk.injEq, Option.some.injEq, and_true]
    exact Slice.getElem_Nat_eq _ _ h'
  · rename_i h
    have h' : it.slice.val.length ≤ it.i := by scalar_tac
    simp [List.drop_eq_nil_of_le h']

/-- What the loop `'scan` appends to `out` for the remaining elements, and whether `x` is placed. -/
def scanF (x : Std.I64) : List Std.I64 → Bool → List Std.I64 × Bool
  | [], p => ([], p)
  | y :: ys, p =>
    if !p && x.val ≤ y.val then
      let r := scanF x ys true
      (x :: y :: r.1, r.2)
    else
      let r := scanF x ys p
      (y :: r.1, r.2)

theorem scan_spec (iter : core.slice.iter.Iter Std.I64) (x : Std.I64)
    (out : alloc.vec.Vec Std.I64) (placed : Bool)
    (hb : out.val.length + (iter.slice.val.length - iter.i) + (if placed then 0 else 1) ≤ Usize.max) :
    insert_sorted.scan iter x out placed ⦃ r =>
      r.1.val = out.val ++ (scanF x (iter.slice.val.drop iter.i) placed).1 ∧
      r.2 = (scanF x (iter.slice.val.drop iter.i) placed).2 ⦄ := by
  unfold insert_sorted.scan
  rw [insert_sorted_loop, next_eq]
  cases hd : List.drop iter.i iter.slice.val with
  | nil => simp [scanF, WP.spec_ok]
  | cons y ys =>
    have hlen : iter.i < iter.slice.val.length := by
      by_contra hc
      simp [List.drop_eq_nil_of_le (by omega : iter.slice.val.length ≤ iter.i)] at hd
    have hys : List.drop (iter.i + 1) iter.slice.val = ys := by
      rw [← List.tail_drop, hd]; rfl
    have hlys : ys.length = iter.slice.val.length - (iter.i + 1) := by
      rw [← hys, List.length_drop]
    cases placed <;> by_cases hx : x.val ≤ y.val <;> simp [scanF, hx, IScalar.le_equiv] at hb ⊢
    · step as ⟨o1, h1⟩
      have : o1.val.length < Usize.max := by simp [h1]; omega
      step as ⟨o2, h2⟩
      have ih := scan_spec ⟨iter.slice, iter.i + 1⟩ x o2 true (by simp [h1, h2]; omega)
      unfold insert_sorted.scan at ih
      refine WP.spec_mono ih ?_
      simp_all
    all_goals
      step as ⟨o1, h1⟩
      first
      | have ih := scan_spec ⟨iter.slice, iter.i + 1⟩ x o1 false (by simp [h1]; omega)
        unfold insert_sorted.scan at ih
        refine WP.spec_mono ih ?_
        simp_all
      | have ih := scan_spec ⟨iter.slice, iter.i + 1⟩ x o1 true (by simp [h1]; omega)
        unfold insert_sorted.scan at ih
        refine WP.spec_mono ih ?_
        simp_all
termination_by iter.slice.val.length - iter.i

theorem scanF_true (x : Std.I64) (ys : List Std.I64) : scanF x ys true = (ys, true) := by
  induction ys with
  | nil => rfl
  | cons y ys ih => simp [scanF, ih]

/-- The order `insert_sorted` sorts by. -/
abbrev le (a b : Std.I64) : Prop := a.val ≤ b.val

theorem scanF_insert (x : Std.I64) (xs : List Std.I64) :
    (let r := scanF x xs false; if r.2 then r.1 else r.1 ++ [x]) = xs.orderedInsert le x := by
  induction xs with
  | nil => rfl
  | cons y ys ih =>
    by_cases h : x.val ≤ y.val
    · simp [scanF, h, scanF_true]
    · simp only [scanF, h] at ih ⊢
      simp [List.orderedInsert_cons, h]
      split <;> simp_all

theorem insert_sorted_spec (x : Std.I64) (xs : Slice Std.I64) (h : xs.val.length < Usize.max) :
    insert_sorted x xs ⦃ out => out.val = xs.val.orderedInsert le x ⦄ := by
  unfold insert_sorted
  step as ⟨i1, h1⟩
  step as ⟨iter, h2, h3⟩
  have hs := scan_spec iter x (alloc.vec.Vec.with_capacity Std.I64 i1) false
    (by simp [alloc.vec.Vec.with_capacity, h2, h3]; omega)
  unfold insert_sorted.scan at hs
  step with hs as ⟨r, hr1, hr2⟩
  rename_i hp
  have key := scanF_insert x xs.val
  simp only [h2, h3, List.drop_zero, alloc.vec.Vec.with_capacity, alloc.vec.Vec.new, alloc.vec.Vec.from_val,
    List.nil_append] at hr2 hp
  have hlen := List.orderedInsert_length le xs.val x
  split
  · rename_i hc
    simp only [hc, ← hp, ↓reduceIte] at key
    simp [WP.spec_ok, hr2, key]
  · rename_i hc
    simp only [hc, ← hp, Bool.false_eq_true, ↓reduceIte] at key
    have : r.val.length < Usize.max := by
      rw [hr2]; rw [← key] at hlen; simp at hlen; omega
    step as ⟨o, ho⟩
    simp [ho, hr2, key]

instance : Std.Total le := ⟨fun a b => le_total a.val b.val⟩

instance : IsTrans Std.I64 le := ⟨fun _ _ _ => le_trans⟩

theorem insert_sorted.proof.sorted : insert_sorted.obligation.sorted := by
  intro x xs h
  simp [_root_.sorting.input_sorted, _root_.sorting.sorted] at h
  refine WP.spec_mono (insert_sorted_spec x xs h.1) ?_
  intro out hout
  simp only [_root_.sorting.output_sorted, _root_.sorting.sorted, hout, decide_eq_true_eq]
  exact List.Pairwise.orderedInsert x _ h.2

theorem insert_sorted.proof.perm : insert_sorted.obligation.perm := by
  intro x xs h
  simp [_root_.sorting.input_sorted] at h
  refine WP.spec_mono (insert_sorted_spec x xs h.1) ?_
  intro out hout
  simp only [_root_.sorting.OutputPerm, hout]
  exact List.perm_orderedInsert le x xs.val

end verified_rust.sort
