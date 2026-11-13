//! Step 12: `requires`, an assumption on the arguments of every obligation and test.

pub mod spec {
    leanfran::lean! {
        #[lean(imports = ["Aeneas"])]
        pub mod mid;
        r#"
        open Aeneas Aeneas.Std

        def ordered (lo hi : Std.U32) : Bool := decide (lo.val ≤ hi.val)

        def between (lo hi r : Std.U32) : Bool := decide (lo.val ≤ r.val ∧ r.val ≤ hi.val)
        "#
    }
}

use spec::mid;

/// The middle of `lo..=hi`, without overflowing. `hi - lo` panics when `hi < lo`, so the
/// obligation assumes `lo ≤ hi`, and the tests draw such arguments only.
#[leanfran::model(requires = mid::ordered, ensures(between = mid::between))]
pub fn midpoint(lo: u32, hi: u32) -> u32 {
    lo + (hi - lo) / 2
}
