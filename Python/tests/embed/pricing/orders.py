from lean_python import lean
from pricing.models import Order

orders = lean(
    "orders",
    r"""
def describe (o : Order) : String :=
  let st := match o.status with
    | .«open» => "open"
    | .closed => "closed"
  let k := match o.kind with
    | .retail => "retail"
    | .wholesale => "wholesale"
  let pet := match o.pet with
    | none => "no pet"
    | some (.Cat c) => s!"cat {c.name} with {c.lives} lives"
    | some (.Dog d) => s!"dog {d.name}"
  s!"{st} {k} {o.items.length} items, {pet}"

def close (o : Order) : Order := { o with status := .closed, pet := none }

theorem lives_le (c : Cat) : c.lives ≤ 9 := c.lives_le
""",
    models=[Order],
)
