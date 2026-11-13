//! Functions on integers: `proved`, `sorry`, `missing` and `mismatch`.

use crate::spec::specs;

/// `proved` (`refines`, replaced by the csimp) and `proved` (`ensures`).
#[leanfran::model(refines = specs::bigger)]
pub fn bigger(a: u32, b: u32) -> u32 {
    crate::effects::trace();
    if a <= b {
        b
    } else {
        a
    }
}

/// `sorry`.
#[leanfran::model(refines = specs::double)]
pub fn double(x: u32) -> u32 {
    x.wrapping_mul(2)
}

/// `missing`.
#[leanfran::model(ensures(halved = specs::halved))]
pub fn halve(x: u32) -> u32 {
    half(x)
}

fn half(x: u32) -> u32 {
    x / 2
}

/// `mismatch`.
#[leanfran::model(requires = specs::small, ensures(pos = specs::positive), strategy = crate::arith::small)]
pub fn succ(x: u32) -> u32 {
    x + 1
}

#[cfg(test)]
fn small() -> impl leanfran::check::proptest::strategy::Strategy<Value = u32> {
    0u32..1000
}
