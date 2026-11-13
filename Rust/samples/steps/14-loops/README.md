# 14-loops

Every loop of a modelled function has a label, which names the loop in Lean: `'add` in
`sum_to` is `step_14_loops.sum_to.add` (an alias of Aeneas's `sum_to_loop`), so the proofs keep
their names when other loops are added.

```rust
#[leanfran::model(refines = sums::sum_to, strategy = crate::small)]
pub fn sum_to(n: u32) -> u64 {
    let mut i = 0u32;
    let mut s = 0u64;
    'add: while i < n {
        i += 1;
        s += i as u64;
    }
    s
}
```

The spec is the closed form `n * (n + 1) / 2`. [`lean/Proofs/SumTo.lean`](lean/Proofs/SumTo.lean)
proves the loop by induction on `n - i` (`add_spec`, with the invariant
`s = i * (i + 1) / 2`), including that `s += i` never overflows. `strategy = crate::small`
keeps the tested `n` below 100000, so that the tests stay fast.

Next: [15-structs-enums](../15-structs-enums).
