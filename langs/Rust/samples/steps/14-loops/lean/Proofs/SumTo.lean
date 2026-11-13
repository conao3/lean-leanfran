import LeanRustGen.Obligation.step_14_loops
open Aeneas Aeneas.Std Result

namespace step_14_loops

theorem tri_succ (k : Nat) : k * (k + 1) / 2 + (k + 1) = (k + 1) * (k + 1 + 1) / 2 := by
  have : (k + 1) * (k + 1 + 1) = k * (k + 1) + 2 * (k + 1) := by ring
  rw [this, Nat.add_mul_div_left _ _ (by decide)]

theorem tri_bound (k : Nat) (h : k ≤ 4294967295) : k * (k + 1) / 2 + (k + 1) < 2 ^ 64 := by
  have : k * (k + 1) ≤ 4294967295 * 4294967296 := Nat.mul_le_mul h (by omega)
  omega

/-- The loop `'add` with `i` numbers added: it returns the sum up to `n`. -/
theorem add_spec (n i : Std.U32) (s : Std.U64) (hi : i.val ≤ n.val)
    (hs : s.val = i.val * (i.val + 1) / 2) :
    sum_to.add n i s ⦃ r => r.val = n.val * (n.val + 1) / 2 ⦄ := by
  unfold sum_to.add
  rw [sum_to_loop]
  split
  · step as ⟨i1, hi1⟩
    step as ⟨i2, hi2⟩
    have h2 : i2.val = i.val + 1 := by scalar_tac
    have hb := tri_bound i.val (by scalar_tac)
    step as ⟨s1, hs1⟩
    have ih := add_spec n i1 s1 (by scalar_tac) (by rw [hs1, hs, h2, hi1]; exact tri_succ _)
    unfold sum_to.add at ih
    exact ih
  · have : i.val = n.val := by scalar_tac
    simp [WP.spec_ok, hs, this]
termination_by n.val - i.val
decreasing_by scalar_tac

theorem eq_ok_of_spec {α : Type} {m : Result α} {v : α} (h : m ⦃ r => r = v ⦄) : m = ok v := by
  cases m with
  | ret r => simp_all [WP.spec_ok]
  | vis i k => simp [WP.spec_vis] at h
  | div => simp [WP.spec_div] at h

theorem sum_to.proof.refines : sum_to.obligation.refines := by
  intro n
  apply eq_ok_of_spec
  unfold sum_to
  refine WP.spec_mono (add_spec n 0#u32 0#u64 (by simp) (by simp)) ?_
  intro r hr
  apply UScalar.eq_of_val_eq
  have hb : n.val * (n.val + 1) / 2 < 2 ^ 64 := by
    have := tri_bound n.val (by scalar_tac)
    omega
  simp only [_root_.sums.sum_to, UScalar.val] at hr ⊢
  rw [hr]
  simp
  exact (Nat.mod_eq_of_lt hb).symm

end step_14_loops
