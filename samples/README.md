# Samples

Programs built with lean-rust, each small enough to read in one sitting. Every directory is a
crate of the repository's cargo workspace that depends on `lean-rust` by path, with its own
README and a `make test` that the repository's `make check` runs. Run the samples inside
`nix develop` of the repository root.

lean-rust is used in three ways here, and the samples follow them.

## 1. Write functions in Lean inside a Rust file

`lean!` holds Lean source in a Rust file. The build script (`lean-rust-build`) checks the
definitions and their proofs with Lean and generates a Rust module; the functions become Rust
functions of that module. The generated code is cached in `.lean-rust/cache/`, so a build
without Lean works as long as the Lean source is unchanged.

| Sample | What it shows |
|---|---|
| [`todo-cli`](todo-cli) | structures (`Task`, `Todo`) and theorems about the list operations, behind a Rust CLI |
| [`word-count`](word-count) | `imports` (`Std.Data.HashMap`), `do` notation, and a result of `List (String × Nat)` |

## 2. Compile a lake project to Rust modules

`lean-rust project generate` builds a lake project and writes a Rust module per Lean module,
which you commit and build without Lean.

| Sample | What it shows |
|---|---|
| [`roman-numerals`](roman-numerals) | an ordinary lake project compiled to committed Rust modules |

## 3. Verify Rust functions in Lean

`#[lean_rust::model]` binds a Rust function to specs written in Lean. `cargo lean-rust extract`
translates the function to Lean with Charon and Aeneas and states its obligations,
`cargo lean-rust check` checks the proofs in `lean/Proofs/`, and `cargo test` tests the
function against the specs. The extracted models, obligations and proof states are committed,
so `make test` needs neither Lean nor Charon; `make verify` extracts and checks again.

| Sample | What it shows |
|---|---|
| [`verified-rust`](verified-rust) | `refines` (a proved one replaces its spec by the Rust function), `ensures`, `requires`, a `Prop` spec, loop labels, proofs of loops |
| [`sorted-search`](sorted-search) | `refines` under `requires` (binary search on a sorted slice) |
| [`inventory`](inventory) | structs and enums in specs (`derive(lean_rust::Model)`), a `BTreeMap` modelled in `lean/External.lean` |

## Where to start

Start with `todo-cli` for `lean!`, then `roman-numerals` for a lake project, then
`verified-rust` for verifying Rust.
