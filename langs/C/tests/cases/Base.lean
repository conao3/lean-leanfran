module

import Dependency

initialize base : IO.Ref UInt64 ← IO.mkRef externalFactor

public def readBase : IO UInt64 := base.get
