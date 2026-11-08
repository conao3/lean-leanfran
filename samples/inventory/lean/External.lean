module
public import Aeneas
public import LeanRustGen.Model.inventory.Types
@[expose] public section
open Aeneas Aeneas.Std Result
open inventory

/-- The value of the entry whose key borrows as `q`. -/
def alloc.collections.btree.map.BTreeMap.find {K V Q : Type} (borrowInst : core.borrow.Borrow K Q)
    (ordInst : core.cmp.Ord Q) (q : Q) : List (K × V) → Result (Option V)
  | [] => ok none
  | (k, v) :: rest => do
    let b ← borrowInst.borrow k
    let o ← ordInst.cmp b q
    if o = .eq then ok (some v) else alloc.collections.btree.map.BTreeMap.find borrowInst ordInst q rest

@[rust_fun
  "alloc::collections::btree::map::{alloc::collections::btree::map::BTreeMap<@K, @V, @A>}::get"]
def alloc.collections.btree.map.BTreeMap.get {K V A Q : Type}
    (_allocInst : core.alloc.AllocatorClone A) (borrowInst : core.borrow.Borrow K Q)
    (_ordK : core.cmp.Ord K) (ordQ : core.cmp.Ord Q)
    (m : alloc.collections.btree.map.BTreeMap K V A) (q : Q) : Result (Option V) :=
  alloc.collections.btree.map.BTreeMap.find borrowInst ordQ q m
