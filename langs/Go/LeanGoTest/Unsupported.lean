namespace LeanGoTest.Unsupported

@[extern "lean_go_missing_alpha"]
opaque alpha : Nat → Nat

@[extern "lean_go_missing_beta"]
opaque beta : Nat → Nat

def run (x : Nat) : Nat := beta (alpha x)

end LeanGoTest.Unsupported
