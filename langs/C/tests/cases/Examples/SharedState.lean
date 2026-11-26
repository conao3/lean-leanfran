initialize sharedCounter : IO.Ref UInt64 ← do
  if (← IO.getEnv "LEANFRAN_TEST_SHARED_INIT_ERROR").isSome then
    throw (IO.userError "shared initialization failed")
  IO.mkRef 7
