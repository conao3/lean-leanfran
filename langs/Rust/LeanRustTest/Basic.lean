namespace LeanRustTest.Basic

def double (n : Nat) : Nat := n + n

theorem double_eq (n : Nat) : double n = 2 * n := by
  unfold double; omega

def sumTo : Nat → Nat
  | 0 => 0
  | n + 1 => (n + 1) + sumTo n

def sumAcc (acc : Nat) : Nat → Nat
  | 0 => acc
  | n + 1 => sumAcc (acc + n + 1) n

theorem sumAcc_eq (acc n : Nat) : sumAcc acc n = acc + sumTo n := by
  induction n generalizing acc with
  | zero => simp [sumAcc, sumTo]
  | succ n ih =>
    simp only [sumAcc, sumTo, ih]
    omega

def isEven : Nat → Bool
  | 0 => true
  | n + 1 => !isEven n

mutual
def parityEven : Nat → Bool
  | 0 => true
  | n + 1 => parityOdd n
def parityOdd : Nat → Bool
  | 0 => false
  | n + 1 => parityEven n
end

structure Point where
  x : Nat
  y : Int
  deriving Repr

def Point.add (p q : Point) : Point := ⟨p.x + q.x, p.y + q.y⟩

def listMapSum (xs : List Nat) : Nat := (xs.map (· * 3)).foldl (· + ·) 0

def greet (name : String) : String := s!"hello, {name}! ({name.length})"

def arrSquares (n : Nat) : Array Nat := Id.run do
  let mut a := #[]
  for i in [0:n] do
    a := a.push (i * i)
  return a

def firstEven? (xs : List Nat) : Option Nat := xs.find? (· % 2 == 0)

theorem firstEven?_eq_none_iff (xs : List Nat) :
    firstEven? xs = none ↔ ∀ x ∈ xs, x % 2 ≠ 0 := by
  simp [firstEven?]

def u64wrap (a b : UInt64) : UInt64 := a * b + 7

def classify (n : Int) : String :=
  if n < 0 then "neg" else if n == 0 then "zero" else "pos"

end LeanRustTest.Basic
