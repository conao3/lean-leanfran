# 16-opaque

`#[leanfran::opaque]` keeps a function's body out of the model; its model is written by hand
in [`lean/External.lean`](lean/External.lean). Use it for code Aeneas does not translate, or
whose details the proofs should not depend on.

```rust
#[leanfran::opaque]
pub fn percent(x: u32) -> u32 { x.min(100) }

#[leanfran::model(ensures(fits = bar::fits))]
pub fn bar_width(p: u32) -> u32 { percent(p) / 5 }
```

```lean
-- lean/External.lean
def percent (x : Std.U32) : Result Std.U32 := if x.val ≤ 100 then ok x else ok 100#u32
```

`cargo leanfran extract` writes the template of `External.lean` (an axiom per opaque
function). Replaced by a definition, the model is compiled like a `lean!` block, and
`cargo test` compares `percent` with it. The proof of `bar_width` uses the model only.

Next: [17-generics](../17-generics).
