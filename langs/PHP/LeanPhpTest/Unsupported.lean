namespace LeanPhpTest.Unsupported

@[extern "lean_php_missing_alpha"]
opaque alpha : Nat → Nat

@[extern "lean_php_missing_beta"]
opaque beta : Nat → Nat

def run (x : Nat) : Nat := beta (alpha x)

end LeanPhpTest.Unsupported
