import LeanPhpTest.NumericOracle

namespace NumericOracle

def run (dispatch : List String → Option String) : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let fields := line.trimAscii.toString.splitOn "\t"
    match dispatch fields with
    | some output => stdout.putStrLn output
    | none => throw <| IO.userError s!"invalid numeric test input: {line}"

end NumericOracle
