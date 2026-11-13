//! Step 16: `#[leanfran::opaque]`, a function whose model is written by hand in
//! `lean/External.lean`.

pub mod spec {
    leanfran::lean! {
        #[lean(imports = ["Aeneas"])]
        pub mod bar;
        r#"
        open Aeneas Aeneas.Std

        def fits (_p r : Std.U32) : Bool := decide (r.val ≤ 20)
        "#
    }
}

use spec::bar;

/// `x` capped at 100. Its body stays out of the model; `cargo test` compares it with the model
/// in `lean/External.lean`.
#[leanfran::opaque]
pub fn percent(x: u32) -> u32 {
    x.min(100)
}

/// The width of a progress bar of 20 cells; the proof uses the model of [`percent`].
#[leanfran::model(ensures(fits = bar::fits))]
pub fn bar_width(p: u32) -> u32 {
    percent(p) / 5
}
