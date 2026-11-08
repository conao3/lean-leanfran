namespace Stats

/-- The mean of `xs`, rounded down (0 for no values). -/
def mean (xs : List Nat) : Nat := if xs.isEmpty then 0 else xs.sum / xs.length

theorem mean_nil : mean [] = 0 := rfl

end Stats
