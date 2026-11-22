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
  let subtotal := prices.foldl (· + ·) 0
  match discount with
  | .none => subtotal
  | .percent p _ => subtotal - subtotal * p / 100
  | .fixed amount => subtotal - amount

end Pricing
