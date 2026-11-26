import LeanCModel.grade

namespace LeanCModel.grade

private theorem ofNat64 (n : Nat) (h : n < 2 ^ 64) : (C.IntType.ofInt (n : Int) : UInt64).toNat = n := by
  simp [C.IntType.ofInt, UInt64.ofInt, UInt64.toNat_ofNat']
  omega

theorem level_of.proof.refines : level_of.obligation.refines := by
  intro x
  simp only [level_of, levelOf, Id.run]
  split <;> (try split) <;> rfl

theorem first_or.proof.refines : first_or.obligation.refines := by
  intro xs d h
  by_cases hn : xs.size = 0
  · have : xs = #[] := Array.eq_empty_of_size_eq_zero hn
    subst this
    rfl
  · have hz : ¬(C.IntType.ofInt (xs.size : Int) : UInt64) = 0 := fun e => by
      have := congrArg UInt64.toNat e
      rw [ofNat64 _ h] at this
      exact hn this
    have hp : 0 < xs.size := by omega
    simp [first_or, firstOr, hz, C.index, C.IntType.toInt, Array.getD, hp]

theorem first_level.proof.refines : first_level.obligation.refines := by
  intro xs h
  simp only [first_level, firstLevel, first_or.proof.refines xs 0 h, firstOr]
  show Except.ok (level_of _) = _
  rw [level_of.proof.refines]

theorem level_at.proof.refines : level_at.obligation.refines := by
  intro xs i h
  have hi := UInt32.toNat_lt i
  simp only [level_at, levelAt, C.cast, C.IntType.toInt, Int.ofNat_eq_natCast, UInt64.le_iff_toNat_le,
    ge_iff_le, ofNat64 _ h, ofNat64 _ (show i.toNat < 2 ^ 64 by omega)]
  by_cases hs : i.toNat < xs.size
  · simp only [hs, Nat.not_le.mpr hs, C.index, dite_true, ite_false,
      show ¬((i.toNat : Int) < 0) by omega, Int.toNat_natCast, Array.getElem?_eq_getElem hs]
    rfl
  · simp [hs, Nat.le_of_not_lt hs]
    rfl

theorem level_at_or.proof.refines : level_at_or.obligation.refines := by
  intro xs i h
  simp only [level_at_or, levelAtOr, level_at.proof.refines xs i h, levelAt]
  by_cases hs : i.toNat < xs.size <;> simp [hs] <;> rfl

theorem first_at.proof.refines : first_at.obligation.refines := by
  intro xs h
  by_cases hn : xs.size = 0
  · have : xs = #[] := Array.eq_empty_of_size_eq_zero hn
    subst this
    rfl
  · have hz : ¬(C.IntType.ofInt (xs.size : Int) : UInt64) = 0 := fun e => by
      have := congrArg UInt64.toNat e
      rw [ofNat64 _ h] at this
      exact hn this
    have hp : 0 < xs.size := by omega
    simp [first_at, firstAt, hz, C.index, C.IntType.toInt, hp]
    rfl

theorem first_pos.proof.refines : first_pos.obligation.refines := by
  intro xs h
  by_cases hn : xs.size = 0
  · have : xs = #[] := Array.eq_empty_of_size_eq_zero hn
    subst this
    rfl
  · have hz : ¬(C.IntType.ofInt (xs.size : Int) : UInt64) = 0 := fun e => by
      have := congrArg UInt64.toNat e
      rw [ofNat64 _ h] at this
      exact hn this
    have hp : 0 < xs.size := by omega
    simp [first_pos, posAt, hz, C.index, C.IntType.toInt, hp]
    by_cases hx : (0 : Int32) < xs[0] <;> simp [hx, bind, Except.bind, pure, Except.pure]

theorem byte_one.proof.refines : byte_one.obligation.refines := by
  intro bs h
  rfl

theorem sign_one.proof.refines : sign_one.obligation.refines := by
  intro xs h
  rfl

theorem low_level.proof.refines : low_level.obligation.refines := by
  intro xs h
  rfl

theorem level_one.proof.refines : level_one.obligation.refines := by
  intro ls h
  rfl

end LeanCModel.grade
