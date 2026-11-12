# 06-imports

`#[lean(imports = [..])]` imports Lean modules into the block. Here `Std.Data.HashSet` serves
`dedup` and `duplicates`, written with `do` notation and mutable variables (`Id.run do`).

```rust
lean_rust::lean! {
    #[lean(imports = ["Std.Data.HashSet"])]
    pub mod dedup;
    r#"
    def dedup (xs : List String) : List String := Id.run do
      let mut seen : Std.HashSet String := {}
      ...
    "#
}
```

The hash set stays inside Lean: the functions take and return `Vec<String>`.

Next: [07-io](../07-io).
