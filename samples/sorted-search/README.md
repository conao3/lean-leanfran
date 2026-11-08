# sorted-search

Binary search over a sorted slice, bound to linear specs under the assumption that the slice
is sorted (`refines = .., requires = search::sorted`).

- [`src/spec.rs`](src/spec.rs): `sorted`, `lower_bound` (the number of elements less than `x`)
  and `mem`, in the types of Aeneas's model.
- [`src/search.rs`](src/search.rs): `lower_bound` halves a range in the loop `'halve`, whose
  Lean model is `sorted_search.search.lower_bound.halve`; `contains` calls it.

Both obligations are proved in [`lean/Proofs/Search.lean`](lean/Proofs/Search.lean): the loop
`'halve` has a spec with its invariant (`lo ≤ hi ≤ len`, the elements below `lo` are less than
`x`, those from `hi` on are not) and `termination_by hi - lo`; at its end the count is `lo`.
`contains` uses the invariant that the spec of `lower_bound` returns. A
`refines` with `requires` is not a csimp replacement: the Rust function is equal to the spec
only on sorted slices, so code calls `lower_bound` directly where the slice is sorted.

The tests draw sorted slices from `strategy = crate::search::sorted_input`.

```
make test      # the tests, from the committed caches (no Lean)
make verify    # cargo lean-rust extract and check again (Charon, Aeneas, Mathlib)
```
