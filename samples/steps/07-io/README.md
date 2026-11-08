# 07-io

An `IO α` action is a Rust function returning `std::io::Result<T>`; `throw` in Lean is an
`Err` whose message is Lean's.

| Lean | Rust |
|---|---|
| `countTo (n : Nat) : IO Nat` (an `IO.Ref` counter) | `count_to(n) -> io::Result<Nat>` |
| `report (name : String) (score : Nat) : IO Unit` (`IO.println`) | `report(name, score) -> io::Result<()>` |
| `checkPositive (n : Int) : IO Int` (`throw (IO.userError ..)`) | `check_positive(n) -> io::Result<Int>` |

The runtime implements the standard streams, references, the clock and tasks.

Next: [08-polymorphic](../08-polymorphic).
