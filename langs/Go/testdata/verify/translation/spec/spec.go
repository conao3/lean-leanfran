package spec

import "github.com/conao3/leanfran-go"

var _ = leanfran.Lean(`
namespace Arithmetic
def step (n : Int64) := 1 + n
end Arithmetic
`)
