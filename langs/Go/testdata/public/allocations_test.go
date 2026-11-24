package allocations

import (
	"math/big"
	"testing"
)

var initialTwice, initialTwiceErr = Twice(big.NewInt(7))

var initialTotal, initialTotalErr = Total(Order{Qty: big.NewInt(12), Price: big.NewInt(25)})

func TestPackageInitializer(t *testing.T) {
	if initialTwiceErr != nil || initialTwice.Int64() != 14 {
		t.Fatal(initialTwice, initialTwiceErr)
	}
	if initialTotalErr != nil || initialTotal.Int64() != 300 {
		t.Fatal(initialTotal, initialTotalErr)
	}
}

type allocationCase struct {
	name string
	max  float64
	call func(testing.TB)
}

func allocationCases() []allocationCase {
	n := big.NewInt(12)
	order := Order{Qty: n, Price: big.NewInt(25)}
	items := make([]*big.Int, 1000)
	for i := range items {
		items[i] = big.NewInt(int64(i + 1))
	}
	return []allocationCase{
		{"Twice", 2, func(tb testing.TB) {
			if got, err := Twice(n); err != nil || got.Int64() != 24 {
				tb.Fatal(got, err)
			}
		}},
		{"Total", 6, func(tb testing.TB) {
			if got, err := Total(order); err != nil || got.Int64() != 300 {
				tb.Fatal(got, err)
			}
		}},
		{"SumList", 1010, func(tb testing.TB) {
			if got, err := SumList(items); err != nil || got.Int64() != 500500 {
				tb.Fatal(got, err)
			}
		}},
		{"Add64", 0, func(tb testing.TB) {
			if got, err := Add64(12, 24); err != nil || got != 36 {
				tb.Fatal(got, err)
			}
		}},
	}
}

func TestAllocations(t *testing.T) {
	for _, c := range allocationCases() {
		t.Run(c.name, func(t *testing.T) {
			got := testing.AllocsPerRun(100, func() { c.call(t) })
			if got > c.max {
				t.Fatalf("allocations per call = %g, limit = %g", got, c.max)
			}
		})
	}
}

func BenchmarkPublic(b *testing.B) {
	for _, c := range allocationCases() {
		b.Run(c.name, func(b *testing.B) {
			b.ReportAllocs()
			for b.Loop() {
				c.call(b)
			}
		})
	}
}
