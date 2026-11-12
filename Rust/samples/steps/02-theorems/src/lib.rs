//! Step 2: theorems next to the definitions, checked when the crate is built.

lean_rust::lean! {
    /// The sum of the numbers up to `n`, and its closed form.
    pub mod sums;
    r#"
    def sumTo : Nat → Nat
      | 0 => 0
      | n + 1 => sumTo n + (n + 1)

    theorem sumTo_closed (n : Nat) : 2 * sumTo n = n * (n + 1) := by
      induction n with
      | zero => rfl
      | succ n ih => simp only [sumTo]; grind

    theorem sumTo_mono (n : Nat) : sumTo n ≤ sumTo (n + 1) := by
      simp [sumTo]
    "#
}

#[cfg(test)]
mod tests {
    use super::sums;
    use lean_rust::Nat;

    #[test]
    fn sum_to() {
        assert_eq!(sums::sum_to(100u64.into()), Nat::from(5050u64));
    }
}
