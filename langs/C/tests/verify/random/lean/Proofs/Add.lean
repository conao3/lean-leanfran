import LeanCModel.random

namespace LeanCModel.random

theorem add.proof.refines : add.obligation.refines := by
  intro a b h
  simp only [small, Bool.and_eq_true, decide_eq_true_eq, Int32.lt_iff_toInt_lt] at h
  have e1 : (-1000 : Int32).toInt = -1000 := by decide
  have e2 : (1000 : Int32).toInt = 1000 := by decide
  rw [e1, e2] at h
  simp only [add, addSpec, C.addS, C.checked, C.bounds]
  simp only [C.IntType.toInt, C.IntType.signed, C.IntType.width, C.IntType.ofInt, ite_true]
  rw [ite_eq_left_of_eq_true _ _ (eq_true (by omega))]
  congr 1
  apply Int32.toInt_inj.mp
  rw [Int32.toInt_ofInt, Int32.toInt_add]

end LeanCModel.random
