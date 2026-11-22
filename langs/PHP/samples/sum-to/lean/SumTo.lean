def sumTo (n acc : Nat) : Nat :=
  if n = 0 then acc else sumTo (n - 1) (acc + n)
