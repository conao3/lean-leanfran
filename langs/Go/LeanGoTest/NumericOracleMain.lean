import LeanGoTest.NumericOracle

namespace NumericOracle

def run (dispatch : Nat → List String → Option String) : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let fields := line.trimAscii.toString.splitOn "\t"
    let output := match fields with
      | index :: _ :: args => index.toNat?.bind fun i => dispatch i args
      | _ => none
    match output with
    | some output => stdout.putStrLn output
    | none => throw <| IO.userError s!"invalid numeric test input: {line}"

end NumericOracle
