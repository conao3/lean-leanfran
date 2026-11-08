//! Fast implementations that compute their spec.

use crate::spec::bits;

/// The number of one bits of `x`, by clearing the lowest one bit until none is left.
#[lean_rust::model(refines = bits::popcount)]
pub fn popcount_fast(mut x: u64) -> u32 {
    let mut n = 0u32;
    'clear: while x != 0 {
        x &= x - 1;
        n += 1;
    }
    n
}

/// The larger of `a` and `b`.
#[lean_rust::model(refines = bits::max, ensures(bound = bits::max_bound))]
pub fn max_u32(a: u32, b: u32) -> u32 {
    if a <= b {
        b
    } else {
        a
    }
}
