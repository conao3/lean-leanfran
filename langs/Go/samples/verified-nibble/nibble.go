package nibble

import "github.com/conao3/leanfran-go"

var _ = leanfran.Lean(`
def nibbleSpec (x : UInt8) : UInt8 := x % 16
def inRange (_x r : UInt8) : Bool := decide (r < 16)
`)

//leanfran:model refines=nibbleSpec ensures=in_range:inRange
func Nibble(x uint8) uint8 {
	return x & 15
}
