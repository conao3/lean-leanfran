# 17-generics

A generic function is proved once for every type, and tested with the types of `instances`.

```rust
#[lean_rust::model(instances = [u32, i64], requires = range::ordered, ensures(within = range::within))]
pub fn clamp<T: Ord + Copy>(x: T, lo: T, hi: T) -> T { .. }
```

The specs are polymorphic over a `LinearOrder`, and `rust_instances` (08-polymorphic) compiles
them for the model types of the instances. The obligation assumes that Aeneas's `Ord`
structure obeys the laws of the order:

```lean
∀ {T : Type} [LinearOrder T] (corecmpOrdInst : core.cmp.Ord T) [LeanRust.OrdModel corecmpOrdInst]
  (coremarkerCopyInst : core.marker.Copy T), ∀ x lo hi, ..
```

The `@[step]` lemmas of `OrdModel` turn the comparisons into `decide (x < lo)`, and
[`lean/Proofs/Clamp.lean`](lean/Proofs/Clamp.lean) is `step*`.

This is the last step. The [samples](../..) combine these pieces into larger programs.
