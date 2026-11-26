import Init

namespace LeanfranC

structure JsonNumber where
  mantissa : Int
  exponent : Int
  deriving Inhabited

inductive Json where
  | null
  | bool (value : Bool)
  | num (value : JsonNumber)
  | str (value : String)
  | arr (items : Array Json)
  | obj (fields : List (String × Json))
  deriving Inhabited

namespace Json

private def escapeChar (out : String) (c : Char) : String :=
  match c with
  | '"' => out ++ "\\\""
  | '\\' => out ++ "\\\\"
  | '\n' => out ++ "\\n"
  | '\r' => out ++ "\\r"
  | c =>
    if c.toNat < 32 then
      (out ++ "\\u00").push (Nat.digitChar (c.toNat / 16)) |>.push (Nat.digitChar (c.toNat % 16))
    else out.push c

private def quote (out value : String) : String :=
  (value.foldl escapeChar (out.push '"')).push '"'

private def JsonNumber.render (n : JsonNumber) : String := Id.run do
  if n.mantissa == 0 then return "0"
  let sign := if n.mantissa < 0 then "-" else ""
  let digits := toString n.mantissa.natAbs
  if n.exponent >= 0 then
    if n.exponent > 10000 then return s!"{sign}{digits}e{n.exponent}"
    return sign ++ digits ++ String.ofList (List.replicate n.exponent.toNat '0')
  let exp := min 0 (9 + (digits.length : Int) + n.exponent)
  let scale := (exp - n.exponent).toNat
  let divisor := 10 ^ scale
  let left := toString (n.mantissa.natAbs / divisor)
  let remainder := n.mantissa.natAbs % divisor
  if remainder == 0 && exp == 0 then return sign ++ left
  let right := (toString (divisor + remainder)).drop 1 |>.dropEndWhile (· == '0') |>.toString
  return s!"{sign}{left}.{right}{if exp == 0 then "" else s!"e{exp}"}"

partial def compress (value : Json) (out : String := "") : String :=
  match value with
  | .null => out ++ "null"
  | .bool b => out ++ toString b
  | .num n => out ++ JsonNumber.render n
  | .str s => quote out s
  | .arr items => Id.run do
    let mut out := out.push '['
    for i in [:items.size] do
      if i != 0 then out := out.push ','
      out := compress items[i]! out
    return out.push ']'
  | .obj fields => Id.run do
    let mut out := out.push '{'
    let mut first := true
    for (key, value) in (fields.toArray.qsort (fun a b => a.1 < b.1)) do
      if !first then out := out.push ','
      first := false
      out := compress value ((quote out key).push ':')
    return out.push '}'

private abbrev Parser := StateT (List Char) (Except String)

private def peek : Parser (Option Char) :=
  return (← get).head?

private def take : Parser Char := do
  let c :: rest ← get | throw "Unexpected end of JSON"
  set rest
  return c

private def accept (c : Char) : Parser Bool := do
  let input ← get
  if input.head? == some c then
    set input.tail
    return true
  return false

private def expect (c : Char) : Parser Unit := do
  unless ← accept c do throw s!"Expected '{c}'"

private def whitespace : Parser Unit :=
  modify (·.dropWhile (fun c => c == ' ' || c == '\t' || c == '\n' || c == '\r'))

private def hex : Parser Nat := do
  let mut value := 0
  for _ in [:4] do
    let c ← take
    let digit ←
      if c.isDigit then pure (c.toNat - '0'.toNat)
      else if 'a' <= c.toLower && c.toLower <= 'f' then pure (c.toLower.toNat - 'a'.toNat + 10)
      else throw "Invalid hexadecimal escape"
    value := value * 16 + digit
  return value

private def surrogate (high : Nat) : Parser Char := do
  let start ← get
  let low : Except String (Nat × List Char) := (do
    expect '\\'
    expect 'u'
    let low ← hex
    unless 0xdc00 <= low && low < 0xe000 do throw "Expected low surrogate"
    pure low : Parser Nat).run start
  if let .ok (low, rest) := low then
    set rest
    return Char.ofNat (0x10000 + (high - 0xd800) * 1024 + low - 0xdc00)
  return '\ufffd'

