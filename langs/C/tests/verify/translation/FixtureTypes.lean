namespace Geo

structure Point where
  x : Int32
  y : Int32

def norm1 (p : Point) : Int32 := p.x + p.y

inductive Color where
  | red
  | green
  | blue

inductive Shape where
  | circle (r : Int32)
  | rect (w h : Int32)
  | pair : Int32 → Int64 → Shape
  | tinted (c : Color) (r : Int32) (pos : 0 ≤ r)
  | dot

def paint (s : Shape) (c : Color) : Shape := match c with
  | .red => s
  | _ => .dot

inductive Shade where
  | light
  | dark

def shade (s : Shade) : Shade := s

end Geo

structure «item» where
  «qty» : UInt32
  «qty_ge» : Int.ofNat «qty».toNat ≥ (1 : Int)
  «price» : Int64
  «weight» : USize
