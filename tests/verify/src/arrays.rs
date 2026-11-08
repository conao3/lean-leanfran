//! A fixed-size array.

use crate::spec::specs;

#[lean_rust::model(refines = specs::arr_sum)]
pub fn sum3(a: [u32; 3]) -> u64 {
    let mut s = 0u64;
    let mut i = 0;
    'add: while i < 3 {
        s += a[i] as u64;
        i += 1;
    }
    s
}
