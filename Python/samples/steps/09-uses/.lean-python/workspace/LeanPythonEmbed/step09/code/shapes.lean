
namespace LeanPythonEmbed.step09.code.shapes


inductive Shape where
  | square (side : Nat)
  | rect (w h : Nat)

def Shape.area : Shape → Nat
  | .square s => s * s
  | .rect w h => w * h


end LeanPythonEmbed.step09.code.shapes
