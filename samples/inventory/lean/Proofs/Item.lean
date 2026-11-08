import LeanRustGen.Obligation.inventory.item
open Aeneas Aeneas.Std Result

namespace inventory.item

theorem apply.proof.refines : apply.obligation.refines := by
  intro it e
  unfold apply _root_.items.apply
  cases e <;> simp [lift] <;> split <;> simp

theorem apply.proof.same_id : apply.obligation.same_id := by
  intro it e
  unfold apply _root_.items.same_id
  cases e <;> simp [lift] <;> split <;> simp

end inventory.item
