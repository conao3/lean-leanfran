from lean_python import lean

spec = lean(
    "spec",
    r"""
def clampSpec (x lo hi : Int) : Int := max lo (min hi x)

def ordered (_x lo hi : Int) : Bool := lo ≤ hi

def inRange (_x lo hi : Int) (r : Int) : Bool := lo ≤ r && r ≤ hi

def firstOr (xs : List Int) (d : Int) : Int := xs.headD d

def sumTo (n : Nat) : Nat := n * (n + 1) / 2

def nonneg (_xs : List Int) (r : Int) : Bool := 0 ≤ r
""",
)
