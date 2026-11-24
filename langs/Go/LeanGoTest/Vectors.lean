import LeanGoTest.ControlIr
import LeanGoTest.VectorInit

namespace LeanGoTest.Vectors

inductive Sample where
  | empty
  | number (value : Nat)
  | point (x y : UInt64)

@[noinline]
def readSample : Sample → Nat
  | .empty => 0
  | .number n => n
  | .point x y => (x + y).toNat

@[noinline]
def sumTo (n acc : Nat) : Nat :=
  if n = 0 then acc else sumTo (n - 1) (acc + n)
termination_by n

mutual
  @[noinline]
  partial def even (n : UInt64) : Bool :=
    if n = 0 then true else odd (n - 1)

  @[noinline]
  partial def odd (n : UInt64) : Bool :=
    if n = 0 then false else even (n - 1)
end

@[noinline]
def add (a b : Nat) : Nat := a + b

@[noinline]
def partialAdd (a : Nat) : Nat → Nat := add a

@[noinline]
def apply (f : Nat → Nat) (x : Nat) : Nat := f x

@[noinline]
def updateArray (xs : Array Nat) : Array Nat :=
  (xs.push 30).set! 0 40

@[noinline]
def updateString (s : String) : String := (s.push '界').append "!"

@[noinline]
def intArithmetic (x : Int) : Bool := (x - 10) * 2 == -34

@[noinline]
def floatArithmetic (x y : UInt64) : Bool := x.toFloat * y.toFloat + x.toFloat == 16

initialize first : String ← do
  IO.eprintln s!"initialize first (initializing: {← IO.initializing}, seed: {LeanGoTest.VectorInit.seed})"
  pure "first"

initialize second : String ← do
  IO.eprintln s!"initialize second: {first}"
  pure (first ++ ":second")

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

@[noinline] def integerLine (limit : Nat) (wide : UInt64) (a b : Int) (zeroDivisor : Nat) : String :=
  let nat := s!"nat {limit - 1} {limit} {limit + 1} {limit / zeroDivisor} {limit % zeroDivisor}"
  let uint := s!"uint64 {wide.toNat} {(wide + 1).toNat} {(wide / 3).toNat}"
  let int := s!"int {a / b} {a % b} {a / Int.ofNat zeroDivisor} {a % Int.ofNat zeroDivisor}"
  s!"integers {nat}; {uint}; {int}"

@[noinline] def libmLine (zero large : Float) (single : Float32) : String :=
  s!"libm {zero.sin} {single.sin} {large.log2} {large.cbrt}"

def run (args : List String) : IO UInt32 := do
  match args with
  | ["status"] =>
    IO.eprintln "requested status"
    return 23
  | ["fail"] => throw (IO.userError "requested failure")
  | _ =>
    IO.println second
    IO.println s!"main initializing: {← IO.initializing}"
    IO.println (sumTo 1000 0)
    IO.println (even 1001)
    IO.println (odd 1001)
    IO.println (readSample .empty)
    IO.println (readSample (.number 11))
    IO.println (readSample (.point 19 23))
    IO.println (apply (partialAdd 12) 34)
    let xs := #[10, 20]
    let ys := updateArray xs
    IO.println (xs[0]?.getD 0)
    IO.println (ys[0]?.getD 0)
    IO.println ys.size
    let s := "Go"
    IO.println (updateString s)
    IO.println s
    let big := 18446744073709551616
    IO.println (add big 123)
    IO.println (intArithmetic (-7))
    IO.println (floatArithmetic 4 3)
    IO.println (integerLine 9223372036854775807 0xffffffffffffffff (-7) 3 0)
    IO.println (integerLine 9223372036854775808 0xffffffffffffffff (-7) (-3) 0)
    IO.println (libmLine 0.0 8.0 0.0)
    IO.println (arrayLine #[3] 9)
    IO.println (stringLine "é" "🌱$name")
    IO.println (utf8Line "é🌱" 2)
    let partiallyApplied := applyOne (addThree 1) 2
    let oversaturated := applyTwo (selectValue (addThree 4 5) (addThree 7 8)) false 6
    IO.println s!"closures {applyOne partiallyApplied 3} {applyTwo (chooseClosure 7) false 6} {oversaturated}"
    IO.println s!"case names {upper 7} {Upper 7}"
    IO.println s!"thunk {thunkLine 5}"
    LeanGoTest.ControlIr.run second
    return 0

end LeanGoTest.Vectors
