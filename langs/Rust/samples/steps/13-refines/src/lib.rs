//! Step 13: `refines`, the function equals a Lean spec; once proved, the spec runs the Rust
//! function.

pub mod spec {
    leanfran::lean! {
        #[lean(imports = ["Aeneas"])]
        pub mod calendar;
        r#"
        open Aeneas Aeneas.Std

        /-- The rule of the Gregorian calendar. -/
        def leap (y : Std.U32) : Bool :=
          y.val % 4 = 0 ∧ (y.val % 100 ≠ 0 ∨ y.val % 400 = 0)
        "#
    }
}

use spec::calendar;

/// Whether `year` is a leap year, testing the most frequent case first.
#[leanfran::model(refines = calendar::leap)]
pub fn is_leap(year: u32) -> bool {
    if !year.is_multiple_of(4) {
        false
    } else if !year.is_multiple_of(100) {
        true
    } else {
        year.is_multiple_of(400)
    }
}
