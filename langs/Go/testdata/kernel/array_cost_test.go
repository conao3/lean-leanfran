package kernel

import (
	"fmt"
	"os"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/conao3/leanfran-go/rt"
)

type controlField struct {
	p *byte
	n uint64
}

type controlArray struct {
	fields []controlField
}

var (
	controlSink *controlArray
	resultSink  []uint64
	bytesSink   []uint8
	countSink   int
)

func controlRead(a *controlArray) []uint64 {
	out := make([]uint64, len(a.fields))
	for i, f := range a.fields {
		out[i] = f.n
	}
	return out
}

func controlFrom(xs []uint64) *controlArray {
	fields := make([]controlField, len(xs))
	for i, x := range xs {
		fields[i] = controlField{n: x}
	}
	a := &controlArray{fields: fields}
	controlSink = a
	return a
}

func controlRecord(xs []uint64, x uint64) []uint64 {
	a := controlFrom(xs)
	a.fields = append(a.fields, controlField{n: x})
	return controlRead(a)
}

func controlDoubled(in *controlArray) *controlArray {
	out := &controlArray{fields: make([]controlField, 0, len(in.fields))}
	for _, f := range in.fields {
		out.fields = append(out.fields, controlField{n: f.n * 2})
	}
	return out
}

func controlBytesOf(s string) []uint8 {
	data := []byte(s)
	countSink = utf8.RuneCount(data)
	a := &controlArray{fields: make([]controlField, 0, len(data))}
	for i := range data {
		a.fields = append(a.fields, controlField{n: uint64(data[i])})
	}
	controlSink = a
	out := make([]uint8, len(a.fields))
	for i, f := range a.fields {
		out[i] = uint8(f.n)
	}
	return out
}

func timeCalls(calls int, f func()) time.Duration {
	start := time.Now()
	for range calls {
		f()
	}
	return time.Since(start)
}

func callRatio(calls, rounds int, call, control func()) float64 {
	defer runtime.GOMAXPROCS(runtime.GOMAXPROCS(1))
	ratios := make([]float64, rounds)
	for i := range ratios {
		ratios[i] = float64(timeCalls(calls, call)) / float64(timeCalls(calls, control))
	}
	slices.Sort(ratios)
	return ratios[rounds/2]
}

func TestArrayCallCost(t *testing.T) {
	if os.Getenv("LEANFRAN_ARRAY_COST") == "" {
		t.Skip("make test-array-cost sets LEANFRAN_ARRAY_COST")
	}
	scale := 1.0
	if s := os.Getenv("LEANFRAN_ARRAY_COST_SCALE"); s != "" {
		scale = checked(strconv.ParseFloat(s, 64))
	}
	xs := make([]uint64, 1_000)
	for i := range xs {
		xs[i] = uint64(i)
	}
	if got := Record(xs, 7); len(got) != len(xs)+1 || got[len(xs)] != 7 || got[999] != 999 {
		t.Fatal("Record returned the wrong array")
	}
	if got := Doubled(xs); len(got) != len(xs) || got[999] != 1998 {
		t.Fatal("Doubled returned the wrong array")
	}
	text := strings.Repeat("leanfran", 125)
	if got := checked(BytesOf(text)); string(got) != text {
		t.Fatal("BytesOf returned the wrong bytes")
	}
	fields := make([]rt.V, len(xs))
	for i, x := range xs {
		fields[i] = rt.Lean_box(x)
	}
	lean := rt.Array(fields)
	defer rt.Lean_dec(lean)
	control := controlFrom(xs)
	cases := []struct {
		name          string
		call, control func()
		allocations   float64
		limit         float64
	}{
		{"Record", func() { resultSink = Record(xs, 7) }, func() { resultSink = controlRecord(xs, 7) }, 4, 2.0},
		{"LeanPush", func() {
			rt.Lean_inc(lean)
			rt.Lean_dec(l_Kernel_doubled(lean))
		}, func() { controlSink = controlDoubled(control) }, 2, 2.5},
		{"BytesOf", func() { bytesSink = checked(BytesOf(text)) }, func() { bytesSink = controlBytesOf(text) }, 7, 4.6},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := testing.AllocsPerRun(100, c.call); got > c.allocations {
				t.Fatalf("%g allocations per call with 1,000 elements, want at most %g", got, c.allocations)
			}
			limit := c.limit * scale
			best := 0.0
			for attempt := range 3 {
				ratio := callRatio(200, 9, c.call, c.control)
				t.Logf("attempt %d: %.2f times the Go control, limit %.2f", attempt, ratio, limit)
				if attempt == 0 || ratio < best {
					best = ratio
				}
				if best <= limit {
					return
				}
			}
			t.Fatalf("a call with 1,000 elements took %.2f times the Go control, want at most %.2f", best, limit)
		})
	}
}

func BenchmarkArrayCall(b *testing.B) {
	for _, n := range []int{10, 1_000, 100_000} {
		xs := make([]uint64, n)
		b.Run(fmt.Sprintf("Record/%d", n), func(b *testing.B) {
			b.ReportAllocs()
			for b.Loop() {
				resultSink = Record(xs, 1)
			}
		})
		b.Run(fmt.Sprintf("HandleReplaceLast/%d", n), func(b *testing.B) {
			v := Value.NewArrayUInt64(xs)
			x := Value.NewUInt64(1)
			b.ReportAllocs()
			for b.Loop() {
				v = Handle.ReplaceLast(v.Take(), x.Borrow())
			}
			v.Close()
			x.Close()
		})
		b.Run(fmt.Sprintf("Doubled/%d", n), func(b *testing.B) {
			b.ReportAllocs()
			for b.Loop() {
				resultSink = Doubled(xs)
			}
		})
	}
}
