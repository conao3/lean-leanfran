package allocations

import (
	"encoding/json"
	"math/big"
	"testing"
)

func TestPackageInitializer(t *testing.T) {
	if initialTwiceErr != nil || initialTwice.Int64() != 14 {
		t.Fatal(initialTwice, initialTwiceErr)
	}
	if initialTotalErr != nil || initialTotal.Int64() != 300 {
		t.Fatal(initialTotal, initialTotalErr)
	}
	var order Order
	if initialJSONErr != nil {
		t.Fatal(initialJSONErr)
	}
	if err := json.Unmarshal(initialJSON, &order); err != nil || order.Qty.Int64() != 12 || order.Price.Int64() != 25 {
		t.Fatal(order, err)
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
			if got := Add64(12, 24); got != 36 {
				tb.Fatal(got)
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
