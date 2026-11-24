namespace Pricing

structure Range where
  lo : Nat
  hi : Nat
  ok : lo ≤ hi

inductive Discount where
  | none
  | percent (p : Nat) (h : p ≤ 100)
  | fixed (amount : Nat)

def total (prices : List Nat) (discount : Discount) : Nat :=
  let sum := prices.foldl (· + ·) 0
  match discount with
  | .none => sum
  | .percent p _ => sum - sum * p / 100
  | .fixed amount => sum - amount

end Pricing
