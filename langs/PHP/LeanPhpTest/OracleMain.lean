import LeanPhpTest.Vectors

def main (args : List String) : IO UInt32 := do
  if args == ["twice"] then
    let first ← LeanPhpTest.Vectors.run ["first"]
    if first != 0 then return first
    LeanPhpTest.Vectors.run ["second"]
  else
    LeanPhpTest.Vectors.run args
