# 13-refines

`refines` says that the function computes a Lean spec on every input:

```rust
#[lean_rust::model(refines = calendar::leap)]
pub fn is_leap(year: u32) -> bool { .. }
```

```lean
def step_13_refines.is_leap.obligation.refines : Prop :=
  ∀ year, step_13_refines.is_leap year = ok (_root_.calendar.leap year)
```

Once it is proved, `cargo lean-rust check` writes `lean/LeanRustGen/Csimp.lean`: a `@[csimp]`
lemma that replaces the spec by the Rust function, so `calendar::leap` (the Lean spec compiled
to Rust) calls `is_leap`. A spec can then be written for clarity and still run as fast as the
implementation.

Next: [14-loops](../14-loops).
