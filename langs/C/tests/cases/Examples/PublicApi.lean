module

import Base
import Std.Data.HashMap

namespace Example

public def counter (value : UInt64) : IO UInt64 := do
  let base ← readBase
  let task ← IO.asTask (pure (value * base))
  IO.ofExcept task.get

public def scalars (a : Bool) (b : UInt8) (c : UInt16) (d : UInt32) (e : USize) : UInt64 :=
  (if a then 1 else 0) + b.toUInt64 + c.toUInt64 + d.toUInt64 + e.toUInt64

public def int8 (n : Int8) : Int8 := n
public def int16 (n : Int16) : IO Int16 := pure n
public def int32 (n : Int32) : Int32 := n
public def int64 (n : Int64) : IO Int64 := pure n
public def doubleValue (n : Float) : IO Float := pure (n * 2)
public def floatValue (n : Float32) : Float32 := n + 0.5
public def character (c : Char) : IO Char := pure c

public def greeting (s : @& String) : String := "こんにちは " ++ s ++ "!"
public def repeatString (s : String) : IO String := pure (s ++ s)
public def emptyString : String := ""

initialize retained : IO.Ref String ← IO.mkRef ""

public def retainForRefcount (value : String) : IO Unit := retained.set value
public def retainedForRefcount : IO String := retained.get

public def effect (fail : Bool) : IO Unit := do
  if fail then throw (IO.userError "requested failure")
  IO.println "from Lean"

public def lookup (k : UInt32) : UInt32 :=
  let m : Std.HashMap UInt32 UInt32 := ({} : Std.HashMap UInt32 UInt32).insert 2 29
  m.getD k 0

private def hidden : UInt8 := 5
public def unsupported (f : Nat → Nat) : Nat := f 1

end Example
