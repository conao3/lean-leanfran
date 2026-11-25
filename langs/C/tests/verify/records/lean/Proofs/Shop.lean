import LeanCModel.shop

namespace LeanCModel.shop

private theorem bmod64 (n : Int) (h1 : -2 ^ 63 ≤ n) (h2 : n < 2 ^ 63) : n.bmod Int64.size = n :=
  Int.bmod_eq_of_le (by simp [Int64.size]; omega) (by simp [Int64.size]; omega)

theorem point_sum.proof.refines : point_sum.obligation.refines := by
  intro p
  have hx1 := Int32.le_toInt p.x
  have hx2 := Int32.toInt_lt p.x
  have hy1 := Int32.le_toInt p.y
  have hy2 := Int32.toInt_lt p.y
  simp only [point_sum, sumSpec, C.addS, C.checked, C.bounds, C.cast, C.IntType.toInt,
    C.IntType.signed, C.IntType.width, C.IntType.ofInt, ite_true, Int64.toInt_ofInt]
  rw [bmod64 _ (by omega) (by omega), bmod64 _ (by omega) (by omega)]
  rw [ite_eq_left_of_eq_true _ _ (eq_true (by omega))]
  congr 1
  apply Int64.toInt_inj.mp
  rw [Int64.toInt_ofInt, Int64.toInt_add, Int32.toInt_toInt64, Int32.toInt_toInt64]

theorem line_total.proof.refines : line_total.obligation.refines := by
  intro o
  have hq1 := o.qty_ge
  have hq2 := o.qty_le
  have hp1 := o.price_ge
  have hp2 := o.price_le
  have hp3 := Int64.toInt_lt o.price
  simp only [line_total, lineSpec, C.mulS, C.checked, C.bounds, C.cast, C.IntType.toInt,
    C.IntType.signed, C.IntType.width, C.IntType.ofInt, ite_true, Int64.toInt_ofInt]
  have hq : (Int.ofNat o.qty.toNat).bmod Int64.size = Int.ofNat o.qty.toNat :=
    bmod64 _ (by omega) (by omega)
  rw [hq]
  generalize hv : o.price.toInt * Int.ofNat o.qty.toNat = v
  have hm : v ≤ 1000000 * 1000 := hv ▸ Int.mul_le_mul hp2 hq2 (by omega) (by omega)
  have hm0 : 0 ≤ v := hv ▸ Int.mul_nonneg hp1 (by omega)
  have hc : (-2 ^ (64 - 1) ≤ v ∧ v < 2 ^ (64 - 1)) = True := eq_true (by omega)
  rw [ite_eq_left_of_eq_true _ _ hc]
  apply congrArg Except.ok
  apply Int64.toInt_inj.mp
  rw [Int64.toInt_mul, Int64.toInt_ofInt, Int64.toInt_ofInt]
  exact (congrArg (Int.bmod · Int64.size) (hq.symm ▸ hv).symm)

theorem size_weight.proof.refines : size_weight.obligation.refines := by
  intro s
  cases s <;> rfl

theorem parcel_size.proof.refines : parcel_size.obligation.refines := by
  intro p
  cases p <;> rfl

end LeanCModel.shop
