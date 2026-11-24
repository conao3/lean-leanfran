import Examples.PublicApi

open Example

def main (args : List String) : IO UInt32 := do
  IO.println (← counter (UInt64.ofNat (args.headD "0" |>.toNat?.getD 0)))
  IO.println (scalars true 255 65535 4294967295 123)
  IO.println (int8 (-128))
  IO.println (← int16 (-32768))
  IO.println (int32 (-2147483648))
  IO.println (← int64 (-9223372036854775808))
  IO.println ((← doubleValue 1.25).toUInt32)
  IO.println ((floatValue 1.5).toUInt32)
  IO.println ((← character '🙂').toNat)
  IO.println (greeting "世界")
  let string ← repeatString "a\x00b"
  IO.println (string.toUTF8.toList.map UInt8.toNat)
  IO.println (emptyString.utf8ByteSize)
  IO.println (lookup 2)
  try
    effect (args.contains "fail")
    return 0
  catch error =>
    IO.eprintln error.toString
    return 7
