namespace LeanPhpTest.ControlDepth

@[noinline] def selfCount (n acc : Nat) : Nat :=
  if n = 0 then acc else selfCount (n - 1) (acc + 1)

mutual
  @[noinline] partial def evenStep (n acc : Nat) : Nat :=
    if n = 0 then acc else oddStep (n - 1) (acc + 2)

  @[noinline] partial def oddStep (n acc : Nat) : Nat :=
    if n = 0 then acc else evenStep (n - 1) (acc + 3)
end

@[noinline] def chainEnd (n : Nat) : Nat := n + 1
@[noinline] def chainMiddle (n : Nat) : Nat := chainEnd (n + 1)
@[noinline] def chainStart (n : Nat) : Nat := chainMiddle (n + 1)

@[noinline] def chainCount (n acc : Nat) : Nat :=
  if n = 0 then acc else chainCount (n - 1) (chainStart acc)

@[noinline] def applyStep (f : Nat → Nat → Nat) (n acc : Nat) : Nat :=
  if n = 0 then acc else f (n - 1) acc

@[noinline] partial def cpsStep (n acc : Nat) : Nat :=
  applyStep (fun k value => cpsStep k (value + 1)) n acc

def run (args : List String) : IO UInt32 := do
  let some mode := args.head? | return 2
  let some n := args[1]?.bind String.toNat? | return 2
  let result := match mode with
    | "self" => selfCount n 0
    | "mutual" => evenStep n 0
    | "chain" => chainCount n 0
    | "cps" => cpsStep n 0
    | _ => 0
  IO.println result
  return 0

end LeanPhpTest.ControlDepth