private def escaped : Parser Char := do
  match ← take with
  | '"' => pure '"'
  | '\\' => pure '\\'
  | '/' => pure '/'
  | 'b' => pure '\x08'
  | 'f' => pure '\x0c'
  | 'n' => pure '\n'
  | 'r' => pure '\r'
  | 't' => pure '\t'
  | 'u' =>
    let n ← hex
    if n < 0xd800 || n >= 0xe000 then return Char.ofNat n
    if n < 0xdc00 then surrogate n else pure '\ufffd'
  | _ => throw "Invalid string escape"

private partial def string (out : String := "") : Parser String := do
  let c ← take
  if c == '"' then return out
  if c == '\\' then return ← string (out.push (← escaped))
  if c.toNat < 32 then throw "Unescaped control character"
  string (out.push c)

private partial def digits (value count : Nat) : Parser (Nat × Nat) := do
  if let some c ← peek then
    if c.isDigit then
      discard take
      return ← digits (value * 10 + c.toNat - '0'.toNat) (count + 1)
  return (value, count)

private def nonemptyDigits (value : Nat := 0) : Parser (Nat × Nat) := do
  let (value, count) ← digits value 0
  if count == 0 then throw "Expected a decimal digit"
  return (value, count)

private def number : Parser JsonNumber := do
  let negative ← accept '-'
  let whole ← if ← accept '0' then pure 0 else Prod.fst <$> nonemptyDigits
  let (value, scale) ← if ← accept '.' then nonemptyDigits whole else pure (whole, 0)
  let mut exponent : Int := -(Int.ofNat scale)
  if (← accept 'e') || (← accept 'E') then
    let negative ← accept '-'
    unless negative do discard (accept '+')
    let (exp, _) ← nonemptyDigits
    exponent := exponent + (if negative then -(Int.ofNat exp) else Int.ofNat exp)
  return ⟨if negative then -(Int.ofNat value) else Int.ofNat value, exponent⟩

private def keyword (word : String) : Parser Unit :=
  word.toList.forM expect

private def uniqueFields (fields : List (String × Json)) : List (String × Json) :=
  let sorted := fields.mergeSort (fun a b => a.1 <= b.1)
  (sorted.foldl (fun out field =>
    if out.head?.any (·.1 == field.1) then out else field :: out) []).reverse

mutual
  private partial def value (depth : Nat) : Parser Json := do
    if depth > 1024 then throw "JSON nesting exceeds 1024 levels"
    whitespace
    match ← peek with
    | some '"' => discard take; return .str (← string)
    | some '[' =>
      discard take
      whitespace
      if ← accept ']' then return .arr #[]
      array (depth + 1) #[]
    | some '{' =>
      discard take
      whitespace
      if ← accept '}' then return .obj []
      object (depth + 1) []
    | some 'n' => keyword "null"; return .null
    | some 't' => keyword "true"; return .bool true
    | some 'f' => keyword "false"; return .bool false
    | _ => return .num (← number)

  private partial def array (depth : Nat) (items : Array Json) : Parser Json := do
    let items := items.push (← value depth)
    whitespace
    if ← accept ']' then return .arr items
    expect ','
    array depth items

  private partial def object (depth : Nat) (fields : List (String × Json)) : Parser Json := do
    whitespace
    expect '"'
    let key ← string
    whitespace
    expect ':'
    let item ← value depth
    let fields := (key, item) :: fields
    whitespace
    if ← accept '}' then return .obj (uniqueFields fields)
    expect ','
    object depth fields
end

def parse (input : String) : Except String Json :=
  (do
    let result ← value 0
    whitespace
    unless (← get).isEmpty do throw "Trailing input after JSON value"
    pure result : Parser Json).run' input.toList

def parseBytes (bytes : ByteArray) : Except String Json := do
  let some input := String.fromUTF8? bytes | throw "Expected valid UTF-8"
  parse input

def getString : Json → Except String String
  | .str s => pure s
  | _ => throw "Expected a JSON string"

