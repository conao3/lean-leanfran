//! An implementation that satisfies conditions on its result.

use crate::spec::sorting;

/// `xs` (sorted) with `x` inserted at its place.
#[lean_rust::model(
    requires = sorting::input_sorted,
    ensures(sorted = sorting::output_sorted, perm = "OutputPerm"),
    strategy = crate::sort::sorted_input,
)]
pub fn insert_sorted(x: i64, xs: &[i64]) -> Vec<i64> {
    let mut out = Vec::with_capacity(xs.len() + 1);
    let mut placed = false;
    'scan: for &y in xs {
        if !placed && x <= y {
            out.push(x);
            placed = true;
        }
        out.push(y);
    }
    if !placed {
        out.push(x);
    }
    out
}

#[cfg(test)]
fn sorted_input() -> impl lean_rust::check::proptest::strategy::Strategy<Value = (i64, Vec<i64>)> {
    use lean_rust::check::proptest::prelude::*;
    (any::<i64>(), prop::collection::vec(any::<i64>(), 0..20)).prop_map(|(x, mut xs)| {
        xs.sort();
        (x, xs)
    })
}
