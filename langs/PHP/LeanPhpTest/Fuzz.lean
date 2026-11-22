namespace LeanPhpTest.Fuzz

def natLine (a b : Nat) : String :=
  s!"{a + b}|{a * b}|{a - b}|{a / b}|{a % b}|{a.log2}|{a <<< 7}"

def intLine (a b : Int) : String :=
  s!"{a + b}|{a * b}|{-a}|{a / b}|{a % b}|{a.tdiv b}|{a.tmod b}"

def uintLine (a b : UInt64) : String :=
  s!"{(a + b).toNat}|{(a - b).toNat}|{(a * b).toNat}|{(a / b).toNat}|{(a % b).toNat}|{(a <<< b).toNat}|{(a >>> b).toNat}|{a.toFloat32.toBits.toNat}"

def stringLine (s t : String) : String :=
  let extended := (s ++ t).push '🌱'
  let bytes := s.toUTF8
  let changed := (bytes.push 255).set! 0 0
  s!"{s.length}|{s.utf8ByteSize}|{extended.length}|{extended.utf8ByteSize}|{extended}|{bytes.size}|{bytes[0]?.getD 0}|{changed.size}|{changed[0]?.getD 1}"

def arrayLine (values : List Nat) : String :=
  let orig := values.toArray
  let edited := (orig.push 17).set! 0 23
  let checksum (a : Array Nat) := a.foldl (fun acc v => 31 * acc + v) 0
  s!"{orig.size}|{checksum orig}|{orig[0]?.getD 0}|{edited.size}|{checksum edited}|{edited[0]!}"

def evalRow (row : String) : Option String :=
  match row.splitOn "\t" with
  | ["NAT", a, b] => natLine <$> a.toNat? <*> b.toNat?
  | ["INT", a, b] => intLine <$> a.toInt? <*> b.toInt?
  | ["U64", a, b] => do
    let a ← a.toNat?
    let b ← b.toNat?
    return uintLine a.toUInt64 b.toUInt64
  | ["STR", s, t] => some (stringLine s t)
  | "ARR" :: rest => arrayLine <$> rest.mapM String.toNat?
  | _ => none

end LeanPhpTest.Fuzz
