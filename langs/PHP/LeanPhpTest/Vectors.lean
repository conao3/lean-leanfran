import LeanPhpTest.ControlIr

namespace LeanPhpTest.Vectors

initialize seedValue : Nat ← do
  IO.eprintln "initialize seed"
  return 5

initialize
  IO.eprintln s!"initialize ready {seedValue}"

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

@[noinline] def selectValue {α : Type} (yes no : α) (test : Bool) : α :=
  if test then yes else no

@[noinline] def upper (n : Nat) : Nat := n + 2
@[noinline] def Upper (n : Nat) : Nat := n * 3

@[noinline] def arrayLine (a : Array Nat) (n : Nat) : String :=
  let pushed := a.push n
  let updated := a.set! 0 (n + 1)
  s!"array {a[0]!}/{a.size} {pushed[0]!}/{pushed[1]!}/{pushed.size} {updated[0]!}/{updated.size}"

@[noinline] def stringLine (s t : String) : String :=
  let appended := s ++ t
  let pushed := s.push '!'
  s!"string {s} {appended} {appended.length}/{appended.utf8ByteSize} {pushed}"

@[noinline] def utf8Line (s : String) (byte : Nat) : String :=
  let start : String.Pos.Raw := ⟨byte⟩
  let next := start.next s
  let middle : String.Pos.Raw := ⟨byte + 1⟩
  s!"utf8 {s.length}/{s.utf8ByteSize} {start.byteIdx}:{start.get s} {next.byteIdx} {(next.prev s).byteIdx} {repr (middle.get? s)}"

@[noinline] def thunkLine (n : Nat) : Nat :=
  let t := Thunk.mk fun _ => n + 7
  t.get + t.get

@[noinline] def natLine (big : Nat) : String :=
  let limit := big - 2
  s!"nat {big + 5} {big * 2} {limit} {big % 10} {limit + 1}"

@[noinline] def integerLine (limit : Nat) (wide : UInt64) (a b : Int) (zeroDivisor : Nat) : String :=
  let nat := s!"nat {limit - 1} {limit} {limit + 1} {limit / zeroDivisor} {limit % zeroDivisor}"
  let uint := s!"uint64 {wide.toNat} {(wide + 1).toNat} {(wide / 3).toNat}"
  let int := s!"int {a / b} {a % b} {a / Int.ofNat zeroDivisor} {a % Int.ofNat zeroDivisor}"
  s!"integers {nat}; {uint}; {int}"

@[noinline] def libmLine (zero large : Float) (single : Float32) : String :=
  s!"libm {zero.sin} {single.sin} {large.log2} {large.cbrt}"

@[noinline] def run (args : List String) : IO UInt32 := do
  match args with
  | ["fail"] => throw (IO.userError "requested failure")
  | ["status"] =>
    IO.eprintln "explicit exit status"
    return 23
  | [text] => IO.println s!"argument {text} (seed {seedValue})"
  | _ => pure ()
  IO.println (natLine 9223372036854775809)
  IO.println (integerLine 9223372036854775807 0xffffffffffffffff (-7) 3 0)
  IO.println (libmLine 0.0 8.0 0.0)
  IO.println s!"case {shapeValue .empty} {shapeValue (retag (.point 2 5))} {shapeValue (retag (.named "猫"))} {shapeValue (retag (.pixel 9))} {boundsValue ⟨1, 2, 4, 8⟩}"
  IO.println (arrayLine #[3] 9)
  IO.println (stringLine "é" "🌱$name")
  IO.println (utf8Line "é🌱" 2)
  let partiallyApplied := applyOne (addThree 1) 2
  let oversaturated := applyTwo (selectValue (addThree 4 5) (addThree 7 8)) false 6
  IO.println s!"closures {applyOne partiallyApplied 3} {applyTwo (chooseClosure 7) false 6} {oversaturated}"
  IO.println s!"case names {upper 7} {Upper 7}"
  IO.println s!"tail {sumTo 101 0} {alternate 101 10 20}"
  IO.println s!"thunk {thunkLine 5}"
  ControlIr.run (args.head?.getD "control")
  return 0

end LeanPhpTest.Vectors
