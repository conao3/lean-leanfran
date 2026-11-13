import Aeneas
namespace calendar

open Aeneas Aeneas.Std

/-- The rule of the Gregorian calendar. -/
def leap (y : Std.U32) : Bool :=
  y.val % 4 = 0 ∧ (y.val % 100 ≠ 0 ∨ y.val % 400 = 0)

end calendar
