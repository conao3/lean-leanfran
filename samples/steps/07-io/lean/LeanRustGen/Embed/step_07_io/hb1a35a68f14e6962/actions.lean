namespace actions

def appendLine (path line : String) : IO Unit := do
  let h ← IO.FS.Handle.mk path .append
  h.putStrLn line

def countLines (path : String) : IO Nat := do
  return (← IO.FS.lines path).size

def runEcho (word : String) : IO String := do
  return (← IO.Process.run { cmd := "echo", args := #[word] }).trimAsciiEnd.toString

def countTo (n : Nat) : IO Nat := do
  let r ← IO.mkRef 0
  for _ in [0:n] do
    r.modify (· + 1)
  r.get

def checkPositive (n : Int) : IO Int := do
  if n ≤ 0 then throw (IO.userError s!"not positive: {n}")
  return n

end actions
