# lean-rs

Write functions in Lean 4, prove their properties in Lean, and call them from Rust. lean-rs
compiles Lean's IR (`Lean.Compiler.IR`) to Rust source that builds with cargo alone: the
generated code needs neither the Lean toolchain nor Lean's C runtime, only the crate
`lean-rust-runtime`.

lean-rs has three parts:

- **A Rust backend for Lean** (`lean-rust module generate`). It reads the IR of a compiled Lean
  module and emits Rust that mirrors Lean's C backend: the same object layout, reference
  counting and in-place updates. Every public definition becomes a safe Rust function on Rust
  types.
- **`lean!`**, Lean source in a Rust file. The crate's build script checks the source and its
  proofs with `lake build`, generates the Rust module, and caches it in the repository, so
  builds without Lean (CI, crates.io users, docs.rs) use the cache.
- **`lean-rust project generate`**, which compiles every module of a lake project to a Rust
  module file plus a `mod.rs`, for committing to a Rust crate.

```rust
lean_rust::lean! {
    pub mod arith;
    r#"
    def double (n : Nat) : Nat := n + n

    theorem double_eq (n : Nat) : double n = 2 * n := by
      unfold double; omega
    "#
}

fn main() {
    assert_eq!(arith::double(21u64.into()), 42u64.into());
}
```

## Values

| Lean | Rust |
|---|---|
| `Bool` (and `Decidable p`) | `bool` |
| `Nat`, `Int` | `lean_rust::Nat`, `lean_rust::Int` (arbitrary precision; `From<u64>`, `TryFrom<Nat> for u64`, `Display`, `FromStr`, arithmetic) |
| `UInt8`…`UInt64`, `USize` | `u8`…`u64`, `usize` |
| `Int8`…`Int64`, `ISize` | `i8`…`i64`, `isize` |
| `Float`, `Float32` | `f64`, `f32` |
| `Char` | `char` |
| `String` | `String` (arguments take `impl AsRef<str>`) |
| `Unit` | `()` |
| `List α`, `Array α` | `Vec<T>` |
| `Option α` | `Option<T>` |
| `Except ε α` | `Result<T, E>` |
| `α × β` | `(A, B)` |
| `Fin n` (literal `n`) | `usize`, checked against `n` (panics when out of range) |
| a structure | a generated `pub struct` with snake_case fields |
| an inductive type | a generated `pub enum` (a field-less `enum` when every constructor is nullary) |
| `IO α` | `std::io::Result<T>` (`IO.Error` becomes `std::io::Error` with Lean's message) |

Generated structs and enums derive `Debug`, `Clone` and `PartialEq`, plus `Eq` and `Hash` when
the Lean type has `DecidableEq`. Recursive fields are boxed (`Box<Tree>`).

A definition whose type uses anything else is not public; `--output json` lists it under
`skipped` with the reason: type variables, function types, `Subtype`, type families, proof
arguments, and argument types with proof fields (Rust could not keep their invariant). Type
arguments are dropped, and instance arguments of a concrete type are synthesized at generation
time. Names are the last components of the Lean name in snake_case relative to the module's
namespace (`Point.add` → `point_add`, `find?` → `find_q`, `get!` → `get_bang`, `x'` →
`x_prime`, keywords as `r#type`). Each function has a doc comment with its Lean name and type,
and `#[lean_rust::exported("<Lean name>")]`. A `@[csimp]` replacement in the definition's module
is what the function runs.

## Install

The CLI is a Lean program. With Nix:

```
nix profile install github:conao3/lean-rs   # or `nix profile install .` in a checkout
lean-rust --version
```

or build it from a checkout with `lake build lean-rust` (Lean 4.35.0, see `lean-toolchain`); the
executable is `.lake/build/bin/lean-rust`.

The Rust crates are `lean-rust` (the facade with `lean!`, the runtime and the conversion
traits), `lean-rust-runtime`, `lean-rust-macros` and `lean-rust-build`. Until they are published,
depend on them by path or git.

## Quick start: `lean!`

```toml
# Cargo.toml
[dependencies]
lean-rust = { git = "https://github.com/conao3/lean-rs" }

[build-dependencies]
lean-rust-build = { git = "https://github.com/conao3/lean-rs" }
```

```rust
// build.rs
fn main() {
    lean_rust_build::Builder::new().compile().unwrap();
}
```

```rust
// src/lib.rs
lean_rust::lean! {
    /// Documentation of the module.
    #[lean(imports = ["Std.Data.HashMap"], uses = [crate::geometry::shapes])]
    pub mod arith;
    r#"
    def double (n : Nat) : Nat := n + n
    "#
}
```

The build script finds every `lean!` in `src/**/*.rs`. For a block that is not in
`.lean-rust/cache/`, it writes the source (wrapped in `namespace <name>`) into the crate's Lean
package `lean/LeanRustGen/Embed/`, creating `lean/` with a `lakefile.toml` when it is missing,
runs `lake build`, and runs `lean-rust module generate`. Lean errors are reported at the Rust
file and line of the source. `imports` are Lean modules to import; `uses` are other `lean!`
blocks of the crate, whose module is imported and opened and whose generated types are shared.

| Variable | Effect |
|---|---|
| `LEAN_RUST_CLI` | the `lean-rust` executable (default: `lean-rust` on `PATH`; `lake` is always taken from `PATH`) |
| `LEAN_RUST_OFFLINE=1` | use the cache only; list the blocks missing from it and stop |
| `LEAN_RUST_EXTRACTING=1` | do nothing |

Commit `.lean-rust/cache/` and `lean/` (its `.gitignore` excludes `lean/.lake/`), and add
`.lean-rust/cache/**` to the crate's `include` when you publish it. The macro only includes the
generated file, so rust-analyzer never runs Lean.

## Quick start: a lake project

```
lean-rust project generate --lake-dir lean --output-dir src/generated
```

builds the project, uses `lake env`'s `LEAN_PATH` as the search path, and writes
`src/generated/<module>.rs` for each module built by the package (or for `--modules ...`) and a
`mod.rs`. Declare `mod generated;` in the crate and depend on `lean-rust`.

## The CLI

```
lean-rust module generate --module-name <Module> [--roots <Name> ...] [--namespace <Name>]
          [--search-path <dir> ...] [--output-file <path>] [--runtime-path <path>]
          [--facade-path <path>] [--type-path <Namespace>=<path> ...] [--internal-only]
          [--batch <jobs.json>] [--output json|text]
lean-rust project generate --lake-dir <dir> --output-dir <dir> [--modules <Module> ...]
```

`--roots` defaults to the module's public definitions written in its source (not instances).
`--batch` runs several modules against one environment. Exit codes: 0 success, 252 invalid
parameters, 254 input that cannot be converted (externs the runtime lacks, unsupported IR,
clashing Rust names), 255 other errors. `lean-rust help` prints all options.

## Samples

[`samples/`](samples) has `todo-cli` and `word-count` (`lean!`) and `roman-numerals` (a lake
project with committed generated modules).

## Development

Inside `nix develop` (elan, Rust, cargo-nextest):

```
make check
```

runs the format check, clippy, the diff tests against Lean's C backend (`./test-diff.sh`), the
public API tests (`./test-public.sh`), the runtime and build tests, the `lean!` tests
(`tests/embed`) and the samples.

## Limitations

- Objects use non-atomic reference counts; `Task`s run synchronously where they are created.
- Each generated module defines its own structs and enums; two modules that mention the same
  Lean type have two Rust types, except for types of the blocks named in `uses`.
- Generic structures are generated per instantiation (`Pair Nat Bool` → `PairNatBool`).

## License

Apache-2.0
