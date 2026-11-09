/-! Functions and types called through the generated public API by `tests/test_public.py`. -/

namespace LeanPythonTest.Public

def double (n : Nat) : Nat := n + n

def isEven : Nat → Bool
  | 0 => true
  | n + 1 => !isEven n

def negate (i : Int) : Int := -i

def mix (a : UInt8) (b : UInt16) (c : UInt32) (d : UInt64) (e : USize) : UInt64 :=
  a.toUInt64 + b.toUInt64 + c.toUInt64 + d + e.toUInt64

def signed (a : Int8) (b : Int16) (c : Int32) (d : Int64) : Int64 :=
  a.toInt64 + b.toInt64 + c.toInt64 + d

def halve (x : Float) : Float := x / 2

def nextChar (c : Char) : Char := Char.ofNat (c.toNat + 1)

def greet (name : String) : String := s!"こんにちは, {name}! ({name.length})"

def unit (_ : Unit) : Unit := ()

def answer : Nat := 42

def big : Nat := 2 ^ 100

def sumList (xs : List Nat) : Nat := xs.foldl (· + ·) 0

def squares (xs : Array Int) : Array Int := xs.map (fun x => x * x)

def firstEven? (xs : List Nat) : Option Nat := xs.find? (· % 2 == 0)

def swap (p : Nat × String) : String × Nat := (p.2, p.1)

def lastOf (n : Fin 10) : Nat := n.val

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

def Meters.twice (m : Meters) : Meters := ⟨m.val * 2⟩

inductive Color where
  | red | green | blue

def Color.next : Color → Color
  | .red => .green
  | .green => .blue
  | .blue => .red

inductive Shape where
  | circle (radius : Nat)
  | rect (width height : Nat)
  | dot

def Shape.area : Shape → Nat
  | .circle r => 3 * r * r
  | .rect w h => w * h
  | .dot => 0

def Shape.scale (k : Nat) : Shape → Shape
  | .circle r => .circle (k * r)
  | .rect w h => .rect (k * w) (k * h)
  | .dot => .dot

inductive Tree where
  | leaf
  | node (l : Tree) (v : Nat) (r : Tree)

def Tree.insert (t : Tree) (x : Nat) : Tree :=
  match t with
  | .leaf => .node .leaf x .leaf
  | .node l v r => if x < v then .node (l.insert x) v r else .node l v (r.insert x)

def Tree.toList : Tree → List Nat
  | .leaf => []
  | .node l v r => l.toList ++ [v] ++ r.toList

def Tree.ofList (xs : List Nat) : Tree := xs.foldl Tree.insert .leaf

inductive Token where
  | num : Nat → Token
  | pair : Nat → String → Token

def Token.weight : Token → Nat
  | .num n => n
  | .pair n s => n + s.length

structure Range where
  lo : Nat
  hi : Nat
  ok : lo ≤ hi

def Range.width (r : Range) : Nat := r.hi - r.lo

def Range.widen (r : Range) (k : Nat) : Range := ⟨r.lo, r.hi + k, by have := r.ok; omega⟩

inductive Discount where
  | none
  | percent (p : Nat) (h : p ≤ 100)
  | fixed (amount : Nat)

def Discount.apply (d : Discount) (s : Nat) : Nat :=
  match d with
  | .none => s
  | .percent p _ => s - s * p / 100
  | .fixed a => s - a

def small (n : { n : Nat // n < 100 }) : Nat := n.val * 2

def ioEcho (s : String) : IO String := pure (s ++ "!")

def failing (_ : Unit) : IO Nat := throw (IO.userError "nope")

def applyTwice (f : α → α) (x : α) : α := f (f x)

end LeanPythonTest.Public
