namespace Inventory

structure Snapshot where
  remaining : UInt64
  sold : UInt64

def initial (remaining : UInt64) : Snapshot := ⟨remaining, 0⟩

inductive Rejection where
  | outOfStock

def transition (snapshot : Snapshot) (amount : UInt64) : Except Rejection (Snapshot × UInt64) :=
  if snapshot.remaining < amount then .error .outOfStock
  else
    let next := { remaining := snapshot.remaining - amount, sold := snapshot.sold + amount : Snapshot }
    .ok (next, next.remaining)

end Inventory
