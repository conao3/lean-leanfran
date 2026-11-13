# 09-lake-project

A lake project instead of a `lean!` block: [`lean/`](lean) is an ordinary Lean library with the
modules `Stats.Mean` and `Stats.Median`, and `leanfran project generate` writes a Rust module
per Lean module to [`src/generated/`](src/generated), which is committed. Building the crate
needs no Lean.

```
make generate   # lake build (the proofs included), then the Rust modules
make test       # regenerate, check that src/generated/ is unchanged, cargo test
```

The functions keep their full Lean names when the namespace (`Stats`) differs from the
module (`Stats.Mean`): `Stats.mean` is `stats_mean::stats_mean`.

Next: [10-ensures](../10-ensures), the first step of verifying Rust functions.
