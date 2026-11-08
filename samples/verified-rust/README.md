# verified-rust

Rust functions bound to specs written in Lean with `#[lean_rust::model]`: the two ways of
`lean-ritsuryo` beyond running a spec directly.

- [`src/spec.rs`](src/spec.rs): the specs, `lean!` blocks over the types of Aeneas's model of
  Rust (`Std.U32`, `Slice Std.I64`, `alloc.vec.Vec Std.I64`).
- [`src/bits.rs`](src/bits.rs): a fast implementation equal to its spec (`refines`).
  `max_u32` also has a condition on its result (`ensures(bound = ..)`).
- [`src/sort.rs`](src/sort.rs): an implementation satisfying conditions on its result, under a
  condition on its input (`requires`, `ensures`); `perm` is a `Prop` spec named by a string,
  for proofs only.
- [`lean/Proofs/`](lean/Proofs): the proofs.

| Function | Obligation | State |
|---|---|---|
| `max_u32` | `refines` (`bits.max`) | proved: `bits::max` runs `max_u32` (csimp) |
| `max_u32` | `bound` (`bits.max_bound`) | proved |
| `popcount_fast` | `refines` (`bits.popcount`) | `sorry`: the step `popcount (x &&& (x - 1)) + 1 = popcount x` is bit-level reasoning not done here |
| `insert_sorted` | `sorted` (`sorting.output_sorted`) | missing: needs a spec of the loop over the slice iterator |
| `insert_sorted` | `perm` (`OutputPerm`) | `sorry` |

`cargo test` checks every `refines` and `ensures` with a Rust path against the spec with
proptest, proved or not; `insert_sorted` draws sorted inputs from `strategy`.

```
make test      # the tests, from the committed caches (no Lean)
make verify    # cargo lean-rust extract and check again (Charon, Aeneas, Mathlib)
```

`cargo lean-rust status` prints the states; `cargo doc` shows them on each function.
