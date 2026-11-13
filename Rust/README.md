# Rust

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) for Rust: write Lean blocks with `lean!`, call them through Rust types, and verify supported Rust functions against Lean specifications.

## Install

Install the Lean compiler and verification tools:

```sh
nix profile install 'github:conao3/lean-leanfran#rust'
```

Generation requires Lean 4.35.0 (`lean` and `lake`) on `PATH`. Add these dependencies to your crate:

```toml
[dependencies]
leanfran = "0.6.0"

[build-dependencies]
leanfran-build = "0.6.0"
```

## First Lean block

Add `build.rs`:

```rust
fn main() {
    leanfran_build::Builder::new().compile().unwrap();
}
```

Then add a block to `src/main.rs`:

```rust
leanfran::lean! {
    pub mod arith;
    r#"
    def double (n : Nat) : Nat := n + n

    theorem double_eq (n : Nat) : double n = 2 * n := by
      unfold double; omega
    "#
}

fn main() {
    assert_eq!(arith::double(21u64.into()), 42u64.into());
}
```

`cargo build` checks the Lean source and generates Rust. Commit `lean/` and `.leanfran/cache/` so subsequent builds can use the generated code. See the guide for publishing a crate with its cache.

## Next steps

- [Full Rust guide](https://github.com/conao3/lean-leanfran/blob/master/docs/rust-guide.md): value conversions, Lean projects, `#[model]`, Cargo verification, WebAssembly and limitations.
- [Samples](https://github.com/conao3/lean-leanfran/blob/master/Rust/samples/README.md) and [step-by-step examples](https://github.com/conao3/lean-leanfran/blob/master/Rust/samples/steps/README.md).
- [Development](https://github.com/conao3/lean-leanfran/blob/master/CONTRIBUTING.md) and [implementation notes](https://github.com/conao3/lean-leanfran/blob/master/docs/rust-development.md).
