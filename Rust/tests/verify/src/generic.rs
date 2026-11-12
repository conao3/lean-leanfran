//! Generic functions: an obligation for every type (`proved`), obligations per type (`proved`,
//! replaced by the csimp), and a method of a generic struct.

use crate::spec::{generic_specs, pairs};

/// The obligation for every type: `proved` with the laws of `Ord`.
#[lean_rust::model(instances = [u32, i64], ensures(ge = generic_specs::max_ge))]
pub fn max_of<T: Ord + Copy>(a: T, b: T) -> T {
    if a >= b {
        a
    } else {
        b
    }
}

/// An obligation per type: `refines.u32` is `proved` and replaces `larger` for `u32`,
/// `refines.i64` is `sorry`.
#[lean_rust::model(
    instances = [u32, i64],
    obligations = per_instance,
    refines = generic_specs::larger
)]
pub fn larger<T: Ord + Copy>(a: T, b: T) -> T {
    if b > a {
        b
    } else {
        a
    }
}

#[derive(Debug, Clone, Copy, PartialEq, lean_rust::Model)]
pub struct Pair<T> {
    pub a: T,
    pub b: T,
}

#[lean_rust::model(instances = [u32], obligations = per_instance, strategy = crate::generic::pairs)]
impl<T: Clone> Pair<T> {
    /// A method of a generic struct.
    #[lean_rust::model(refines = pairs::swapped)]
    pub fn swap(&self) -> Pair<T> {
        Pair {
            a: self.b.clone(),
            b: self.a.clone(),
        }
    }
}

#[cfg(test)]
fn pairs<T: lean_rust::check::proptest::arbitrary::Arbitrary + Clone>(
) -> impl lean_rust::check::proptest::strategy::Strategy<Value = Pair<T>> {
    use lean_rust::check::proptest::prelude::*;
    (any::<T>(), any::<T>()).prop_map(|(a, b)| Pair { a, b })
}
