//! Functions whose bodies are not extracted, and a Rust function Lean calls.

use std::cell::Cell;

thread_local! {
    static TRACES: Cell<u32> = const { Cell::new(0) };
}

/// Counts the calls; its model (`lean/External.lean`) does nothing.
#[lean_rust::opaque]
pub fn trace() {
    TRACES.with(|c| c.set(c.get() + 1));
}

/// The number of calls of [`trace`] on this thread.
pub fn traces() -> u32 {
    TRACES.with(|c| c.get())
}

/// Panics on 7; its model (`lean/External.lean`) is an axiom.
#[lean_rust::opaque]
pub fn check(x: u32) {
    if x == 7 {
        panic!("seven");
    }
}

/// `axioms`: the proof relies on the axiom of `check`.
#[lean_rust::model(ensures(same = crate::spec::specs::unchanged), check = false)]
pub fn guarded(x: u32) -> u32 {
    check(x);
    x
}
