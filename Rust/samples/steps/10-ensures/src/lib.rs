//! Step 10: `ensures`, a condition on the result, proved for every input.

pub mod spec {
    leanfran::lean! {
        #[lean(imports = ["Aeneas"])]
        pub mod double;
        r#"
        open Aeneas Aeneas.Std

        /-- The result is not less than the argument. -/
        def ge (x r : Std.U32) : Bool := decide (x.val ≤ r.val)
        "#
    }
}

use spec::double;

/// `2 * x`, or `u32::MAX` when that overflows. The obligation also says that `x * 2` does not
/// overflow where it runs: the model fails where the Rust function panics.
#[leanfran::model(ensures(ge = double::ge))]
pub fn saturating_double(x: u32) -> u32 {
    if x > u32::MAX / 2 {
        u32::MAX
    } else {
        x * 2
    }
}
