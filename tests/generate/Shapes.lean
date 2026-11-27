namespace Shapes

structure Point where
  x : Nat
  y : Nat

def shift (p : Point) (d : Nat) : Point := ⟨p.x + d, p.y + d⟩

end Shapes
