//! A stock of quantities by item id.

use std::collections::BTreeMap;

/// The quantity of `id` in `stock` (0 when absent). Aeneas has no model of `BTreeMap`;
/// `lean/ExternalTypes.lean` and `lean/External.lean` model it as an association list.
#[leanfran::model]
pub fn quantity(stock: &BTreeMap<u32, u32>, id: u32) -> u32 {
    match stock.get(&id) {
        Some(q) => *q,
        None => 0,
    }
}
