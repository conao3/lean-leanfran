/-! IO actions and closures over more than 16 arguments, run by `oracle-io` and by the
generated Rust (`lean-rust-difftest-io`). -/

namespace LeanRustTest.Io

@[noinline] def sum17 (a b c d e f g h i j k l m n o p q : UInt8) : Nat :=
  [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q].foldl (· + ·.toNat) 0

@[noinline] def apply15 (f : UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 →
    UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → Nat) (x : UInt8) : Nat :=
  f x x x x x x x x x x x x x x x

def wide (n : UInt8) : List Nat :=
  let f := sum17 n 1
  [apply15 f 2, apply15 (sum17 0 0) 3, apply15 f 255]

def run : IO Unit := do
  let out ← IO.getStdout
  out.putStrLn "stream: hello"
  out.flush
  IO.println s!"wide: {wide 10}"
  let r ← IO.mkRef 3
  r.modify (· + 4)
  IO.println s!"ref: {← r.get}"
  let old ← r.swap 9
  IO.println s!"swap: {old} {← r.get}"
  let t ← IO.monoMsNow
  let t' ← IO.monoNanosNow
  IO.println s!"clock: {decide (t > 0)} {decide (t' > 0)}"
  let line ← (← IO.getStdin).getLine
  IO.println s!"stdin: {line.length}"
  IO.eprintln "to stderr"
  try
    throw (IO.userError "boom")
  catch e =>
    IO.println s!"caught: {e}"
  let task ← IO.asTask (pure 5)
  IO.println s!"task: {task.get.toOption}"
  (← IO.getStderr).putStrLn "stream: stderr"

end LeanRustTest.Io
