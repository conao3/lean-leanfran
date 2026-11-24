namespace LeanGoTest.Allocations

structure Order where
  qty : Nat
  price : Nat
  ok : qty ≤ 100

def twice (n : Nat) : Nat := n + n

def total (o : Order) : Nat := o.qty * o.price

def sumList (xs : List Nat) : Nat := xs.foldl (· + ·) 0

def add64 (a b : UInt64) : UInt64 := a + b

def natEcho (n : Nat) : Nat := n

def intEcho (n : Int) : Int := n

end LeanGoTest.Allocations
