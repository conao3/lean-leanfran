namespace sums

def sumTo : Nat → Nat
  | 0 => 0
  | n + 1 => sumTo n + (n + 1)

theorem sumTo_closed (n : Nat) : 2 * sumTo n = n * (n + 1) := by
  induction n with
  | zero => rfl
  | succ n ih => simp only [sumTo]; grind

theorem sumTo_mono (n : Nat) : sumTo n ≤ sumTo (n + 1) := by
  simp [sumTo]

end sums
