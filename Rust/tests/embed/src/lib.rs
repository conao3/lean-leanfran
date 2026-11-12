//! `lean!` blocks checked by the build script: a proof, `imports`, `uses` and a module file.

pub mod geometry;

lean_rust::lean! {
    /// Doubling, with a proof.
    pub mod arith;
    r#"
    def double (n : Nat) : Nat := n + n

    theorem double_eq (n : Nat) : double n = 2 * n := by
      unfold double; omega

    def sumTo : Nat → Nat
      | 0 => 0
      | n + 1 => (n + 1) + sumTo n

    theorem le_sumTo (n : Nat) : n ≤ sumTo n := by
      induction n with
      | zero => simp only [sumTo]; omega
      | succ k ih => simp only [sumTo]; omega
    "#
}

lean_rust::lean! {
    #[lean(imports = ["Std.Data.HashMap"])]
    pub mod counts;
    r#"
    open Std in
    def tally (words : List String) : List (String × Nat) :=
      let m : HashMap String Nat := words.foldl (fun m w => m.insert w (m.getD w 0 + 1)) {}
      (m.toList.mergeSort (fun a b => a.1 < b.1 || (a.1 == b.1 && a.2 ≤ b.2)))
    "#
}

lean_rust::lean! {
    #[lean(uses = [crate::geometry::shapes, self::arith])]
    pub mod scaled;
    r#"
    def scale (p : Point) (k : Nat) : Point := ⟨p.x * k, p.y * k⟩

    def doubleBoth (p : Point) : Point := ⟨double p.x, double p.y⟩

    theorem doubleBoth_eq (p : Point) : doubleBoth p = scale p 2 := by
      simp [doubleBoth, scale, double_eq, Nat.mul_comm]
    "#
}

lean_rust::lean! {
    /// A polymorphic function instantiated for Rust.
    pub mod generic;
    r#"
    def countOf {α : Type} [BEq α] (xs : List α) (x : α) : Nat := xs.countP (· == x)

    rust_instances countOf [Nat, String]
    "#
}
