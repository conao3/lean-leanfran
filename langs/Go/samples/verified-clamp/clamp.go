package clamp

import "github.com/conao3/leanfran-go"

var _ = leanfran.Lean(`
def clampSpec (x lo hi : Int64) : Int64 := max lo (min hi x)
def ordered (_x lo hi : Int64) : Bool := decide (lo ≤ hi)
def inRange (_x lo hi r : Int64) : Bool := decide (lo ≤ r) && decide (r ≤ hi)
`)

//leanfran:model refines=clampSpec requires=ordered ensures=in_range:inRange
func Clamp(x, lo, hi int64) int64 {
	if x < lo {
		return lo
	}
	if x > hi {
		return hi
	}
	return x
}
