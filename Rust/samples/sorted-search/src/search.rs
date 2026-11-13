//! Searches in a sorted slice.

use crate::spec::search;

/// The index of the first element of `xs` that is not less than `x` (`xs.len()` if none):
/// halves the range that holds it until it is empty.
#[leanfran::model(
    refines = search::lower_bound,
    requires = search::sorted,
    strategy = crate::search::sorted_input,
)]
pub fn lower_bound(xs: &[i64], x: i64) -> usize {
    let mut lo = 0;
    let mut hi = xs.len();
    'halve: while lo < hi {
        let mid = lo + (hi - lo) / 2;
        if xs[mid] < x {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    lo
}

/// Whether `x` is an element of `xs`.
#[leanfran::model(
    refines = search::mem,
    requires = search::sorted,
    strategy = crate::search::sorted_input,
)]
pub fn contains(xs: &[i64], x: i64) -> bool {
    let i = lower_bound(xs, x);
    i < xs.len() && xs[i] == x
}

#[cfg(test)]
fn sorted_input() -> impl leanfran::check::proptest::strategy::Strategy<Value = (Vec<i64>, i64)> {
    use leanfran::check::proptest::prelude::*;
    (prop::collection::vec(-50i64..50, 0..30), -60i64..60).prop_map(|(mut xs, x)| {
        xs.sort();
        (xs, x)
    })
}
