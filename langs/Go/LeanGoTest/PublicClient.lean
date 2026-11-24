import LeanGoTest.Public

namespace LeanGoTest.PublicClient

def width (r : Public.Range) : Nat := r.hi - r.lo
def echo (d : Public.Discount) : Public.Discount := d

def amount (v : Public.Value) : UInt64 := v.amount

end LeanGoTest.PublicClient
