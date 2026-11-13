# verified-rust

Rust functions bound to specs written in Lean with `#[leanfran::model]`: the two ways of
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
| `popcount_fast` | `refines` (`bits.popcount`) | proved: `bits::popcount` runs `popcount_fast` (csimp) |
| `insert_sorted` | `sorted` (`sorting.output_sorted`) | proved |
| `insert_sorted` | `perm` (`OutputPerm`) | proved |

The proofs in [`lean/Proofs/Bits.lean`](lean/Proofs/Bits.lean) count the one bits of the `n`
lowest bits (`pc`), prove `pc (v &&& (v - 1)) + 1 = pc v` for `v ≠ 0` by induction on `n`, and
state the loop `'clear` with `termination_by x.val`. [`lean/Proofs/Sort.lean`](lean/Proofs/Sort.lean)
states the loop `'scan` over the slice iterator (`slice` and index `i`) with a function of the
remaining elements `slice.val.drop i`, shows that the result is Mathlib's `List.orderedInsert`,
and takes sortedness and the permutation from Mathlib. `input_sorted` also bounds the length
below `Usize.max`: `xs.len() + 1` overflows on a slice of that length in the model.

`cargo test` checks every `refines` and `ensures` with a Rust path against the spec with
proptest, proved or not; `insert_sorted` draws sorted inputs from `strategy`.

```
make test      # the tests, from the committed caches (no Lean)
make verify    # cargo leanfran extract and check again (Charon, Aeneas, Mathlib)
```

`cargo leanfran status` prints the states; `cargo doc` shows them on each function.
