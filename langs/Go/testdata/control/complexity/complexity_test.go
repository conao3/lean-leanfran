package complexity

import (
	"runtime"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/conao3/leanfran-go/rt"
)

func checkArray(value rt.V, n int, reversed bool) bool {
	if rt.Lean_array_size(value) != uint64(n) {
		return false
	}
	for i := range n {
		want := i + 1
		if reversed {
			want = n - i
		}
		if rt.Lean_unbox(rt.Lean_array_uget_borrowed(value, uint64(i))) != uint64(want) {
			return false
		}
	}
	return true
}

func checkBytes(value rt.V, n int) bool {
	if rt.Lean_sarray_size(value) != uint64(n) {
		return false
	}
	for i := range n {
		if rt.Lean_byte_array_uget(value, uint64(i)) != 255 {
			return false
		}
	}
	return true
}

func TestComplexity(t *testing.T) {
	maxProcs := runtime.GOMAXPROCS(1)
	t.Cleanup(func() { runtime.GOMAXPROCS(maxProcs) })
	suffix := rt.Lean_mark_persistent(rt.Lean_mk_string("é猫"))
	emptyString := func(_ int) rt.V { return rt.Lean_mk_string("") }
	cases := []struct {
		name  string
		run   func(rt.V, rt.V) rt.V
		input func(int) rt.V
		check func(rt.V, int) bool
	}{
		{
			name:  "Array.push",
			run:   L_LeanGoTest_ControlComplexity_arrayPush,
			input: func(_ int) rt.V { return rt.Lean_mk_empty_array() },
			check: func(value rt.V, n int) bool { return checkArray(value, n, true) },
		},
		{
			name:  "Array.set",
			run:   L_LeanGoTest_ControlComplexity_arraySet,
			input: func(n int) rt.V { return rt.Lean_mk_array(rt.NatFromUint64(uint64(n)), rt.V{}) },
			check: func(value rt.V, n int) bool { return checkArray(value, n, false) },
		},
		{
			name:  "String.push",
			run:   L_LeanGoTest_ControlComplexity_stringPush,
			input: emptyString,
			check: func(value rt.V, n int) bool { return rt.String(value) == strings.Repeat("猫", n) },
		},
		{
			name: "String.++",
			run: func(n, value rt.V) rt.V {
				return L_LeanGoTest_ControlComplexity_stringAppend(n, value, suffix)
			},
			input: emptyString,
			check: func(value rt.V, n int) bool { return rt.String(value) == strings.Repeat("é猫", n) },
		},
		{
			name:  "ByteArray.push",
			run:   L_LeanGoTest_ControlComplexity_bytePush,
			input: func(_ int) rt.V { return rt.Lean_mk_empty_byte_array(rt.V{}) },
			check: checkBytes,
		},
		{
			name: "ByteArray.set",
			run:  L_LeanGoTest_ControlComplexity_byteSet,
			input: func(n int) rt.V {
				return rt.Lean_byte_array_mk(rt.Lean_mk_array(rt.NatFromUint64(uint64(n)), rt.V{}))
			},
			check: checkBytes,
		},
	}

	const n = 100_000
	const samples = 7
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			measure := func(size int) time.Duration {
				t.Helper()
				count := rt.NatFromUint64(uint64(size))
				input := test.input(size)
				runtime.GC()
				start := time.Now()
				result := test.run(count, input)
				elapsed := time.Since(start)
				if !test.check(result, size) {
					t.Fatalf("incorrect result for %d updates", size)
				}
				rt.Lean_dec(result)
				return elapsed
			}
			measure(100)
			small, large := make([]time.Duration, samples), make([]time.Duration, samples)
			for i := range samples {
				small[i] = measure(n)
				large[i] = measure(4 * n)
			}
			slices.Sort(small)
			slices.Sort(large)
			ratio := float64(large[samples/2]) / float64(small[samples/2])
			t.Logf("n=%d %s, 4n=%d %s, ratio %.2f", n, small[samples/2], 4*n, large[samples/2], ratio)
			if ratio >= 8 {
				t.Errorf("expected ratio < 8, got %.2f", ratio)
			}
		})
	}
}
