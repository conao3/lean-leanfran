import Examples.SharedState

def firstCounter : IO UInt64 := sharedCounter.get
