namespace NumericOracle

def bool (value : String) : Bool :=
  match value with
  | "0" => false
  | "1" => true
  | _ => panic! s!"invalid Bool: {value}"

def showBool (value : Bool) : String :=
  if value then "1" else "0"

def decision {p : Prop} (value : Decidable p) : Bool :=
  match value with
  | .isTrue _ => true
  | .isFalse _ => false

def float (bits : String) : Float :=
  Float.ofBits bits.toNat!.toUInt64

def float32 (bits : String) : Float32 :=
  Float32.ofBits bits.toNat!.toUInt32

def showFloat (value : Float) : String :=
  toString value.toBits.toNat

def showFloat32 (value : Float32) : String :=
  toString value.toBits.toNat

def showFloatPair (value : Float × Int) : String :=
  s!"{showFloat value.1},{value.2}"

def showFloat32Pair (value : Float32 × Int) : String :=
  s!"{showFloat32 value.1},{value.2}"

def natDivExact (a b : Nat) : Nat :=
  if h : b ∣ a then a.divExact b h else panic! "invalid Nat.divExact input"

def intDivExact (a b : Int) : Int :=
  if h : b ∣ a then a.divExact b h else panic! "invalid Int.divExact input"

def charOfNat (n : Nat) : Nat :=
  if h : Nat.isValidChar n then (Char.ofNatAux n h).toNat else panic! "invalid Char input"

@[extern "fmod"] opaque fmod64 : Float → Float → Float

@[extern "fmodf"] opaque fmod32 : Float32 → Float32 → Float32

end NumericOracle
