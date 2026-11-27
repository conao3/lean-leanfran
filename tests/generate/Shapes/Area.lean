import Shapes
import Choice
import Settings

namespace Shapes.Area

structure Rect where
  origin : Point
  width : Nat
  height : Nat

def area (r : Rect) : Nat := r.width * r.height

def count (c : Counter) : Counter := ⟨c.value + 1⟩

def place (s : Seed) : Rect := ⟨s.point, 3, 4⟩

def packet (status : Status) : Packet Status := ⟨status⟩

def mainFlag (flag : Choice.Flag) : Choice.Flag := flag

def weigh (grams : UInt64) : Loose.Weight := ⟨grams⟩

def shapeCount (s : Shapes) : UInt64 := s.count

end Shapes.Area
