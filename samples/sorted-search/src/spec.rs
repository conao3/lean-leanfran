//! The specs.

lean_rust::lean! {
    #[lean(imports = ["Aeneas"])]
    pub mod search;
    r#"
    open Aeneas Aeneas.Std

    /-- The elements are in increasing order. -/
    def sorted (xs : Slice Std.I64) (_x : Std.I64) : Bool := decide (xs.val.Pairwise (·.val ≤ ·.val))

    /-- The number of elements less than `x`: where `x` goes in a sorted slice. -/
    def lower_bound (xs : Slice Std.I64) (x : Std.I64) : Std.Usize :=
      ⟨BitVec.ofNat _ (xs.val.countP (·.val < x.val))⟩

    /-- `x` is an element. -/
    def mem (xs : Slice Std.I64) (x : Std.I64) : Bool := xs.val.any (· == x)
    "#
}
