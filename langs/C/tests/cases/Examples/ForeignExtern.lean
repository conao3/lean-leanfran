@[extern "go:foreign.Increment"]
private opaque foreignIncrement : UInt32 → UInt32

def callsForeign (n : UInt32) : UInt32 := foreignIncrement n
