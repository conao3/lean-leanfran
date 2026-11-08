/-! Functions called through the generated public API by the `tests/public` crate. -/

namespace LeanRustTest.Public

def double (n : Nat) : Nat := n + n

def isEven : Nat → Bool
  | 0 => true
  | n + 1 => !isEven n

def negate (i : Int) : Int := -i

def mix (a : UInt8) (b : UInt16) (c : UInt32) (d : UInt64) (e : USize) : UInt64 :=
  a.toUInt64 + b.toUInt64 + c.toUInt64 + d + e.toUInt64

def signed (a : Int8) (b : Int16) (c : Int32) (d : Int64) (e : ISize) : Int64 :=
  a.toInt64 + b.toInt64 + c.toInt64 + d + e.toInt64

def halve (x : Float) : Float := x / 2

def halve32 (x : Float32) : Float32 := x / 2

def nextChar (c : Char) : Char := Char.ofNat (c.toNat + 1)

def greet (name : String) : String := s!"こんにちは, {name}! ({name.length})"

def unit (_ : Unit) : Unit := ()

def answer : Nat := 42

def big : Nat := 2 ^ 100

structure Point where
  x : Nat
  y : Int
  deriving Repr, DecidableEq

def Point.add (p q : Point) : Point := ⟨p.x + q.x, p.y + q.y⟩

structure Sample where
  name : String
  count : UInt32
  weight : Float
  flag : Bool
  tags : List String

def Sample.describe (s : Sample) : String :=
  s!"{s.name}:{s.count}:{s.weight}:{s.flag}:{s.tags}"

def Sample.bump (s : Sample) : Sample := { s with count := s.count + 1, flag := !s.flag }

structure Meters where
  val : UInt64
  deriving DecidableEq

def Meters.twice (m : Meters) : Meters := ⟨m.val * 2⟩

inductive Color where
  | red | green | blue
  deriving DecidableEq

def Color.next : Color → Color
  | .red => .green
  | .green => .blue
  | .blue => .red

inductive Shape where
  | circle (radius : Nat)
  | rect (width height : Nat)
  | dot
  deriving DecidableEq

def Shape.area : Shape → Nat
  | .circle r => 3 * r * r
  | .rect w h => w * h
  | .dot => 0

inductive Tree where
  | leaf
  | node (left : Tree) (value : Nat) (right : Tree)

def Tree.insert (t : Tree) (x : Nat) : Tree :=
  match t with
  | .leaf => .node .leaf x .leaf
  | .node l v r => if x < v then .node (l.insert x) v r else .node l v (r.insert x)

def Tree.toList : Tree → List Nat
  | .leaf => []
  | .node l v r => l.toList ++ [v] ++ r.toList

def Tree.ofList (xs : List Nat) : Tree := xs.foldl Tree.insert .leaf

def sumList (xs : List Nat) : Nat := xs.foldl (· + ·) 0

def evens (xs : Array Int) : Array Int := xs.filter (· % 2 == 0)

def find? (xs : List Nat) (p : Nat) : Option Nat := xs.find? (· > p)

def safeDiv (a b : Nat) : Except String Nat :=
  if b == 0 then .error "division by zero" else .ok (a / b)

def swap (p : Nat × String) : String × Nat := (p.2, p.1)

def pick (i : Fin 3) : String := #["zero", "one", "two"][i]

def lastIndex (n : Nat) : Fin (n + 1) := Fin.last n

def hello (name : String) : IO Nat := do
  IO.println s!"hello from Lean, {name}"
  return name.length

def failing (code : Nat) : IO Unit := do
  if code > 0 then throw (IO.userError s!"failed with {code}")

def counter : IO Nat := do
  let r ← IO.mkRef 0
  for _ in [0:5] do r.modify (· + 2)
  r.get

def slowLength (xs : List Nat) : Nat := xs.foldl (fun n _ => n + 1) 0

def fastLength (xs : List Nat) : Nat := xs.length * 1

@[csimp] theorem slowLength_eq : @slowLength = @fastLength := by
  funext xs
  simp only [slowLength, fastLength, Nat.mul_one]
  suffices ∀ n, List.foldl (fun n _ => n + 1) n xs = n + xs.length by simp [this 0]
  induction xs with
  | nil => simp
  | cons _ _ ih => intro n; simp [ih]; omega

def withInst [inst : Inhabited Nat] (n : Nat) : Nat := n + inst.default

def generic {α : Type} (xs : List α) : Nat := xs.length

def compose (f : Nat → Nat) (x : Nat) : Nat := f (f x)

def positive : { n : Nat // n > 0 } := ⟨1, by decide⟩

def «type» (n : Nat) : Nat := n

def first! (xs : List Nat) : Nat := xs.head!

def double' (n : Nat) : Nat := 2 * n

end LeanRustTest.Public
