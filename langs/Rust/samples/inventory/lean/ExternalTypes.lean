module
public import Aeneas
@[expose] public section
open Aeneas Aeneas.Std Result

/-- `BTreeMap`: its entries in increasing order of the keys. -/
@[rust_type "alloc::collections::btree::map::BTreeMap"]
def alloc.collections.btree.map.BTreeMap (K : Type) (V : Type) (_A : Type) : Type := List (K × V)
