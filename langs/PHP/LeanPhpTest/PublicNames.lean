namespace LeanPhpTest.PublicNames

structure List where
  value : Nat

structure Name where
  value : Bool

structure name where
  value : Nat

inductive Read where
  | «class»
  | lower
  | Lower

def do_thing (n : Nat) : Nat := n + 1

def do_Thing (n : Nat) : Nat := n + 2

def «class» (l : List) : Nat := l.value

def Names.prime' (n : Nat) : Nat := n

end LeanPhpTest.PublicNames
