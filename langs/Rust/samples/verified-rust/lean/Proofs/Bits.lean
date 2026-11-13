import LeanRustGen.Obligation.verified_rust.bits
open Aeneas Aeneas.Std Result

namespace verified_rust.bits

theorem max_u32.proof.refines : max_u32.obligation.refines := by
  intro a b
  unfold max_u32 _root_.bits.max
  by_cases h : a.val ≤ b.val <;> simp [UScalar.le_equiv, h]

theorem max_u32.proof.bound : max_u32.obligation.bound := by
  intro a b
  unfold max_u32 _root_.bits.max_bound
  by_cases h : a.val ≤ b.val
  · simp [UScalar.le_equiv, h]
  · simp [UScalar.le_equiv, h]
    omega
/-- The number of one bits among the `n` lowest bits of `v`. -/
def pc (n v : Nat) : Nat := (List.range n).countP fun i => v.testBit i

theorem pc_succ (n v : Nat) : pc (n + 1) v = (if v.testBit 0 then 1 else 0) + pc n (v / 2) := by
  unfold pc
  rw [List.range_succ_eq_map, List.countP_cons, List.countP_map]
  simp [Function.comp_def, Nat.testBit_succ]
  omega

theorem pc_clear (n v : Nat) (h0 : v ≠ 0) (hv : v < 2 ^ n) :
    pc n (v &&& (v - 1)) + 1 = pc n v := by
  induction n generalizing v with
  | zero => simp at hv; omega
  | succ n ih =>
    rw [pc_succ, pc_succ]
    rcases Nat.even_or_odd v with ⟨k, hk⟩ | ⟨k, hk⟩
    · have hk0 : k ≠ 0 := by omega
      have h1 : (v &&& (v - 1)) / 2 = k &&& (k - 1) := by
        rw [Nat.and_div_two]; congr 1 <;> omega
      have h2 : (v &&& (v - 1)).testBit 0 = false := by
        simp; omega
      have := ih k hk0 (by rw [Nat.pow_succ] at hv; omega)
      have h3 : v.testBit 0 = false := by simp; omega
      rw [h1, h2, h3, show v / 2 = k by omega]
      simp; omega
    · have h1 : (v &&& (v - 1)) / 2 = k := by
        rw [Nat.and_div_two, show v / 2 = k by omega, show (v - 1) / 2 = k by omega, Nat.and_self]
      have h2 : (v &&& (v - 1)).testBit 0 = false := by
        simp; omega
      have h3 : v.testBit 0 = true := by simp; omega
      rw [h1, h2, h3, show v / 2 = k by omega]
      simp; omega

theorem pc_zero (n : Nat) : pc n 0 = 0 := by simp [pc]

theorem clear_spec (x : Std.U64) (n : Std.U32) (hb : n.val + pc 64 x.val ≤ 64) :
    popcount_fast.clear x n ⦃ r => r.val = n.val + pc 64 x.val ⦄ := by
  unfold popcount_fast.clear
  rw [popcount_fast_loop]
  split
  · rename_i hx
    have hx0 : x.val ≠ 0 := by
      intro h; apply absurd hx; simp [UScalar.eq_equiv, h]
    have hxb : x.val < 2 ^ 64 := by scalar_tac
    have hpc := pc_clear 64 x.val hx0 hxb
    step as ⟨i, hi⟩
    step as ⟨x1, hx1, hbv⟩
    have hv : x1.val = x.val &&& (x.val - 1) := by
      rw [← hi]; simp only [UScalar.val, hbv, BitVec.toNat_and]
    have hlt : x1.val < x.val := by
      rw [hv]; have := Nat.and_le_right (n := x.val) (m := x.val - 1); omega
    step as ⟨n1, hn1⟩
    have ih := clear_spec x1 n1 (by rw [hv, hn1]; omega)
    unfold popcount_fast.clear at ih
    refine WP.spec_mono ih ?_
    intro r hr
    rw [hr, hn1, hv]; omega
  · rename_i hx
    have hx0 : x.val = 0 := by simpa [UScalar.eq_equiv] using hx
    simp [WP.spec_ok, hx0, pc_zero]
termination_by x.val

theorem eq_ok_of_spec {α : Type} {m : Result α} {v : α} (h : m ⦃ r => r = v ⦄) : m = ok v := by
  cases m with
  | ret r => simp_all [WP.spec_ok]
  | vis i k => simp [WP.spec_vis] at h
  | div => simp [WP.spec_div] at h

theorem popcount_fast.proof.refines : popcount_fast.obligation.refines := by
  intro x
  apply eq_ok_of_spec
  unfold popcount_fast
  have hle : pc 64 x.val ≤ 64 := by
    unfold pc; have := List.countP_le_length (p := fun i => x.val.testBit i) (l := List.range 64)
    simpa using this
  refine WP.spec_mono (clear_spec x 0#u32 (by simp; omega)) ?_
  intro r hr
  obtain ⟨bv⟩ := r
  simp only [_root_.bits.popcount, UScalar.val, pc] at hr ⊢
  simp at hr
  apply UScalar.eq_of_val_eq
  simp only [UScalar.val]
  unfold pc at hle
  simp only [UScalar.val] at hle
  rw [hr]
  exact (Nat.mod_eq_of_lt (by omega : _ < 2 ^ 32)).symm

end verified_rust.bits
