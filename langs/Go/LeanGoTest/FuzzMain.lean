import LeanGoTest.Fuzz

def main : IO Unit := do
  let input ← IO.getStdin
  let output ← IO.getStdout
  let mut number := 0
  repeat
    let line ← input.getLine
    if line.isEmpty then break
    number := number + 1
    let row := if line.endsWith "\n" then (line.dropEnd 1).toString else line
    let some result := LeanGoTest.Fuzz.evalRow row |
      throw (IO.userError s!"Invalid fuzz input on line {number}: {row}")
    output.putStrLn result
