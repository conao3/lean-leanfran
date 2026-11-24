import Lean.Data.Json

def encodeNumber (n : UInt32) : String := (Lean.toJson n.toNat).compress
