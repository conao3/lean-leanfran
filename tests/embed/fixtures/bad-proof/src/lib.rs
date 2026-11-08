lean_rust::lean! {
    pub mod bad;
    r#"
    def double (n : Nat) : Nat := n + n

    theorem double_eq (n : Nat) : double n = 3 * n := by
      unfold double; omega
    "#
}
