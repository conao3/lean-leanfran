# 11-prop-specs

The function of 10-ensures with an exact spec stated as a `Prop`. A string names a Lean
definition instead of a Rust path, so it need not be computable:

```rust
#[leanfran::model(ensures(exact = "IsSaturatingDouble"))]
pub fn saturating_double(x: u32) -> u32 { .. }
```

```lean
def IsSaturatingDouble (x r : Std.U32) : Prop := r.val = min (2 * x.val) U32.max
```

The obligation is proved like a `Bool` spec, but `cargo test` has nothing to run for it.

Next: [12-requires](../12-requires).
