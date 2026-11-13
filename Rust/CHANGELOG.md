# Changelog

## 0.4.0

### Breaking

- The generated code is of generator version 3. A crate's `.leanfran/cache/` and
  `leanfran.lock` from 0.3.0 are regenerated: build the crate with `LEANFRAN_CLI` set to a
  0.4.0 `leanfran`, then run `cargo leanfran extract` and `cargo leanfran check`.
- `#[leanfran::opaque]` on a method is an error that points to its impl block.

### Added

- `#[leanfran::opaque]` on an inherent impl block keeps the bodies of its methods out of the
  model, and `cargo test` compares each method with its model in `lean/External.lean`. A
  method's own `#[leanfran::opaque(..)]` in the block gives its `check` and `strategy`.
- `cargo leanfran extract` takes a crate whose only items are `#[leanfran::opaque]`
  functions.
- `Fin n` whose bound reduces to a literal is a public type: `usize` below 2^64, and
  `leanfran::Nat` from 2^64.

### Fixed

- `String` is passed to a model as Lean's `String`, the type Aeneas gives
  `alloc::string::String`, and `&'static str` as `Str`.
- `leanfran project generate` and `leanfran crate check` take the Lean sysroot from `lake env`
  of the lake project, and the build script runs `leanfran` in the crate's `lean/`: a crate
  needs no `lean-toolchain` in a directory above it.
- A constant is read without nesting `LocalKey::with`, so a chain of thousands of constants
  compiles within rustc's recursion limit.
- Generated code allows `unused_qualifications`.

### Changed

- Dependencies: syn 3, sha2 0.11, toml 1.2, num-bigint 0.5.
