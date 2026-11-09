from lean_python import lean

shapes = lean(
    "shapes",
    r"""
inductive Shape where
  | square (side : Nat)
  | rect (w h : Nat)

def Shape.area : Shape → Nat
  | .square s => s * s
  | .rect w h => w * h
""",
)

report = lean(
    "report",
    r"""
def totalArea (xs : List Shape) : Nat := (xs.map Shape.area).foldl (· + ·) 0

def largest (xs : List Shape) : Option Shape :=
  xs.foldl (fun best s => match best with
    | none => some s
    | some b => if b.area < s.area then some s else some b) none
""",
    uses=["shapes"],
)
