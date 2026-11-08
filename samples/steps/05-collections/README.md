# 05-collections

The standard containers of Lean have their Rust counterparts:

| Lean | Rust | In this step |
|---|---|---|
| `List α`, `Array α` | `Vec<T>` | `evens`, `indexed` |
| `α × β` | `(A, B)` | `indexed` returns `Vec<(Nat, String)>` |
| `Option α` | `Option<T>` | `firstLong` |
| `Except ε α` | `Result<T, E>` | `safeDiv` returns `Result<Int, String>` |

Next: [06-imports](../06-imports).
