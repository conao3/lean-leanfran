import LeanGoModel.B6578616d706c652e636f6d2f76657269666965642d6e6962626c65

open LeanGoEmbed.B6578616d706c652e636f6d2f76657269666965642d6e6962626c65
namespace LeanGoModel.B6578616d706c652e636f6d2f76657269666965642d6e6962626c65

theorem Nibble.proof.refines : Nibble.obligation.refines := by
  intro x
  simp only [Nibble, nibbleSpec, Id.run, pure, Pure.pure]
  apply UInt8.toNat_inj.mp
  simpa [UInt8.toNat_and, UInt8.toNat_mod] using Nat.and_two_pow_sub_one_eq_mod x.toNat 4

theorem Nibble.proof.in_range : Nibble.obligation.in_range := by
  intro x
  simp only [Nibble, inRange, Id.run, pure, Pure.pure]
  simp only [UInt8.lt_iff_toNat_lt, UInt8.toNat_and, UInt8.reduceToNat]
  have h := Nat.and_le_right (n := x.toNat) (m := 15)
  exact decide_eq_true (by omega)

end LeanGoModel.B6578616d706c652e636f6d2f76657269666965642d6e6962626c65
