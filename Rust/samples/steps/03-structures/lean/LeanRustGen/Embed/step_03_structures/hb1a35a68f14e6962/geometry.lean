namespace geometry

structure Point where
  x : Int
  y : Int
  deriving DecidableEq

def Point.add (p q : Point) : Point := ⟨p.x + q.x, p.y + q.y⟩

def Point.manhattan (p : Point) : Nat := p.x.natAbs + p.y.natAbs

def origin : Point := ⟨0, 0⟩

theorem Point.add_origin (p : Point) : p.add origin = p := by
  simp [Point.add, origin]

end geometry
