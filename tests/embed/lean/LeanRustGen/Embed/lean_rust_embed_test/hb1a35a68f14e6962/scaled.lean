import LeanRustGen.Embed.lean_rust_embed_test.h434e341aaed83712.shapes
import LeanRustGen.Embed.lean_rust_embed_test.hb1a35a68f14e6962.arith
open shapes arith
namespace scaled

def scale (p : Point) (k : Nat) : Point := ⟨p.x * k, p.y * k⟩

def doubleBoth (p : Point) : Point := ⟨double p.x, double p.y⟩

theorem doubleBoth_eq (p : Point) : doubleBoth p = scale p 2 := by
  simp [doubleBoth, scale, double_eq, Nat.mul_comm]

end scaled
