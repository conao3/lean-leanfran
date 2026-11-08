namespace basics

def double (n : Nat) : Nat := 2 * n

def isEven (n : UInt64) : Bool := n % 2 == 0

def greet (name : String) : String := s!"Hello, {name}!"

end basics
