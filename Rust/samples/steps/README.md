# Steps

One feature per crate, in the order to read them. Each step is a crate of the repository's
cargo workspace with a README, tests (`cargo test`), and a `make test` that the repository's
`make check` runs; the steps that verify Rust also have `make verify`.

## Writing functions in Lean

| Step | Feature |
|---|---|
| [01-functions](01-functions) | a `lean!` block: Lean definitions as Rust functions (`Nat`, `UInt64`, `Bool`, `String`) |
| [02-theorems](02-theorems) | theorems checked when the crate is built |
| [03-structures](03-structures) | a structure as a Rust struct |
| [04-inductives](04-inductives) | inductive types as Rust enums, a recursive one boxed |
| [05-collections](05-collections) | `List`, `Array`, pairs, `Option` and `Except` |
| [06-imports](06-imports) | `imports` and `do` notation |
| [07-io](07-io) | `IO` actions as `std::io::Result` |
| [08-polymorphic](08-polymorphic) | a polymorphic function as a generic Rust function (`rust_instances`) |
| [09-lake-project](09-lake-project) | a lake project compiled to committed Rust modules |

## Verifying functions written in Rust

| Step | Feature |
|---|---|
| [10-ensures](10-ensures) | `ensures`: a condition on the result |
| [11-prop-specs](11-prop-specs) | a `Prop` spec |
| [12-requires](12-requires) | `requires`: an assumption on the arguments |
| [13-refines](13-refines) | `refines`: equal to a spec, which then runs the Rust function |
| [14-loops](14-loops) | loop labels and a proof by induction |
| [15-structs-enums](15-structs-enums) | the crate's structs and enums in specs (`derive(leanfran::Model)`) |
| [16-opaque](16-opaque) | `#[leanfran::opaque]`: a model written by hand |
| [17-generics](17-generics) | a generic function proved for every `Ord` type |
