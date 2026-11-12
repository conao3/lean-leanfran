//! Step 17: a generic function, proved once for every `Ord` type and tested with `instances`.

pub mod spec {
    lean_rust::lean! {
        #[lean(imports = ["Aeneas"])]
        pub mod range;
        r#"
        open Aeneas Aeneas.Std

        def ordered {α : Type} [LinearOrder α] (_x lo hi : α) : Bool := decide (lo ≤ hi)

        def within {α : Type} [LinearOrder α] (_x lo hi r : α) : Bool := decide (lo ≤ r ∧ r ≤ hi)

        rust_instances ordered [Std.U32, Std.I64]

        rust_instances within [Std.U32, Std.I64]
        "#
    }
}

use spec::range;

/// `x` moved into `lo..=hi`.
#[lean_rust::model(instances = [u32, i64], requires = range::ordered, ensures(within = range::within))]
pub fn clamp<T: Ord + Copy>(x: T, lo: T, hi: T) -> T {
    if x < lo {
        lo
    } else if hi < x {
        hi
    } else {
        x
    }
}
