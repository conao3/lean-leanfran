# Samples

Programs built with lean-rust, each small enough to read in one sitting. Every directory is a
crate of the repository's cargo workspace that depends on `lean-rust` by path, with its own
README and a `make test` that the repository's `make check` runs. Run the samples inside
`nix develop` of the repository root.

lean-rust is used in two ways here, and the samples follow them.

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

## Where to start

Start with `todo-cli` for `lean!`, then `roman-numerals` for a lake project.
