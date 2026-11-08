//! The specs, in the types of Aeneas's model of Rust.

lean_rust::lean! {
    #[lean(imports = ["Aeneas"])]
    pub mod bits;
    r#"
    open Aeneas Aeneas.Std

    def popcount (x : Std.U64) : Std.U32 :=
      ⟨BitVec.ofNat 32 ((List.range 64).countP fun i => x.val.testBit i)⟩

    def max (a b : Std.U32) : Std.U32 := if a.val ≤ b.val then b else a

    def max_bound (a b : Std.U32) (r : Std.U32) : Bool := decide (a.val ≤ r.val ∧ b.val ≤ r.val)
    "#
}

lean_rust::lean! {
    #[lean(imports = ["Aeneas"])]
    pub mod sorting;
    r#"
    open Aeneas Aeneas.Std

    def sorted (xs : List Std.I64) : Bool := decide (xs.Pairwise (·.val ≤ ·.val))

    def input_sorted (_x : Std.I64) (xs : Slice Std.I64) : Bool := sorted xs.val

    def output_sorted (_x : Std.I64) (_xs : Slice Std.I64) (out : alloc.vec.Vec Std.I64) : Bool :=
      sorted out.val

    def OutputPerm (x : Std.I64) (xs : Slice Std.I64) (out : alloc.vec.Vec Std.I64) : Prop :=
      out.val.Perm (x :: xs.val)
    "#
}
