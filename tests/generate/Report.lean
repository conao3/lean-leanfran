import Shapes
import Shapes.Area

namespace Report

structure Line where
  label : String
  origin : Shapes.Point
  size : Shapes.Area.Rect

def total (lines : List Line) : Nat := (lines.map fun l => Shapes.Area.area l.size).sum

def moved (l : Line) (d : Nat) : Line := { l with origin := Shapes.shift l.origin d }

end Report
