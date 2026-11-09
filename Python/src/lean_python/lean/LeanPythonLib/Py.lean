/-! The meaning of the Python operations the translated functions use (`lean-py check`).

Failing operations (indexing, `//`, `%`, `assert`, `raise`) return `Py.M α = Except Py.Exc α`.
Python's `int` is `Int`; `//` and `%` round towards negative infinity (`Int.fdiv`, `Int.fmod`). -/

namespace Py

/-- The exceptions of the translated functions. -/
inductive Exc where
  | indexError
  | zeroDivisionError
  | assertionError
  | valueError (msg : String)
  deriving Repr, DecidableEq

abbrev M := Except Exc

/-- `xs[i]`, with Python's negative indices. -/
def getItem (xs : List α) (i : Int) : M α :=
  let j := if i < 0 then i + xs.length else i
  if 0 ≤ j then
    match xs[j.toNat]? with
    | some v => pure v
    | none => throw .indexError
  else throw .indexError

/-- `a // b`. -/
def floordiv (a b : Int) : M Int := if b = 0 then throw .zeroDivisionError else pure (Int.fdiv a b)

/-- `a % b`. -/
def mod (a b : Int) : M Int := if b = 0 then throw .zeroDivisionError else pure (Int.fmod a b)

/-- `range(a, b)`. -/
def range (a b : Int) : List Int := (List.range (b - a).toNat).map fun (k : Nat) => a + (k : Int)

def abs (a : Int) : Int := if a < 0 then -a else a

def len (xs : List α) : Int := xs.length

def strLen (s : String) : Int := s.length

def sum (xs : List Int) : Int := xs.foldl (· + ·) 0

def assert (c : Bool) : M Unit := if c then pure () else throw .assertionError

@[simp] theorem range_mem (a b i : Int) : i ∈ range a b ↔ a ≤ i ∧ i < b := by
  simp only [range, List.mem_map, List.mem_range]
  constructor
  · rintro ⟨k, hk, rfl⟩; omega
  · intro h; exact ⟨(i - a).toNat, by omega, by omega⟩

end Py
