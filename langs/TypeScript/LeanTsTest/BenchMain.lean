import LeanTsTest.Bench

def main (args : List String) : IO Unit := do
  let n := args[1]!.toNat!
  let r := match args[0]! with
    | "pushLoop" => LeanTsTest.Bench.pushLoop n
    | "fib" => LeanTsTest.Bench.fib n
    | "naiveFib" => LeanTsTest.Bench.naiveFib n
    | "buildString" => LeanTsTest.Bench.buildString n
    | _ => LeanTsTest.Bench.sortList n
  IO.println r
