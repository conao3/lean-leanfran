namespace collections

def evens (xs : List Nat) : List Nat := xs.filter (· % 2 == 0)

def indexed (xs : Array String) : List (Nat × String) := xs.toList.zipIdx.map fun (s, i) => (i, s)

def firstLong (xs : List String) (n : Nat) : Option String := xs.find? (·.length ≥ n)

def safeDiv (a b : Int) : Except String Int :=
  if b == 0 then .error "division by zero" else .ok (a / b)

end collections
