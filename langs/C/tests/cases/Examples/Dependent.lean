namespace Dependent

def safeHalf (n : Nat) : { m : Nat // m ≤ n } := ⟨n / 2, Nat.div_le_self n 2⟩

def lastIndex (n : Nat) (i : Fin (n + 1)) : Nat := i.val

def half (n : Nat) : Nat := n / 2

end Dependent
