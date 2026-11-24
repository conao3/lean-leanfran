namespace LeanGoTest.ControlDepth

@[noinline] def selfCount (n acc : Nat) : Nat :=
  if n = 0 then acc else selfCount (n - 1) (acc + 1)

mutual
  @[noinline] partial def evenStep (n acc : UInt64) : Nat :=
    if n = 0 then acc.toNat else oddStep (n - 1) (acc + 2)

  @[noinline] partial def oddStep (n acc : UInt64) : Nat :=
    if n = 0 then acc.toNat else evenStep (n - 1) (acc + 3)
end

@[noinline] def chainEnd (n : UInt64) : UInt64 := n + 1
@[noinline] def chainMiddle (n : UInt64) : UInt64 := chainEnd (n + 1)
@[noinline] def chainStart (n : UInt64) : UInt64 := chainMiddle (n + 1)

@[noinline] def chainCount (n : Nat) (acc : UInt64) : Nat :=
  if n = 0 then acc.toNat else chainCount (n - 1) (chainStart acc)

@[noinline] def applyStep (f : UInt64 → UInt64 → Nat) (n acc : UInt64) : Nat :=
  if n = 0 then acc.toNat else f (n - 1) acc

@[noinline] partial def cpsStep (n acc : UInt64) : Nat :=
  applyStep (fun k value => cpsStep k (value + 1)) n acc

@[noinline] def nonTailBase (n : Nat) : Nat := n + 1

@[noinline] def nonTail (n : Nat) : Nat :=
  if n = 0 then nonTailBase n else nonTail (n - 1) + 1
termination_by n

def run (args : List String) : IO UInt32 := do
  let some mode := args.head? | return 2
  let some n := args[1]?.bind String.toNat? | return 2
  let result := match mode with
    | "self" => selfCount n 0
    | "mutual" => evenStep n.toUInt64 0
    | "chain" => chainCount n 0
    | "cps" => cpsStep n.toUInt64 0
    | "non-tail" => nonTail n
    | _ => 0
  IO.println result
  return 0

end LeanGoTest.ControlDepth
