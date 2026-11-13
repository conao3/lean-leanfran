//! Step 14: a loop, named by its label, and proved by induction.

pub mod spec {
    leanfran::lean! {
        #[lean(imports = ["Aeneas"])]
        pub mod sums;
        r#"
        open Aeneas Aeneas.Std

        /-- `0 + 1 + … + n`, in closed form. -/
        def sum_to (n : Std.U32) : Std.U64 := ⟨BitVec.ofNat 64 (n.val * (n.val + 1) / 2)⟩
        "#
    }
}

use spec::sums;

/// `0 + 1 + … + n`, adding one number at a time. The loop `'add` is `sum_to.add` in Lean.
#[leanfran::model(refines = sums::sum_to, strategy = crate::small)]
pub fn sum_to(n: u32) -> u64 {
    let mut i = 0u32;
    let mut s = 0u64;
    'add: while i < n {
        i += 1;
        s += i as u64;
    }
    s
}

/// Arguments that keep the loop short in the tests.
#[cfg(test)]
fn small() -> impl leanfran::check::proptest::strategy::Strategy<Value = u32> {
    0u32..100_000
}
