//! A struct and a method.

use crate::spec::counters;

#[derive(Clone, Debug, PartialEq, leanfran::Model)]
pub struct Counter {
    pub count: u32,
    pub active: bool,
}

#[leanfran::model]
impl Counter {
    #[leanfran::model(refines = counters::reset, strategy = crate::counter::counters)]
    pub fn reset(&mut self) {
        self.count = 0;
    }
}

#[cfg(test)]
fn counters() -> impl leanfran::check::proptest::strategy::Strategy<Value = Counter> {
    use leanfran::check::proptest::prelude::*;
    (any::<u32>(), any::<bool>()).prop_map(|(count, active)| Counter { count, active })
}
