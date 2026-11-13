//! Functions whose bodies are not extracted, and a Rust function Lean calls.

use std::cell::Cell;

thread_local! {
    static TRACES: Cell<u32> = const { Cell::new(0) };
}

/// Counts the calls; its model (`lean/External.lean`) does nothing.
#[leanfran::opaque]
pub fn trace() {
    TRACES.with(|c| c.set(c.get() + 1));
}

/// The number of calls of [`trace`] on this thread.
pub fn traces() -> u32 {
    TRACES.with(|c| c.get())
}

/// Panics on 7; its model (`lean/External.lean`) is an axiom.
#[leanfran::opaque]
pub fn check(x: u32) {
    if x == 7 {
        panic!("seven");
    }
}

/// `axioms`: the proof relies on the axiom of `check`.
#[leanfran::model(ensures(same = crate::spec::specs::unchanged), check = false)]
pub fn guarded(x: u32) -> u32 {
    check(x);
    x
}

/// Its model (`lean/External.lean`) is a definition: the test compares the two.
#[leanfran::opaque]
pub fn clamp(x: u32) -> u32 {
    x.min(100)
}

/// A model calling `clamp`, without obligations.
#[leanfran::model]
pub fn capped(x: u32) -> u32 {
    clamp(x)
}

/// A reading whose method's model (`lean/External.lean`) is a definition: the test compares the
/// two.
#[derive(Clone, Copy, Debug, PartialEq, Eq, leanfran::Model)]
pub struct Meter {
    pub value: u32,
}

#[leanfran::opaque(strategy = crate::effects::meter_input)]
impl Meter {
    /// The smaller of the reading and `limit`.
    pub fn lesser(&self, limit: u32) -> u32 {
        self.value.min(limit)
    }
}

#[cfg(test)]
fn meter_input() -> impl leanfran::check::proptest::strategy::Strategy<Value = (Meter, u32)> {
    use leanfran::check::proptest::prelude::*;
    (any::<u32>().prop_map(|value| Meter { value }), any::<u32>())
}
