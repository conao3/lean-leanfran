module

import Init

@[expose] public section

namespace C

inductive Exc where
  | signedOverflow
  | divByZero
  | shiftOutOfRange
  | floatToIntOutOfRange
  | indexOutOfRange
  | diverged
  | missingReturn
  deriving DecidableEq, Repr, Inhabited

abbrev M := Except Exc

inductive Status where
  | ok
  | invalid
  | except
  | io
  | notInitialized
  deriving DecidableEq, Repr, Inhabited

class IntType (α : Type) where
  width : Nat
  signed : Bool
  toInt : α → Int
  ofInt : Int → α

instance : IntType Int8 := ⟨8, true, Int8.toInt, Int8.ofInt⟩
instance : IntType Int16 := ⟨16, true, Int16.toInt, Int16.ofInt⟩
instance : IntType Int32 := ⟨32, true, Int32.toInt, Int32.ofInt⟩
instance : IntType Int64 := ⟨64, true, Int64.toInt, Int64.ofInt⟩
instance : IntType UInt8 := ⟨8, false, fun a => Int.ofNat a.toNat, UInt8.ofInt⟩
instance : IntType UInt16 := ⟨16, false, fun a => Int.ofNat a.toNat, UInt16.ofInt⟩
instance : IntType UInt32 := ⟨32, false, fun a => Int.ofNat a.toNat, UInt32.ofInt⟩
instance : IntType UInt64 := ⟨64, false, fun a => Int.ofNat a.toNat, UInt64.ofInt⟩
instance : IntType USize :=
  ⟨System.Platform.numBits, false, fun a => Int.ofNat a.toNat, USize.ofInt⟩

def bounds (α : Type) [IntType α] : Int × Int :=
  if IntType.signed α then
    let limit : Int := 2 ^ (IntType.width α - 1)
    (-limit, limit)
  else (0, 2 ^ IntType.width α)

def checked (α : Type) [IntType α] (error : Exc) (value : Int) : M α :=
  let (lower, upper) := bounds α
  if lower ≤ value ∧ value < upper then .ok (IntType.ofInt value)
  else .error error

def addS [IntType α] (a b : α) : M α :=
  checked α .signedOverflow (IntType.toInt a + IntType.toInt b)

def subS [IntType α] (a b : α) : M α :=
  checked α .signedOverflow (IntType.toInt a - IntType.toInt b)

def mulS [IntType α] (a b : α) : M α :=
  checked α .signedOverflow (IntType.toInt a * IntType.toInt b)

def negS [IntType α] (a : α) : M α :=
  checked α .signedOverflow (-IntType.toInt a)

def checkDivisor (α : Type) [IntType α] (a b : Int) : M Unit :=
  if b = 0 then .error .divByZero
  else if b = -1 ∧ a = (bounds α).1 then .error .signedOverflow
  else .ok ()

def div [IntType α] (a b : α) : M α := do
  let a := IntType.toInt a
  let b := IntType.toInt b
  checkDivisor α a b
  return IntType.ofInt (a.tdiv b)

def mod [IntType α] (a b : α) : M α := do
  let a := IntType.toInt a
  let b := IntType.toInt b
  checkDivisor α a b
  return IntType.ofInt (a.tmod b)

def shiftCount (width : Nat) (count : Int) : M Nat :=
  if 0 ≤ count ∧ count < Int.ofNat width then .ok count.toNat
  else .error .shiftOutOfRange

def shl [IntType α] (a : α) (count : Int) : M α := do
  let n ← shiftCount (IntType.width α) count
  let value := IntType.toInt a
  let shifted := value * 2 ^ n
  if IntType.signed α then
    if value < 0 then .error .signedOverflow else checked α .signedOverflow shifted
  else return IntType.ofInt shifted

def shr [IntType α] (a : α) (count : Int) : M α := do
  let n ← shiftCount (IntType.width α) count
  return IntType.ofInt (IntType.toInt a >>> n)

class Cast (α β : Type) where
  cast : α → β

export Cast (cast)

instance castInt [IntType α] [IntType β] : Cast α β :=
  ⟨fun a => IntType.ofInt (IntType.toInt a)⟩

instance castIntToBool [IntType α] : Cast α Bool :=
  ⟨fun a => IntType.toInt a != 0⟩

instance castBoolToInt [IntType α] : Cast Bool α :=
  ⟨fun a => IntType.ofInt (if a then 1 else 0)⟩

instance : Cast Bool Bool := ⟨id⟩
instance : Cast Float Float := ⟨id⟩
instance : Cast Bool Float := ⟨fun a => if a then 1.0 else 0.0⟩
instance : Cast Float Bool := ⟨fun a => a != 0.0⟩

instance castIntToFloat [IntType α] : Cast α Float :=
  ⟨fun a =>
    let value := IntType.toInt a
    let magnitude := (UInt64.ofNat value.natAbs).toFloat
    if value < 0 then -magnitude else magnitude⟩

def floatToInt [IntType α] (a : Float) : M α :=
  let magnitude := a.abs
  if magnitude < 18446744073709551616.0 then
    let value := Int.ofNat magnitude.toUInt64.toNat
    checked α .floatToIntOutOfRange (if a < 0.0 then -value else value)
  else .error .floatToIntOutOfRange

def andThen (a : Bool) (b : Unit → M Bool) : M Bool :=
  if a then b () else .ok false

def orElse (a : Bool) (b : Unit → M Bool) : M Bool :=
  if a then .ok true else b ()

def index (values : Array α) (i : Int) : M α :=
  if i < 0 then .error .indexOutOfRange
  else match values[i.toNat]? with
    | some value => .ok value
    | none => .error .indexOutOfRange

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

end C
