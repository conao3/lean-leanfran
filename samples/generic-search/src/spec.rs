//! The specs, polymorphic over a linear order and instantiated for the types of the tests.

lean_rust::lean! {
    #[lean(imports = ["Aeneas", "Mathlib.Data.String.Basic"])]
    pub mod search;
    r#"
    open Aeneas Aeneas.Std

    /-- `r` is one of `a` and `b`, and not less than either. -/
    def is_max {α : Type} [LinearOrder α] (a b r : α) : Bool :=
      decide (a ≤ r ∧ b ≤ r ∧ (r = a ∨ r = b))

    rust_instances is_max [Std.U32, Std.I64]

    /-- The elements are in increasing order. -/
    def sorted {α : Type} [LinearOrder α] (xs : Slice α) (_x : α) : Bool :=
      decide (xs.val.Pairwise (· ≤ ·))

    /-- `x` is an element. -/
    def mem {α : Type} [LinearOrder α] (xs : Slice α) (x : α) : Bool := decide (x ∈ xs.val)

    rust_instances sorted [Std.U32, Std.I64, String]

    rust_instances mem [Std.U32, Std.I64, String]
    "#
}
