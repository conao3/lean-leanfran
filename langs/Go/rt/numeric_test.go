package rt

import (
	"math"
	"testing"
)

func TestNatPromotion(t *testing.T) {
	small := NatFromUint64(math.MaxInt64)
	one := NatFromUint64(1)
	big := Lean_nat_add(small, one)
	if big.p == nil || NatString(big) != "9223372036854775808" {
		t.Fatalf("addition failed to promote: %s", NatString(big))
	}
	if sub := Lean_nat_sub(big, one); sub != small {
		t.Fatalf("subtraction failed to normalize: %s", NatString(sub))
	}
	if zero := Lean_nat_sub(one, big); zero != (V{}) {
		t.Fatalf("subtraction failed to saturate: %s", NatString(zero))
	}
	wide := Lean_nat_mul(big, big)
	if got := NatString(wide); got != "85070591730234615865843651857942052864" {
		t.Fatalf("multiplication yielded %s", got)
	}
	if got := Lean_nat_dec_eq(Lean_nat_div(wide, big), big); got != 1 {
		t.Fatal("division lost precision")
	}
	if remainder := Lean_nat_mod(big, V{}); remainder != big || big.p.rc != 2 {
		t.Fatal("modulo by zero did not retain the borrowed operand")
	}
}

func TestIntBoundaries(t *testing.T) {
	least := IntFromInt64(math.MinInt64)
	minusOne := IntFromInt64(-1)
	positive := Lean_int_div(least, minusOne)
	if positive.p == nil || IntString(positive) != "9223372036854775808" {
		t.Fatalf("overflowing division yielded %s", IntString(positive))
	}
	if got := Lean_int_add(positive, minusOne); got != IntFromInt64(math.MaxInt64) {
		t.Fatalf("addition failed to normalize: %s", IntString(got))
	}
	if got := Lean_int_sub(least, IntFromInt64(1)); IntString(got) != "-9223372036854775809" {
		t.Fatalf("overflowing subtraction yielded %s", IntString(got))
	}
	if got := Lean_int_mul(least, minusOne); Lean_int_dec_eq(got, positive) != 1 {
		t.Fatalf("overflowing multiplication yielded %s", IntString(got))
	}

	a, b := IntFromInt64(-17), IntFromInt64(-5)
	if q, r := Lean_int_div(a, b), Lean_int_mod(a, b); q != IntFromInt64(3) || r != IntFromInt64(-2) {
		t.Fatalf("truncated division yielded (%s, %s)", IntString(q), IntString(r))
	}
	if q, r := Lean_int_ediv(a, b), Lean_int_emod(a, b); q != IntFromInt64(4) || r != IntFromInt64(3) {
		t.Fatalf("Euclidean division yielded (%s, %s)", IntString(q), IntString(r))
	}
}

func TestFixedWidthBoundaries(t *testing.T) {
	if got := Lean_uint8_add(255, 2); got != 1 {
		t.Fatalf("UInt8 wrapping addition yielded %d", got)
	}
	if got := Lean_int8_div(128, 255); got != 128 {
		t.Fatalf("Int8 wrapping division yielded %d", got)
	}
	if got := Lean_int8_shift_right(128, 255); got != 255 {
		t.Fatalf("Int8 arithmetic shift yielded %d", got)
	}
	if got := Lean_int8_to_int64(255); got != math.MaxUint64 {
		t.Fatalf("Int8 sign extension yielded %d", got)
	}
	if got := Lean_uint64_of_nat(Lean_cstr_to_nat("18446744073709551617")); got != 1 {
		t.Fatalf("UInt64 conversion yielded %d", got)
	}
	if got := Lean_int64_of_int(Lean_cstr_to_int("-18446744073709551617")); got != math.MaxUint64 {
		t.Fatalf("Int64 conversion yielded %d", got)
	}
}

func TestFloatBoundaries(t *testing.T) {
	negativeZero := math.Copysign(0, -1)
	if boxed := Lean_box_float(negativeZero); boxed.p != nil || math.Float64bits(Lean_unbox_float(boxed)) != 1<<63 {
		t.Fatal("Float boxing lost the sign bit of zero")
	}
	if got := String(Lean_float_to_string(negativeZero)); got != "-0.000000" {
		t.Fatalf("Float negative zero formatted as %q", got)
	}
	if got := String(Lean_float32_to_string(1.25)); got != "1.250000" {
		t.Fatalf("Float32 formatted as %q", got)
	}
	if got := Lean_float_to_uint64(math.Inf(1)); got != math.MaxUint64 {
		t.Fatalf("Float unsigned saturation yielded %d", got)
	}
	if got := Lean_float32_to_int8(float32(math.Inf(-1))); got != 128 {
		t.Fatalf("Float32 signed saturation yielded %d", got)
	}
	if got := Lean_float_to_int64(math.NaN()); got != 0 {
		t.Fatalf("Float NaN conversion yielded %d", got)
	}
}
