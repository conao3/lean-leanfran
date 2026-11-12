import Aeneas
import LeanRustGen.Model.lean_rust_verify_test.Types
namespace pairs

open Aeneas Aeneas.Std lean_rust_verify_test

def swapped (p : generic.Pair Std.U32) : generic.Pair Std.U32 := ⟨p.b, p.a⟩

end pairs
