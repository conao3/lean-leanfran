namespace shapes

structure Point where
  x : Nat
  y : Nat
  deriving DecidableEq

def Point.manhattan (p : Point) : Nat := p.x + p.y

end shapes
