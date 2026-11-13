/-! Workloads of `samples/bench/bench.py`. -/

namespace LeanPythonTest.Bench

def pushLoop (n : Nat) : Nat := Id.run do
  let mut a : Array Nat := #[]
  for i in [0:n] do
    a := a.push i
  let mut s := 0
  for i in [0:n] do
    a := a.set! i (a[i]! * 2)
  for x in a do
    s := s + x
  return s

def fib (n : Nat) : Nat := Id.run do
  let mut a := 0
  let mut b := 1
  for _ in [0:n] do
    (a, b) := (b, a + b)
  return a % 1000000007

def naiveFib : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => naiveFib n + naiveFib (n + 1)

def buildString (n : Nat) : Nat := Id.run do
  let mut s := ""
  for i in [0:n] do
    s := s.push (Char.ofNat (97 + i % 26))
  return s.length

def sortList (n : Nat) : Nat :=
  let xs := (List.range n).map (fun i => (i * 7919) % n)
  (xs.toArray.qsort (· < ·)).size

structure Item where
  sku : String
  qty : Nat
  price : Nat

def total (items : List Item) : Nat := items.foldl (fun acc i => acc + i.qty * i.price) 0

end LeanPythonTest.Bench
