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

initialize first : String ← pure "first"
initialize second : String ← pure (first ++ ":second")

def run (args : List String) : IO UInt32 := do
  match args with
  | ["status"] =>
    IO.eprintln "requested status"
    return 23
  | ["fail"] => throw (IO.userError "requested failure")
  | _ =>
    IO.println second
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
    return 0

end LeanGoTest.Vectors
