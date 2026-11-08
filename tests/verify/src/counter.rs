//! A struct and a method.

use crate::spec::counters;

#[derive(Clone, Debug, PartialEq, lean_rust::Model)]
pub struct Counter {
    pub count: u32,
    pub active: bool,
}

#[lean_rust::model]
impl Counter {
    #[lean_rust::model(refines = counters::reset, strategy = crate::counter::counters)]
    pub fn reset(&mut self) {
        self.count = 0;
    }
}

#[cfg(test)]
fn counters() -> impl lean_rust::check::proptest::strategy::Strategy<Value = Counter> {
    use lean_rust::check::proptest::prelude::*;
    (any::<u32>(), any::<bool>()).prop_map(|(count, active)| Counter { count, active })
}
