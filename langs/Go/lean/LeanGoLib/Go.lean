import Init

namespace Go

inductive Exc where
  | divideByZero
  | indexOutOfRange
  | negativeShift
  | panic
  | error (message : String)
  | diverged
  deriving DecidableEq, Repr, Inhabited

abbrev M := Except Exc

def div [OfNat α 0] [BEq α] [Div α] (a b : α) : M α :=
  if b == 0 then .error .divideByZero else .ok (a / b)

def mod [OfNat α 0] [BEq α] [Mod α] (a b : α) : M α :=
  if b == 0 then .error .divideByZero else .ok (a % b)

def shl [OfNat α 0] [HShiftLeft α α α] (width : Nat) (ofNat : Nat → α) (a : α)
    (b : Nat) : α :=
  if b < width then a <<< ofNat b else 0

def shr [OfNat α 0] [HShiftRight α α α] (width : Nat) (ofNat : Nat → α) (a : α)
    (b : Nat) : α :=
  if b < width then a >>> ofNat b else 0

def shift (f : α → Nat → α) (a : α) (b : Int) : M α :=
  if b < 0 then .error .negativeShift else .ok (f a b.toNat)

def index (a : Array α) (i : Int) : M α :=
  if i < 0 then .error .indexOutOfRange
  else match a[i.toNat]? with
    | some v => .ok v
    | none => .error .indexOutOfRange

def setIndex (a : Array α) (i : Int) (v : α) : M (Array α) :=
  if i < 0 || i.toNat ≥ a.size then .error .indexOutOfRange else .ok (a.set! i.toNat v)

def strLen (s : String) : Int64 := Int64.ofNat s.utf8ByteSize

def arrayLen (xs : Array α) : Int64 := Int64.ofNat xs.size

inductive Loop where
  | forever

def repeatStep (step : Unit → σ → M (ForInStep σ)) (state : σ) : Option (M σ) :=
  match step () state with
  | .error e => some (.error e)
  | .ok (.done result) => some (.ok result)
  | .ok (.yield next) => repeatStep step next
partial_fixpoint

instance : ForIn M Loop Unit where
  forIn _ state step := (repeatStep step state).getD (.error .diverged)

def andThen (a : Bool) (b : Unit → M Bool) : M Bool :=
  if a then b () else pure false

def orElse (a : Bool) (b : Unit → M Bool) : M Bool :=
  if a then pure true else b ()

def floatMin (a b : Float) : Float :=
  if a.isNaN then a else if b.isNaN then b
  else if a < b || (a == b && a.toBits > b.toBits) then a else b

def floatMax (a b : Float) : Float :=
  if a.isNaN then a else if b.isNaN then b
  else if a > b || (a == b && a.toBits < b.toBits) then a else b

def stringMin (key : α → String) (a b : α) : α :=
  if key a < key b then a else b

def stringMax (key : α → String) (a b : α) : α :=
  if key a > key b then a else b

end Go
