namespace LeanPhpTest.Vectors

initialize seedValue : Nat ← do
  IO.eprintln "initialize seed"
  return 5

initialize
  IO.eprintln "initialize ready"

inductive Shape
  | empty
  | point (atX atY : Nat)
  | named (name : String)
  | pixel (color : UInt32)

structure Bounds where
  lo : Nat
  hi : Nat
  flags : UInt8
  size : USize

@[noinline] def shapeValue : Shape → Nat
  | .empty => 1
  | .point x y => x + y
  | .named name => name.length
  | .pixel color => color.toNat

@[noinline] def boundsValue (b : Bounds) : Nat :=
  b.lo + b.hi + b.flags.toNat + b.size.toNat

@[noinline] def retag : Shape → Shape
  | .empty => .empty
  | .point x y => .point y x
  | .named s => .named (s.push '!')
  | .pixel c => .pixel (c + 1)

@[noinline] def sumTo (n acc : Nat) : Nat :=
  if n = 0 then acc else sumTo (n - 1) (acc + n)

@[noinline] def alternate (n first second : Nat) : Nat :=
  if n = 0 then first else alternate (n - 1) second first

@[noinline] def addThree (a b c : Nat) : Nat :=
  a + 10 * b + 100 * c

@[noinline] def applyOne {α β : Type} (f : α → β) (a : α) : β := f a

@[noinline] def chooseClosure (a : Nat) (byAddition : Bool) : Nat → Nat :=
  if byAddition then fun b => a + b else fun b => a * b

@[noinline] def applyTwo (f : Bool → Nat → Nat) (b : Bool) (n : Nat) : Nat := f b n

@[noinline] def upper (n : Nat) : Nat := n + 2
@[noinline] def Upper (n : Nat) : Nat := n * 3

@[noinline] def arrayLine (a : Array Nat) (n : Nat) : String :=
  let b := (a.push n).set! 0 (n + 1)
  s!"array {a[0]!}/{a.size} {b[0]!}/{b[1]!}/{b.size}"

@[noinline] def stringLine (s t : String) : String :=
  let u := (s ++ t).push '!'
  s!"string {s} {u} {u.length}/{u.utf8ByteSize}"

@[noinline] def thunkLine (n : Nat) : Nat :=
  let t := Thunk.mk fun _ => n + 7
  t.get + t.get

@[noinline] def natLine (big : Nat) : String :=
  let limit := big - 2
  s!"nat {big + 5} {big * 2} {limit} {big % 10} {limit + 1}"

@[noinline] def libmLine (zero large : Float) (single : Float32) : String :=
  s!"libm {zero.sin} {single.sin} {large.log2} {large.cbrt}"

@[noinline] def run (args : List String) : IO UInt32 := do
  match args with
  | ["fail"] => throw (IO.userError "requested failure")
  | [text] => IO.println s!"argument {text} (seed {seedValue})"
  | _ => pure ()
  IO.println (natLine 9223372036854775809)
  IO.println (libmLine 0.0 8.0 0.0)
  IO.println s!"case {shapeValue .empty} {shapeValue (retag (.point 2 5))} {shapeValue (retag (.named "猫"))} {shapeValue (retag (.pixel 9))} {boundsValue ⟨1, 2, 4, 8⟩}"
  IO.println (arrayLine #[3] 9)
  IO.println (stringLine "é" "🌱$name")
  let partiallyApplied := applyOne (addThree 1) 2
  IO.println s!"closures {applyOne partiallyApplied 3} {applyTwo (chooseClosure 7) false 6}"
  IO.println s!"case names {upper 7} {Upper 7}"
  IO.println s!"tail {sumTo 1000000 0} {alternate 1000001 10 20}"
  IO.println s!"thunk {thunkLine 5}"
  return 0

end LeanPhpTest.Vectors
