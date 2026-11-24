package main

import (
	"errors"
	"fmt"
	"math"

	"fixture.test/translate/helper"
	"github.com/conao3/leanfran-go"
)

type Tagged struct {
	Count uint16 `leanfran:"ge=10"`
}

var _ = leanfran.Lean(`
structure Entry where
  key : String
  count : UInt16
inductive Flavor where
  | plain
  | robust
def flavorSpec : Flavor → Bool
  | .plain => false
  | .robust => true
def arithmeticSpec (n m : Int64) := (n + m, n - m, n * m)
def divSpec (n m : Int64) := (n / m, n % m)
def nonzero (_n m : Int64) : Bool := m != 0
def bitsSpec (n : UInt8) (s : UInt16) :=
  if s < 8 then (n <<< UInt8.ofNat s.toNat) ^^^ (n >>> UInt8.ofNat s.toNat) else 0
def sumSpec (xs : Array Int64) := xs.foldl (· + ·) 0
def pairSpec (n : Int64) := (n + 1, n)
def incSpec (n : Int64) := 1 + n
def chooseSpec (n : Int64) : Int64 := if n == 0 then 1 else if n == 2 || n == 4 then 2 else 3
def asciiSpec (s t : String) := Int64.ofNat (s.utf8ByteSize + t.utf8ByteSize)
def equalEntries (a b : Entry) : Bool := a.key == b.key && a.count == b.count
def compareSpec (a : Entry) (s : String) (v : UInt16) := equalEntries a ⟨s, v⟩
def halfSpec (x : Float) := x / 2
def firstSpec (xs : Array Int64) := xs[0]!
def nonempty (xs : Array Int64) : Bool := xs.size > 0
def changeSpec (x : Int64) := #[x+2, x]
def posSpec (x : Int64) := max 0 x
def isNonnegative (x : Int64) : Bool := x ≥ 0
def safeSpec (n m : Int64) := m != 0 && n / m > (0 : Int64)
def stepSpec (n : Int64) : Int64 := if n ≤ 0 then 0 else if n < 3 then 2 else 6
def stepRange (n : Int64) : Bool := n < 10
def narrowSpec (x : Int64) : UInt8 := UInt8.ofInt x.toInt
def switchSpec (n : Int64) := if n == 0 then (4 : Int64) else n - 1
def countSpec (n : Int64) := max n 0
def messageSpec (n : Int64) := n
def notZero (n : Int64) : Bool := n != 0
def tagValueSpec (x : GoValues.Tagged) := x.Count
`, leanfran.Models(Tagged{}))

//leanfran:model refines=arithmeticSpec
func Arithmetic(n, m int64) (int64, int64, int64) {
	pos, neg := n, n
	pos += m
	neg -= m
	product := n
	product *= m
	return pos, neg, product
}

//leanfran:model refines=divSpec requires=nonzero
func Divide(n, m int64) (int64, int64) { return n / m, n % m }

//leanfran:model refines=bitsSpec
func Bits(n uint8, s uint16) uint8 { return (n << s) ^ (n >> s) }

//leanfran:model refines=sumSpec
func Sum(xs []int64) int64 {
	var total int64
	for _, x := range xs {
		total += x
	}
	return total
}

//leanfran:model refines=pairSpec
func Pair(n int64) (int64, int64) {
	a, b := n, n+1
	a, b = b, a
	return a, b
}

//leanfran:model refines=chooseSpec
func Choose(n int64) int64 {
	switch v := n; v {
	case 0:
		return 1
	case 2, 4:
		return 2
	default:
		return 3
	}
}

//leanfran:model refines=asciiSpec
func Bytes(s, t string) int64 { return int64(len(max(s, t) + min(s, t))) }

//leanfran:model refines=compareSpec
func Compare(a Entry, s string, v uint16) bool { return a == (Entry{Key: s, Count: v}) }

//leanfran:model refines=halfSpec
func Half(x float64) float64 { return x / 2 }

