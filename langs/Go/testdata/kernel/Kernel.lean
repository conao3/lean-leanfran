import Std.Data.HashMap

namespace Kernel

inductive Mode where
  | active
  | paused
  deriving Inhabited

def Mode.render : Mode → String
  | .active => "active"
  | .paused => "paused"

structure Row where
  id : UInt64
  amount : UInt64
  limit? : Option UInt64
  mode : Mode

structure Snapshot where
  rows : List Row
  revision : UInt64

structure Actor where
  tenant : UInt64
  canWrite : Bool

inductive Command where
  | read
  | add (amount : UInt64)
  | set (amount : UInt64)
  | limit (value : Option UInt64)
  | pause

inductive Error where
  | forbidden
  | missing
  | paused
  | limit
  deriving Inhabited

def Error.render : Error → String
  | .forbidden => "forbidden"
  | .missing => "missing"
  | .paused => "paused"
  | .limit => "limit"

inductive Writes where
  | unchanged
  | amount (value : UInt64) (id : UInt64)
  | limit (value : Option UInt64) (id : UInt64)
  | pause (id : UInt64)

def initial (size : Nat) : Snapshot :=
  ⟨(List.range size).map fun n =>
    ⟨n.toUInt64, (18446744073709551615 : UInt64) - n.toUInt64, if n % 2 == 0 then some (18446744073709551615 : UInt64) else none,
      if n % 3 == 0 then .active else .paused⟩, 0⟩

def starting : Snapshot := initial 3

def transition (actor : Actor) (snapshot : Snapshot) (command : Command) :
    Except Error (Writes × UInt64) := do
  let row ← match snapshot.rows.find? (·.id == actor.tenant) with
    | none => .error .missing
    | some row => .ok row
  match command with
  | .read => return (.unchanged, row.amount)
  | _ =>
    if !actor.canWrite then throw .forbidden
    match command with
    | .add delta | .set delta =>
      let value := match command with | .add _ => row.amount + delta | _ => delta
      if let .paused := row.mode then throw .paused
      if (row.limit?.any (· < value)) then throw .limit
      return (.amount value row.id, value)
    | .limit limit => return (.limit limit row.id, row.amount)
    | .pause => return (.pause row.id, row.amount)
    | .read => return (.unchanged, row.amount)

private def updateRow (writes : Writes) (id : UInt64) : List Row → List Row
  | [] => []
  | row :: rest =>
    if row.id == id then
      let updated := match writes with
        | .amount value _ => { row with amount := value }
        | .limit value _ => { row with limit? := value }
        | .pause _ => { row with mode := if let .active := row.mode then .paused else .active }
        | .unchanged => row
      updated :: rest
    else row :: updateRow writes id rest

@[noinline] private def writeRows (writes : Writes) (id : UInt64) (rows : List Row) : List Row :=
  updateRow writes id rows

def apply (snapshot : Snapshot) (writes : Writes) : Snapshot :=
  match writes with
  | .unchanged => snapshot
  | .amount _ id | .limit _ id | .pause id =>
    { rows := writeRows writes id snapshot.rows, revision := snapshot.revision + 1 }

def renderSnapshot (snapshot : Snapshot) : String :=
  let rows := snapshot.rows.map fun r =>
    s!"{r.id},{r.amount},{r.limit?.map toString |>.getD "-"}, {r.mode.render}"
  s!"{snapshot.revision};" ++ String.intercalate ";" rows

structure Counter where
  count : UInt64
  other : UInt64

def bump (counter : Counter) (value : UInt64) : Counter :=
  { counter with count := value }

def replaceLast (values : Array UInt64) (value : UInt64) : Array UInt64 :=
  values.pop.push value

def record (values : Array UInt64) (value : UInt64) : Array UInt64 :=
  values.push value

def doubled (values : Array UInt64) : Array UInt64 := Id.run do
  let mut out := Array.mkEmpty values.size
  for value in values do
    out := out.push (value * 2)
  return out

structure Verified where
  value : UInt64
  proof : ∀ n : Nat, n = n

def verify (value : UInt64) : Verified := ⟨value, fun _ => rfl⟩

def readVerified (v : Verified) : UInt64 := v.value

structure Cache where
  entries : Std.HashMap UInt64 UInt64

def newCache (capacity : Nat) : Cache := ⟨Std.HashMap.emptyWithCapacity capacity⟩

def insertCache (cache : Cache) (key value : UInt64) : Cache :=
  ⟨cache.entries.insert key value⟩

def findCache (cache : Cache) (key : UInt64) : Option UInt64 :=
  cache.entries.get? key

def emptyMap (capacity : Nat) : Std.HashMap UInt64 UInt64 :=
  Std.HashMap.emptyWithCapacity capacity

def mapSize (entries : Std.HashMap UInt64 UInt64) : Nat := entries.size

def pairValue (n : UInt64) : UInt64 × UInt64 := (n, n)

def addValues (a b : UInt64) : UInt64 := a + b

def hasRow (snapshot : Snapshot) (id : UInt64) : Bool := snapshot.rows.any (·.id == id)

end Kernel
