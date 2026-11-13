# 02-theorems

Theorems sit next to the definitions in the `lean!` block, and the build checks them: a
proof that does not hold stops `cargo build` with Lean's error.

```lean
def sumTo : Nat → Nat
  | 0 => 0
  | n + 1 => sumTo n + (n + 1)

theorem sumTo_closed (n : Nat) : 2 * sumTo n = n * (n + 1) := by
  induction n with
  | zero => rfl
  | succ n ih => simp only [sumTo]; grind
```

Theorems do not appear in Rust: only `sums::sum_to` does, and it runs the definition as written.

Next: [03-structures](../03-structures).
