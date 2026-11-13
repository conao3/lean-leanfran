# 01-functions

The smallest use of `lean!`: a block of Lean definitions in a Rust file becomes a Rust module.

```rust
leanfran::lean! {
    pub mod basics;
    r#"
    def double (n : Nat) : Nat := 2 * n
    def isEven (n : UInt64) : Bool := n % 2 == 0
    def greet (name : String) : String := s!"Hello, {name}!"
    "#
}
```

| Lean | Rust |
|---|---|
| `double (n : Nat) : Nat` | `basics::double(n: Nat) -> Nat` (`leanfran::Nat`, arbitrary precision) |
| `isEven (n : UInt64) : Bool` | `basics::is_even(n: u64) -> bool` |
| `greet (name : String) : String` | `basics::greet(name: impl AsRef<str>) -> String` |

Names become snake_case. The build script ([`build.rs`](build.rs)) runs Lean when
`.leanfran/cache/` has no module for the block, and writes the module there; commit the cache
(and `lean/LeanRustGen/`), and the crate builds without Lean.

```
make test
```

Next: [02-theorems](../02-theorems).
