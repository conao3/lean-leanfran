namespace Shapes

structure Point where
  x : Nat
  y : Nat

inductive Status where
  | ready
  | busy

structure Counter where
  value : UInt64

structure Packet (α : Type u) where
  payload : α

structure Unsupported where
  run : Nat → Nat

end Shapes

namespace Shapes.Area

structure Seed where
  point : Shapes.Point

end Shapes.Area

structure Shapes.Template where
  seed : Shapes.Area.Seed
