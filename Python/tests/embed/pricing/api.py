from fastapi import FastAPI

from lean_python import lean
from pricing.models import LineItem

pricing = lean(
    "pricing",
    r"""
inductive Discount where
  | none
  | percent (p : Nat) (h : p ≤ 100)
  | fixed (amount : Nat)

def subtotal (items : List LineItem) : Nat :=
  items.foldl (fun acc i => acc + i.qty * i.unitPrice) 0

def total (items : List LineItem) (d : Discount) : Nat :=
  match d with
  | .none => subtotal items
  | .percent p _ => subtotal items - subtotal items * p / 100
  | .fixed a => subtotal items - a

theorem total_le (items : List LineItem) (d : Discount) : total items d ≤ subtotal items := by
  unfold total; split <;> omega

theorem qty_pos (i : LineItem) : 0 < i.qty := by
  have := i.qty_ge; omega
""",
    models=[LineItem],
)

geometry = lean(
    "geometry",
    r"""
structure Range where
  lo : Nat
  hi : Nat
  ok : lo ≤ hi

def Range.width (r : Range) : Nat := r.hi - r.lo
""",
)

report = lean(
    "report",
    r"""
def describe (r : Range) : String := s!"[{r.lo}, {r.hi}] width {r.width}"
""",
    uses=["geometry"],
)

app = FastAPI()


@app.post("/total")
def post_total(items: list[LineItem], discount: pricing.Discount) -> int:
    return pricing.total(items, discount)
