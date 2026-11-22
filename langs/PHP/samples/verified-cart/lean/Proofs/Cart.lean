import LeanPhpModel.App.Cart

open LeanPhpEmbed.App.Cart
namespace LeanPhpModel.App.Cart

private theorem sumBounds (prices : List Int)
    (bounds : ∀ price ∈ prices, 0 ≤ price ∧ price ≤ 1000000) :
    0 ≤ prices.sum ∧ prices.sum ≤ 1000000 * (prices.length : Int) := by
  induction prices with
  | nil => simp
  | cons price rest ih =>
    have hp := bounds price (by simp)
    have hr := ih fun p h => bounds p (by simp [h])
    simp only [List.sum_cons, List.length_cons, Int.natCast_add, Int.cast_ofNat_Int]
    omega

private theorem checkedTotal (prices : List Int) (initial : Int)
    (bounds : ∀ price ∈ prices, 0 ≤ price ∧ price ≤ 1000000)
    (start : 0 ≤ initial)
    (fits : initial + prices.sum ≤ 9223372036854775807) :
    (do
      let mut result := initial
      for price in prices do
        result ← Php.add result price
      pure result : Php.M Int) = .ok (initial + prices.sum) := by
  induction prices generalizing initial with
  | nil =>
    change Except.ok initial = Except.ok (initial + [].sum)
    simp
  | cons price rest ih =>
    have hp := (bounds price (by simp)).1
    have hr : ∀ p ∈ rest, 0 ≤ p ∧ p ≤ 1000000 := fun p h => bounds p (by simp [h])
    have hs := (sumBounds rest hr).1
    simp only [List.sum_cons] at fits
    have checked : Php.add initial price = .ok (initial + price) := by
      simp [Php.add, Php.checked, show -9223372036854775808 ≤ initial + price by omega,
        show initial + price ≤ 9223372036854775807 by omega]
    simp only [List.forIn_cons, checked]
    change (do
      let mut result := initial + price
      for p in rest do
        result ← Php.add result p
      pure result : Php.M Int) = .ok (initial + (price :: rest).sum)
    simpa [List.sum_cons, Int.add_assoc] using ih (initial + price) hr (by omega) (by omega)

theorem total.proof.refines : total.obligation.refines := by
  intro prices h
  simp only [bounded, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at h
  have bounds : ∀ price ∈ prices, 0 ≤ price ∧ price ≤ 1000000 := by
    intro price member
    simpa only [Bool.and_eq_true, decide_eq_true_eq] using h.2 price member
  have upper := (sumBounds prices bounds).2
  have length : (prices.length : Int) ≤ 1000 := Int.ofNat_le.mpr h.1
  simpa [total, totalSpec] using checkedTotal prices 0 bounds (by decide) (by omega)

end LeanPhpModel.App.Cart
