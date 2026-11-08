namespace Stats

/-- The middle value of `xs` once sorted (the upper one of an even count), `none` for no values. -/
def median (xs : List Nat) : Option Nat :=
  let s := xs.mergeSort
  s[s.length / 2]?

theorem median_nil : median [] = none := by simp [median]

end Stats
