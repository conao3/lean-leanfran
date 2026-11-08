# 08-polymorphic

A polymorphic Lean function is compiled for the types named by `rust_instances`, and becomes
one generic Rust function.

```lean
def largest {α : Type} [Ord α] [Inhabited α] (xs : List α) : α :=
  xs.foldl (fun a b => if compare a b == .lt then b else a) default

rust_instances largest [Nat, String]
```

`sorting::largest::<T>` accepts `Nat` and `String` only (another type is a rustc error), and the
instantiations are also functions of their own (`largest_inst_nat`, `largest_inst_string`).

Next: [09-lake-project](../09-lake-project).
