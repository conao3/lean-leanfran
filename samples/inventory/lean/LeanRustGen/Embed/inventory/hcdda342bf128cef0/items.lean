import Aeneas
import LeanRustGen.Model.inventory.Types
namespace items

open Aeneas Aeneas.Std inventory

def apply (i : item.Item) (e : item.Event) : item.Item :=
  match e with
  | .Received id n => if id = i.id then { i with qty := core.num.U32.saturating_add i.qty n } else i
  | .Shipped id n => if id = i.id then { i with qty := core.num.U32.saturating_sub i.qty n } else i
  | .Retired => { i with qty := 0#u32 }

deriving instance DecidableEq for item.Kind

def same_id (i : item.Item) (_e : item.Event) (r : item.Item) : Bool := decide (r.id = i.id ∧ r.kind = i.kind)

end items
