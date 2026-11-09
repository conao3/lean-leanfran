import LeanPythonModels.step08.code

namespace LeanPythonEmbed.step08.code.bank
open LeanPythonModels.step08.code


/-- Moves `amount` when `a` can afford it. -/
def transfer (a b : Account) (amount : Nat) : Account × Account :=
  if amount ≤ a.balance then
    ({ a with balance := a.balance - amount }, { b with balance := b.balance + amount })
  else (a, b)

theorem transfer_total (a b : Account) (amount : Nat) :
    (transfer a b amount).1.balance + (transfer a b amount).2.balance = a.balance + b.balance := by
  unfold transfer; split <;> simp <;> omega


end LeanPythonEmbed.step08.code.bank
