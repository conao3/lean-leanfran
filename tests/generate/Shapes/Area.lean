namespace Shapes.Area

structure Rect where
  width : Nat
  height : Nat

def area (r : Rect) : Nat := r.width * r.height

end Shapes.Area
