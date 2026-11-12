namespace funcs

def fib : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => fib n + fib (n + 1)
decreasing_by all_goals omega

def fastFib (n : Nat) : Nat := Id.run do
  let mut (a, b) := (0, 1)
  for _ in [0:n] do
    (a, b) := (b, a + b)
  return a

def greet (names : List String) : String :=
  ", ".intercalate (names.map (s!"Hello, {·}!"))

def sortDesc (xs : Array Int) : Array Int := xs.qsort (· > ·)

def headOr (xs : List Nat) : Nat := xs.head!

def addInt (a b : Int) : Int := a + b

def mix (x : UInt64) : UInt64 := x * 0x9e3779b97f4a7c15 + 1

def half (x : Float) : String := toString (x / 2)

def readFile (path : String) : IO String := IO.FS.readFile path

end funcs
