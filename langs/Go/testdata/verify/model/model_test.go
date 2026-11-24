package main

import (
	"errors"
	"math"
	"math/rand/v2"
	"slices"
	"testing"

	"fixture.test/translate/models"
	"github.com/conao3/leanfran-go"
)

func panicFrom(f func()) (panicked bool) {
	defer func() { panicked = recover() != nil }()
	f()
	return false
}

func outcome(t *testing.T, op, kind string, panicked bool, err error, args ...any) {
	t.Helper()
	if panicked {
		var modeled *leanfran.ExceptError[string]
		if !errors.As(err, &modeled) || modeled.Value != kind {
			t.Fatalf("%s%v: Go panicked, model error = %v", op, args, err)
		}
	} else if err != nil {
		t.Fatalf("%s%v: Go returned, model error = %v", op, args, err)
	}
}

func TestGoOperations(t *testing.T) {
	edges := []int64{math.MinInt64, math.MinInt64 + 1, -256, -9, -1, 0, 1, 7, 8, 9, 63, 64, 255, 256, math.MaxInt64}
	rng := rand.New(rand.NewPCG(20261124, 0))
	check := func(a, b int64) {
		var q, r int64
		p := panicFrom(func() { q, r = a/b, a%b })
		got, err := models.Signed(a, b)
		outcome(t, "signed", "divideByZero", p, err, a, b)
		if !p && (got.Fst != q || got.Snd != r) {
			t.Fatalf("signed(%d, %d) = %v, want (%d, %d)", a, b, got, q, r)
		}
		ua, ub := uint64(a), uint64(b)
		var uq, ur uint64
		p = panicFrom(func() { uq, ur = ua/ub, ua%ub })
		gotU, err := models.Unsigned(ua, ub)
		outcome(t, "unsigned", "divideByZero", p, err, ua, ub)
		if !p && (gotU.Fst != uq || gotU.Snd != ur) {
			t.Fatalf("unsigned(%d, %d) = %v, want (%d, %d)", ua, ub, gotU, uq, ur)
		}
		gotS, err := models.Shifts(uint8(a), ub)
		if err != nil || gotS.Fst != uint8(a)<<ub || gotS.Snd != uint8(a)>>ub {
			t.Fatalf("shifts(%d, %d) = %v, %v", uint8(a), ub, gotS, err)
		}
		var signedShift uint8
		p = panicFrom(func() { signedShift = uint8(a) << b })
		s, err := models.SignedShift(uint8(a), b)
		outcome(t, "signedShift", "negativeShift", p, err, uint8(a), b)
		if !p && s != signedShift {
			t.Fatalf("signedShift(%d, %d) = %d, want %d", a, b, s, signedShift)
		}
		n := rng.IntN(9)
		var xs []int64
		for i := range n {
			xs = append(xs, a+int64(i))
		}
		var value int64
		p = panicFrom(func() { value = xs[b] })
		at, err := models.IndexValue(xs, b)
		outcome(t, "at", "indexOutOfRange", p, err, xs, b)
		if !p && at != value {
			t.Fatalf("at(%v, %d) = %d, want %d", xs, b, at, value)
		}
		ys := slices.Clone(xs)
		p = panicFrom(func() { ys[b] = a })
		updated, err := models.Update(xs, b, a)
		outcome(t, "update", "indexOutOfRange", p, err, xs, b, a)
		if !p && !slices.Equal(updated, ys) {
			t.Fatalf("update(%v, %d, %d) = %v, want %v", xs, b, a, updated, ys)
		}
		length, err := models.Length(xs)
		if err != nil || length != int64(len(xs)) {
			t.Fatalf("len(%v) = %d, %v", xs, length, err)
		}
		converted, err := models.Convert(a)
		if err != nil || converted.Fst != uint8(a) || converted.Snd.Fst != uint64(a) || converted.Snd.Snd != int8(a) {
			t.Fatalf("convert(%d) = %v, %v", a, converted, err)
		}
	}
	for _, a := range edges {
		for _, b := range edges {
			check(a, b)
		}
	}
	for range 512 {
		check(int64(rng.Uint64()), int64(rng.Uint64()))
	}

	corpus := []string{"", "\x00", "a", "é", "aé\x00", "猫", "🙂"}
	for _, a := range corpus {
		for _, b := range corpus {
			got, err := models.Text(a, b)
			if err != nil || got.Fst != a+b || got.Snd.Fst != int64(len(a)) ||
				got.Snd.Snd.Fst != (a < b) || got.Snd.Snd.Snd != (a == b) {
				t.Fatalf("text(%q, %q) = %v, %v", a, b, got, err)
			}
			bounds, err := models.StringBounds(a, b)
			if err != nil || bounds.Fst != min(a, b) || bounds.Snd != max(a, b) {
				t.Fatalf("stringBounds(%q, %q) = %v, %v", a, b, bounds, err)
			}
		}
	}

	floats := []float64{0, math.Copysign(0, -1), math.Inf(1), math.Inf(-1), math.NaN(), -1, 1}
	same := func(a, b float64) bool {
		return math.IsNaN(a) && math.IsNaN(b) || math.Float64bits(a) == math.Float64bits(b)
	}
	for _, a := range floats {
		for _, b := range floats {
			got, err := models.Bounds(a, b)
			if err != nil || !same(got.Fst, min(a, b)) || !same(got.Snd.Fst, max(a, b)) ||
				got.Snd.Snd.Fst != (a < b) || got.Snd.Snd.Snd != (a == b) {
				t.Fatalf("bounds(%v, %v) = %v, %v", a, b, got, err)
			}
		}
	}
}
