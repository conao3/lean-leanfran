# 07-io

An `IO α` action is a Rust function returning `std::io::Result<T>`. Lean's `IO.Error` becomes a
`std::io::Error` with Lean's message (`IO.Error.toString`) and a matching `ErrorKind`.

| Lean | Rust |
|---|---|
| `appendLine (path line : String) : IO Unit` (`IO.FS.Handle.mk path .append`) | `append_line(path, line) -> io::Result<()>` |
| `countLines (path : String) : IO Nat` (`IO.FS.lines`) | `count_lines(path) -> io::Result<Nat>` |
| `runEcho (word : String) : IO String` (`IO.Process.run`) | `run_echo(word) -> io::Result<String>` |
| `countTo (n : Nat) : IO Nat` (an `IO.Ref` counter) | `count_to(n) -> io::Result<Nat>` |
| `checkPositive (n : Int) : IO Int` (`throw (IO.userError ..)`) | `check_positive(n) -> io::Result<Int>` |

A missing file is `ErrorKind::NotFound` with the message
`no such file or directory (error code: 2)\n  file: <path>`, as Lean's C runtime reports it.

Next: [08-polymorphic](../08-polymorphic).
