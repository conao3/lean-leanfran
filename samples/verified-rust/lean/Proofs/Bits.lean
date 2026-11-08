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

theorem popcount_fast.proof.refines : popcount_fast.obligation.refines := by
  sorry

end verified_rust.bits
