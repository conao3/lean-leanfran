//! The public API generated from `LeanRustTest.Public` (`test-out/public.rs`).

#![allow(dead_code, non_snake_case, unused_parens, clippy::all)]

include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../test-out/public.rs"
));

/// The generated source, for tests of what the wrappers call.
pub const SOURCE: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../test-out/public.rs"
));
