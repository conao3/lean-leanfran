//! A loop over a `&mut Vec`.

use crate::spec::specs;

#[allow(clippy::ptr_arg)]
#[leanfran::model(ensures(zeroed = specs::all_zero))]
pub fn zero_all(v: &mut Vec<u32>) {
    let mut i = 0;
    'zero: while i < v.len() {
        v[i] = 0;
        i += 1;
    }
}
