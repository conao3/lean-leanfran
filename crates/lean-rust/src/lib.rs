//! Run Lean functions from Rust and verify Rust functions in Lean.
//!
//! - [`lean!`] embeds Lean source in a Rust file. The build script of the crate
//!   (`lean_rust_build::Builder::new().compile()`) checks it with Lean and generates the Rust
//!   module that the macro includes.
//! - [`runtime`] is the runtime of the generated code. [`Nat`] and [`Int`] are the Rust types of
//!   Lean's `Nat` and `Int`; [`ToLean`] and [`FromLean`] convert values.

pub use lean_rust_macros::{exported, lean};
pub use lean_rust_runtime as runtime;
pub use lean_rust_runtime::{FromLean, Int, Nat, ToLean};
