# 12-requires

`requires` adds an assumption to every obligation, and the tests draw only arguments that
satisfy it.

```rust
#[lean_rust::model(requires = mid::ordered, ensures(between = mid::between))]
pub fn midpoint(lo: u32, hi: u32) -> u32 {
    lo + (hi - lo) / 2
}
```

```lean
def step_12_requires.midpoint.obligation.between : Prop :=
  ∀ lo hi, _root_.mid.ordered lo hi = true →
    step_12_requires.midpoint lo hi ⦃ res => _root_.mid.between lo hi res = true ⦄
```

Without the assumption the obligation is false: `hi - lo` panics when `hi < lo`.

Next: [13-refines](../13-refines).
