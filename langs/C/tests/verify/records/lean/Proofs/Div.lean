import LeanCModel.div

namespace LeanCModel.div

theorem safe_div.proof.refines : safe_div.obligation.refines := by
  intro a b h
  by_cases hb : b = 0
  · simp [safe_div, divSpec, hb]
    rfl
  · have hb' : b.toInt ≠ 0 := fun e => hb (Int32.toInt_inj.mp (by simpa using e))
    have hm : ¬(b.toInt = -1 ∧ a.toInt = -2147483648) := by
      intro ⟨e1, e2⟩
      have : b = -1 := Int32.toInt_inj.mp (by simpa using e1)
      have : a = -2147483648 := Int32.toInt_inj.mp (by simpa using e2)
      simp_all [safe]
    simp only [safe_div, divSpec, hb, ite_false, C.div, C.checkDivisor, C.bounds, C.IntType.toInt,
      C.IntType.signed, C.IntType.width, C.IntType.ofInt]
    simp only [hb', ite_false, ite_true]
    split
    · next e => exact absurd (by simpa using e) hm
    · show Except.ok (C.Status.ok, some (Int32.ofInt (a.toInt.tdiv b.toInt))) = _
      have e : Int32.ofInt (a.toInt.tdiv b.toInt) = a / b := by
        apply Int32.toInt_inj.mp
        rw [Int32.toInt_ofInt, Int32.toInt_div]
      rw [e]

end LeanCModel.div
