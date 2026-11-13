import LeanPythonTest.Bench

def main (args : List String) : IO Unit := do
  let n := args[1]!.toNat!
  let r := match args[0]! with
    | "pushLoop" => LeanPythonTest.Bench.pushLoop n
    | "fib" => LeanPythonTest.Bench.fib n
    | "naiveFib" => LeanPythonTest.Bench.naiveFib n
    | "buildString" => LeanPythonTest.Bench.buildString n
    | _ => LeanPythonTest.Bench.sortList n
  IO.println r
