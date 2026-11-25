namespace Geo

structure Point where
  x : Int32
  y : Int32

def norm1 (p : Point) : Int32 := p.x + p.y

end Geo

structure «item» where
  «qty» : UInt32
  «qty_ge» : Int.ofNat «qty».toNat ≥ (1 : Int)
  «price» : Int64
  «weight» : USize
