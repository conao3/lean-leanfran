# 10-ensures

From here on, the functions are written in Rust and verified in Lean. `#[lean_rust::model]`
names the specs; `cargo lean-rust extract` translates the function to Lean with Charon and
Aeneas and states one obligation per spec; the proofs in [`lean/Proofs/`](lean/Proofs) prove
them; `cargo lean-rust check` records the states in [`lean-rust.lock`](lean-rust.lock).

```rust
#[lean_rust::model(ensures(ge = double::ge))]
pub fn saturating_double(x: u32) -> u32 {
    if x > u32::MAX / 2 { u32::MAX } else { x * 2 }
}
```

The spec `double::ge` is a `Bool` function in a `lean!` block, written in the types of Aeneas's
model (`Std.U32`). The obligation, in `lean/LeanRustGen/Obligation/step_10_ensures.lean`:

```lean
def step_10_ensures.saturating_double.obligation.ge : Prop :=
  ∀ x, step_10_ensures.saturating_double x ⦃ res => _root_.double.ge x res = true ⦄
```

The model returns a `Result`, which fails where the Rust function panics, so the proof also
shows that `x * 2` does not overflow. The proof is three lines in
[`lean/Proofs/SaturatingDouble.lean`](lean/Proofs/SaturatingDouble.lean); `cargo test` also
tests the function against the spec with proptest.

```
make test      # the tests, from the committed caches (no Lean, Charon or Aeneas)
make verify    # cargo lean-rust extract and check again (Charon, Aeneas, Mathlib)
```

Next: [11-prop-specs](../11-prop-specs).