//leanfran:model refines=firstSpec requires=nonempty
func First(xs []int64) int64 { return xs[0] }

//leanfran:model refines=changeSpec
func Change(x int64) []int64 {
	xs := []int64{0}
	xs[0] = x + 2
	xs = append(xs, x)
	return xs
}

//leanfran:model refines=posSpec requires=isNonnegative
func Positive(x int64) (int64, error) {
	if x < 0 {
		return 0, errors.New("negative")
	}
	return max(x, 0), nil
}

//leanfran:model refines=safeSpec
func Safe(n, m int64) bool { return m != 0 && n/m > 0 }

//leanfran:model refines=stepSpec requires=stepRange
func Steps(n int64) int64 {
	var total int64
	for i := int64(0); i < n; i++ {
		if i == 1 {
			continue
		}
		if i > 2 {
			break
		}
		total += i + 2
	}
	return total
}

//leanfran:model refines=incSpec
func WithCall(n int64) int64 {
	return helper.Step(n)
}

//leanfran:model refines=narrowSpec
func Narrow(n int64) uint8 { return uint8(n) }

//leanfran:model refines=switchSpec
func TrySwitch(n int64) (out int64) {
	switch n {
	case 0:
		out = 4
		break
	default:
		if x := n - 1; x != 0 {
			out = x
		}
	}
	return
}

//leanfran:model refines=countSpec requires=stepRange
func Count(n int64) int64 {
	var total int64
	for i := range n {
		if i >= 0 {
			total++
		}
	}
	return total
}

//leanfran:model refines=messageSpec requires=notZero
func Message(n int64) int64 {
	if n == 0 {
		panic("zero")
	}
	return n
}

//leanfran:model refines=tagValueSpec
func ReadTagged(x Tagged) uint16 { return x.Count }

//leanfran:model refines=flavorSpec
func FlavorOk(f Flavor) bool { return f == FlavorRobust }

func showPair(a, b int64) { fmt.Printf("%d %d\n", a, b) }

func panics(f func()) {
	defer func() { fmt.Println(recover() != nil) }()
	f()
}

func main() {
	for _, n := range []int64{-1, 0, 1, 2, 3, 6, math.MaxInt64} {
		a, b, c := Arithmetic(n, 2)
		fmt.Printf("%d %d %d\n", a, b, c)
		showPair(Pair(n))
		fmt.Println(Choose(n))
		fmt.Println(Safe(n, 0), Safe(n, 2))
		fmt.Println(Steps(n))
	}
	showPair(Divide(math.MinInt64, -1))
	showPair(Divide(-7, 3))
	panics(func() { Divide(3, 0) })
	for _, s := range []uint16{0, 7, 8, 256, 65535} {
		fmt.Println(Bits(131, s))
	}
	fmt.Println(Sum([]int64{4, -5, 7}))
	fmt.Println(Bytes("aé", "🙂"))
	fmt.Println(Compare(Entry{Key: "猫", Count: 18}, "猫", 18))
	fmt.Println(Compare(Entry{Key: "猫", Count: 18}, "猫", 19))
	fmt.Println(math.Signbit(Half(math.Copysign(0, -1))))
	fmt.Println(First([]int64{-8}))
	panics(func() { First(nil) })
	x := Change(-4)
	showPair(x[0], x[1])
	v, err := Positive(8)
	fmt.Println(v, err)
	_, err = Positive(-8)
	fmt.Println(err)
	fmt.Println(WithCall(100))
	fmt.Println(Narrow(-257))
	fmt.Println(TrySwitch(0), TrySwitch(1), TrySwitch(-1))
	fmt.Println(Count(-1), Count(0), Count(5))
	fmt.Println(Message(1))
	panics(func() { Message(0) })
	fmt.Println(ReadTagged(Tagged{Count: 0}))
	fmt.Println(FlavorOk(FlavorPlain), FlavorOk(FlavorRobust))
}
