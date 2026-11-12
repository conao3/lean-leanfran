import LeanRustGen.Obligation.step_15_structs_enums
open Aeneas Aeneas.Std Result

namespace step_15_structs_enums

theorem eq_ok_of_spec {α : Type} {m : Result α} {v : α} (h : m ⦃ r => r = v ⦄) : m = ok v := by
  cases m with
  | ret r => simp_all [WP.spec_ok]
  | vis i k => simp [WP.spec_vis] at h
  | div => simp [WP.spec_div] at h

theorem apply.proof.refines : apply.obligation.refines := by
  intro c a h
  simp [_root_.counter.within] at h
  apply eq_ok_of_spec
  unfold apply _root_.counter.apply
  cases a with
  | Reset => step*
  | Add n =>
    step as ⟨i, hi⟩
    split
    · have : c.max.val - c.count.val ≤ n.val := by scalar_tac
      simp [WP.spec_ok, this]
    · step as ⟨count, hcount⟩
      have hlt : ¬ (c.max.val - c.count.val ≤ n.val) := by scalar_tac
      have hb : c.count.val + n.val < 2 ^ 32 := by scalar_tac
      simp only [hlt, ite_false, Counter.mk.injEq, and_true]
      apply UScalar.eq_of_val_eq
      rw [hcount]
      simp only [UScalar.val]
      simp [BitVec.toNat_add]
      exact (Nat.mod_eq_of_lt hb).symm

end step_15_structs_enums