def getBool : Json → Except String Bool
  | .bool b => pure b
  | _ => throw "Expected a JSON boolean"

def getArray : Json → Except String (Array Json)
  | .arr items => pure items
  | _ => throw "Expected a JSON array"

def getTuple (value : Json) (size : Nat) : Except String (Array Json) := do
  let items ← getArray value
  unless items.size == size do throw s!"Expected {size} elements"
  return items

def getFields : Json → Except String (List (String × Json))
  | .obj fields => pure fields
  | _ => throw "Expected a JSON object"

def getField (value : Json) (key : String) (optional := false) : Except String Json := do
  let fields ← value.getFields
  if let some item := fields.lookup key then return item
  if optional then return .null
  throw s!"Missing JSON field {key}"

def getTag : Json → Except String (String × Json)
  | .str s => pure (s, .null)
  | .obj [(key, value)] => pure (key, value)
  | _ => throw "Expected a constructor name or a single constructor field"

def getInt : Json → Except String Int
  | .num n => do
    if n.mantissa == 0 then return 0
    if n.exponent >= 0 then
      if n.exponent > 10000 then throw "JSON integer exponent is too large"
      return n.mantissa * Int.ofNat (10 ^ n.exponent.toNat)
    let scale := n.exponent.natAbs
    if scale >= (toString n.mantissa.natAbs).length then throw "Expected an integer"
    let factor := Int.ofNat (10 ^ scale)
    unless n.mantissa % factor == 0 do throw "Expected an integer"
    return n.mantissa / factor
  | _ => throw "Expected a JSON number"

def getNat (value : Json) : Except String Nat := do
  let n ← value.getInt
  if n < 0 then throw "Expected a natural number"
  return n.toNat

def nat (value : Nat) : Json := .num ⟨value, 0⟩

def int (value : Int) : Json := .num ⟨value, 0⟩

def boundedNat (value : Json) (bound : Nat) (quoted : Bool) : Except String Nat := do
  let n ← if quoted then do
      let some n := (← value.getString).toNat? | throw "Expected a decimal string"
      pure n
    else value.getNat
  if n >= bound then throw "Unsigned integer out of range"
  return n

def boundedInt (value : Json) (bound : Int) : Except String Int := do
  let n ← value.getInt
  if n < -bound || n >= bound then throw "Signed integer out of range"
  return n

def char (value : Char) : Json := .str (String.singleton value)

def getChar (value : Json) : Except String Char := do
  let [c] := (← value.getString).toList | throw "Expected one Unicode scalar value"
  return c

def bytes (value : ByteArray) : Json :=
  .arr (value.data.map (nat ∘ UInt8.toNat))

def getBytes (value : Json) : Except String ByteArray := do
  ByteArray.mk <$> (← value.getArray).mapM (fun j => UInt8.ofNat <$> j.boundedNat 256 false)

def getUnit (value : Json) : Except String Unit := do
  unless (← value.getFields).isEmpty do throw "Expected an empty object"

def float (value : Float) : Json :=
  if value.isNaN then .str "NaN"
  else if value.isInf then .str (if value < 0 then "-Infinity" else "Infinity")
  else
    match parse (toString value) with
    | .ok result => result
    | .error _ => .null

def getFloat : Json → Except String Float
  | .str "Infinity" => pure (1.0 / 0.0)
  | .str "-Infinity" => pure (-1.0 / 0.0)
  | .str "NaN" => pure (0.0 / 0.0)
  | .num n =>
    pure ((if n.mantissa < 0 then -1.0 else 1.0) *
      OfScientific.ofScientific n.mantissa.natAbs (n.exponent < 0) n.exponent.natAbs)
  | _ => throw "Expected a JSON number or a special floating-point value"

def floats (value : FloatArray) : Json :=
  .arr (value.data.map float)

def getFloats (value : Json) : Except String FloatArray := do
  FloatArray.mk <$> (← value.getArray).mapM getFloat

def omitNull (key : String) : Json → List (String × Json)
  | .null => []
  | value => [(key, value)]

end Json
end LeanfranC
