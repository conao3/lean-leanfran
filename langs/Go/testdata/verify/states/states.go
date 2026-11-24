package states

import "github.com/conao3/leanfran-go"

var _ = leanfran.Lean(`
def incSpec (n : Int64) := 1 + n
`)

//leanfran:model refines=incSpec
func Proved(n int64) int64 { return n + 1 }

//leanfran:model refines=incSpec
func Sorry(n int64) int64 { return n + 1 }

//leanfran:model refines=incSpec
func Axioms(n int64) int64 { return n + 1 }

//leanfran:model refines=incSpec
func Missing(n int64) int64 { return n + 1 }

//leanfran:model refines=incSpec
func Mismatch(n int64) int64 { return n + 1 }

//leanfran:model refines=incSpec
func Failed(n int64) int64 { return n + 1 }

//leanfran:model refines=incSpec
func Unsupported(n int64) int64 {
	return map[int64]int64{n: n + 1}[n]
}
