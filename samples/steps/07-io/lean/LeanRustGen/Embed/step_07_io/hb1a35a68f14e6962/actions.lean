namespace actions

def countTo (n : Nat) : IO Nat := do
  let r ← IO.mkRef 0
  for _ in [0:n] do
    r.modify (· + 1)
  r.get

def report (name : String) (score : Nat) : IO Unit :=
  IO.println s!"{name}: {score}"

def checkPositive (n : Int) : IO Int := do
  if n ≤ 0 then throw (IO.userError s!"not positive: {n}")
  return n

end actions
