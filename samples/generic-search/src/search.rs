//! Generic functions over `Ord`.

use crate::spec::search;

/// The larger of `a` and `b`.
#[lean_rust::model(instances = [u32, i64], ensures(max = search::is_max))]
pub fn max_of<T: Ord + Copy>(a: T, b: T) -> T {
    if a >= b {
        a
    } else {
        b
    }
}

/// Whether `x` is an element of the sorted slice `xs`: halves the range of the elements that
/// are not less than `x` from below, then compares the first of them.
#[lean_rust::model(
    instances = [u32, i64, String],
    refines = search::mem,
    requires = search::sorted,
    strategy = crate::search::sorted_input,
)]
pub fn contains<T: Ord>(xs: &[T], x: &T) -> bool {
    let mut lo = 0;
    let mut hi = xs.len();
    'halve: while lo < hi {
        let mid = lo + (hi - lo) / 2;
        if xs[mid] < *x {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    lo < xs.len() && xs[lo] == *x
}

#[cfg(test)]
fn sorted_input<T>() -> impl lean_rust::check::proptest::strategy::Strategy<Value = (Vec<T>, T)>
where
    T: lean_rust::check::proptest::arbitrary::Arbitrary + Ord + Clone,
{
    use lean_rust::check::proptest::prelude::*;
    (
        prop::collection::vec(any::<T>(), 0..30),
        any::<T>(),
        any::<prop::sample::Index>(),
        any::<bool>(),
    )
        .prop_map(|(mut xs, x, i, pick)| {
            xs.sort();
            let x = if pick && !xs.is_empty() {
                i.get(&xs).clone()
            } else {
                x
            };
            (xs, x)
        })
}
