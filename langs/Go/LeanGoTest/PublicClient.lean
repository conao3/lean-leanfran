import LeanGoTest.Public

namespace LeanGoTest.PublicClient

def width (r : Public.Range) : Nat := r.hi - r.lo
def echo (d : Public.Discount) : Public.Discount := d

end LeanGoTest.PublicClient
