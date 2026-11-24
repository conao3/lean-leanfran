namespace LeanGoTest.Panic

set_option compiler.extract_closed false in
@[noinline] def unreachable (value : Empty) : Nat := nomatch value

@[noinline] unsafe def unreadableRef (value : Nat) : Nat :=
  runST fun σ => do
    let ref ← ST.mkRef (σ := σ) value
    discard ref.take
    ref.get

set_option compiler.extract_closed false in
@[noinline] unsafe def triggerUnreachable (value : Nat) : Nat :=
  if value == 0 then value else unreachable (unsafeCast value)

@[implemented_by triggerUnreachable]
opaque executeUnreachable (value : Nat) : Nat := value

initialize
  match ← IO.getEnv "LEANFRAN_GO_TEST_INIT_FAILURE" with
  | some "panic" => IO.println (executeUnreachable (← IO.getTID).toNat)
  | some "io-error" => throw (IO.userError "initializer fixture")
  | _ => pure ()

@[noinline] def increment (value : Nat) : Nat := value + 1

@[noinline] def leanPanic (message : String) : Nat := panic! message

end LeanGoTest.Panic

def main (args : List String) : IO Unit := do
  if args == ["unreachable"] then
    IO.println (LeanGoTest.Panic.executeUnreachable (← IO.getTID).toNat)
  IO.println "main reached"
