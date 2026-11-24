import Examples.PublicApi

initialize do
  if (← IO.getEnv "LEANFRAN_TEST_INIT_ERROR").isSome then
    throw (IO.userError "initialization failed")

def sample : UInt8 := 0
