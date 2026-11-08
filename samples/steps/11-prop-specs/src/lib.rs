//! Step 11: a `Prop` spec, named by a string: proved, but not tested.

pub mod spec {
    lean_rust::lean! {
        #[lean(imports = ["Aeneas"])]
        pub mod double;
        r#"
        open Aeneas Aeneas.Std

        /-- The result is `2 * x` cut at the largest `u32`. -/
        def IsSaturatingDouble (x r : Std.U32) : Prop := r.val = min (2 * x.val) U32.max
        "#
    }
}

/// `2 * x`, or `u32::MAX` when that overflows.
#[lean_rust::model(ensures(exact = "IsSaturatingDouble"))]
pub fn saturating_double(x: u32) -> u32 {
    if x > u32::MAX / 2 {
        u32::MAX
    } else {
        x * 2
    }
}
