from pydantic import BaseModel, Field

from lean_python import lean


class Account(BaseModel):
    owner: str = Field(min_length=1)
    balance: int = Field(ge=0)


bank = lean(
    "bank",
    r"""
/-- Moves `amount` when `a` can afford it. -/
def transfer (a b : Account) (amount : Nat) : Account × Account :=
  if amount ≤ a.balance then
    ({ a with balance := a.balance - amount }, { b with balance := b.balance + amount })
  else (a, b)

theorem transfer_total (a b : Account) (amount : Nat) :
    (transfer a b amount).1.balance + (transfer a b amount).2.balance = a.balance + b.balance := by
  unfold transfer; split <;> simp <;> omega
""",
    models=[Account],
)
