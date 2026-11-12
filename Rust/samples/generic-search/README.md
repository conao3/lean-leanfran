# generic-search

Generic functions over `Ord`, verified once for every type and tested with `u32`, `i64` and
`String` (`instances = [..]`).

- [`src/spec.rs`](src/spec.rs): `is_max`, `sorted` and `mem` are polymorphic over a
  `LinearOrder`; `rust_instances` compiles them for the model types of the tests (`Std.U32`,
  `Std.I64`, and Lean's `String` for Rust's `String`), and they become generic Rust functions.
- [`src/search.rs`](src/search.rs): `max_of<T: Ord + Copy>` and `contains<T: Ord>`, a binary
  search over a sorted slice whose loop `'halve` is `generic_search.search.contains.halve`.

Each obligation is one theorem for every type `T` with `[LinearOrder T]` and an instance
`ord : core.cmp.Ord T` with `[LeanRust.OrdModel ord]` (`lean/LeanRustGen/Lib/AeneasModel.lean`):
the `@[step]` lemmas of `OrdModel` turn `ord.partialOrdInst.lt t x` into `decide (t < x)` and
`ord.eqInst.partialEqInst.eq t x` into `decide (t = x)`. The proofs in
[`lean/Proofs/Search.lean`](lean/Proofs/Search.lean) are those of `sorted-search` with `<` of
the order in place of the integers: the loop keeps `lo ≤ hi ≤ len`, the elements below `lo`
less than `x` and those from `hi` on not less than `x`.

The proofs apply to `u32` and `i64` through Aeneas's instances (`core.cmp.OrdU32`), which
lean-rs proves to be models. Aeneas has no `Ord` for `String`, so `String` is covered by the
tests only. The tests draw sorted slices from `strategy = crate::search::sorted_input`, a
generic function called with the type of each instance.

```
make test      # the tests, from the committed caches (no Lean)
make verify    # cargo lean-rust extract and check again (Charon, Aeneas, Mathlib)
```
