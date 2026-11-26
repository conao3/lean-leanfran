import Examples.SharedState

def secondCounter : IO UInt64 := sharedCounter.get
