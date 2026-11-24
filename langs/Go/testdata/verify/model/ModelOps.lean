import LeanGoLib.Go

namespace ModelOps

private def checked (result : Go.M α) : Except String α :=
  result.mapError fun
    | .divideByZero => "divideByZero"
    | .indexOutOfRange => "indexOutOfRange"
    | .negativeShift => "negativeShift"
    | _ => "unexpected"

def signed (a b : Int64) : Except String (Int64 × Int64) := checked do
  let q ← Go.div a b
  let r ← Go.mod a b
  return (q, r)

def unsigned (a b : UInt64) : Except String (UInt64 × UInt64) := checked do
  let q ← Go.div a b
  let r ← Go.mod a b
  return (q, r)

def shifts (x : UInt8) (count : UInt64) : UInt8 × UInt8 :=
  (Go.shl 8 UInt8.ofNat x count.toNat, Go.shr 8 UInt8.ofNat x count.toNat)

def signedShift (x : UInt8) (count : Int64) : Except String UInt8 :=
  checked (Go.shift (Go.shl 8 UInt8.ofNat) x count.toInt)

def indexValue (values : Array Int64) (i : Int64) : Except String Int64 :=
  checked (Go.index values i.toInt)

def update (values : Array Int64) (i v : Int64) : Except String (Array Int64) :=
  checked (Go.setIndex values i.toInt v)

def text (a b : String) : String × Int64 × Bool × Bool :=
  (a ++ b, Go.strLen a, decide (a < b), a == b)

def length (values : Array Int64) : Int64 := Go.arrayLen values

def convert (x : Int64) : UInt8 × UInt64 × Int8 :=
  (UInt8.ofInt x.toInt, UInt64.ofInt x.toInt, Int8.ofInt x.toInt)

def bounds (a b : Float) : Float × Float × Bool × Bool :=
  (Go.floatMin a b, Go.floatMax a b, decide (a < b), a == b)

end ModelOps
