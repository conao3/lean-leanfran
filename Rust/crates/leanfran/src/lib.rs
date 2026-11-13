//! Run Lean functions from Rust and verify Rust functions in Lean.
//!
//! - [`lean!`] embeds Lean source in a Rust file. The build script of the crate
//!   (`leanfran_build::Builder::new().compile()`) checks it with Lean and generates the Rust
//!   module that the macro includes.
//! - [`model`] binds a Rust function to Lean specs: `cargo leanfran extract` translates it to
//!   Lean with Charon and Aeneas and states the proof obligations, `cargo leanfran check`
//!   checks the proofs, and `cargo test` tests the function against the specs.
//! - [`runtime`] is the runtime of the generated code. [`Nat`] and [`Int`] are the Rust types of
//!   Lean's `Nat` and `Int`; [`ToLean`] and [`FromLean`] convert values, [`Model`] converts them
//!   to the representation of Aeneas's model.

pub use leanfran_macros::{exported, lean, model, opaque, Model};
pub use leanfran_runtime as runtime;
pub use leanfran_runtime::{FromLean, Int, Model, Nat, ToLean};

pub mod spec;

/// The property-based testing of `#[model]` (the `proptest` crate).
#[cfg(feature = "check")]
pub mod check {
    pub use proptest;

    /// A value in the message of a failed test: `(&Shown(&v)).show()` is the `Debug` form of
    /// `v` when its type implements `Debug` ([`ShowDebug`]), and `_` otherwise ([`ShowOther`]).
    pub struct Shown<'a, T>(pub &'a T);

    pub trait ShowDebug {
        fn show(&self) -> String;
    }

    impl<T: std::fmt::Debug> ShowDebug for Shown<'_, T> {
        fn show(&self) -> String {
            format!("{:?}", self.0)
        }
    }

    pub trait ShowOther {
        fn show(&self) -> String;
    }

    impl<T> ShowOther for &Shown<'_, T> {
        fn show(&self) -> String {
            "_".to_string()
        }
    }
}
