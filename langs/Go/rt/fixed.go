package rt

import "math/bits"

type fixedInteger interface {
	~uint8 | ~uint16 | ~uint32 | ~uint64 | ~int8 | ~int16 | ~int32 | ~int64
}

func fixedDiv[T fixedInteger](a, b T) T {
	if b == 0 {
		return 0
	}
	return a / b
}

func fixedMod[T fixedInteger](a, b T) T {
	if b == 0 {
		return a
	}
	return a % b
}

func fixedAbs[T ~int8 | ~int16 | ~int32 | ~int64](a T) T {
	if a < 0 {
		return -a
	}
	return a
}

func fixedNatBits(a V) uint64 {
	if a.p == nil {
		return a.n
	}
	return bigNatBits(a)
}

//go:noinline
func bigNatBits(a V) uint64 { return uint64(natBig(a).Bits()[0]) }

func fixedIntBits(a V) uint64 {
	if a.p == nil {
		return a.n
	}
	n := intBig(a)
	words := n.Bits()
	if n.Sign() < 0 {
		return -uint64(words[0])
	}
	return uint64(words[0])
}

func Lean_uint8_add(a, b uint8) uint8         { return a + b }
func Lean_uint8_sub(a, b uint8) uint8         { return a - b }
func Lean_uint8_mul(a, b uint8) uint8         { return a * b }
func Lean_uint8_land(a, b uint8) uint8        { return a & b }
func Lean_uint8_lor(a, b uint8) uint8         { return a | b }
func Lean_uint8_xor(a, b uint8) uint8         { return a ^ b }
func Lean_uint8_neg(a uint8) uint8            { return -a }
func Lean_uint8_complement(a uint8) uint8     { return ^a }
func Lean_uint8_shift_left(a, b uint8) uint8  { return a << (b & 7) }
func Lean_uint8_shift_right(a, b uint8) uint8 { return a >> (b & 7) }
func Lean_uint8_div(a, b uint8) uint8         { return fixedDiv(a, b) }
func Lean_uint8_mod(a, b uint8) uint8         { return fixedMod(a, b) }
func Lean_uint8_dec_eq(a, b uint8) uint8      { return decision(a == b) }
func Lean_uint8_dec_le(a, b uint8) uint8      { return decision(a <= b) }
func Lean_uint8_dec_lt(a, b uint8) uint8      { return decision(a < b) }
func Lean_uint8_of_nat(a V) uint8             { return uint8(fixedNatBits(a)) }
func Lean_uint8_log2(a uint8) uint8           { return uint8(max(0, bits.Len8(a)-1)) }
func Lean_uint8_to_nat(a uint8) V             { return NatFromUint64(uint64(a)) }
func Lean_uint8_of_nat_mk(a V) uint8 {
	value := Lean_uint8_of_nat(a)
	Lean_dec(a)
	return value
}
func Lean_uint8_to_uint16(a uint8) uint16   { return uint16(a) }
func Lean_uint8_to_uint32(a uint8) uint32   { return uint32(a) }
func Lean_uint8_to_uint64(a uint8) uint64   { return uint64(a) }
func Lean_uint8_to_usize(a uint8) uint64    { return uint64(a) }
func Lean_uint8_to_float(a uint8) float64   { return float64(a) }
func Lean_uint8_to_float32(a uint8) float32 { return float32(a) }

func Lean_uint16_add(a, b uint16) uint16         { return a + b }
func Lean_uint16_sub(a, b uint16) uint16         { return a - b }
func Lean_uint16_mul(a, b uint16) uint16         { return a * b }
func Lean_uint16_land(a, b uint16) uint16        { return a & b }
func Lean_uint16_lor(a, b uint16) uint16         { return a | b }
func Lean_uint16_xor(a, b uint16) uint16         { return a ^ b }
func Lean_uint16_neg(a uint16) uint16            { return -a }
func Lean_uint16_complement(a uint16) uint16     { return ^a }
func Lean_uint16_shift_left(a, b uint16) uint16  { return a << (b & 15) }
func Lean_uint16_shift_right(a, b uint16) uint16 { return a >> (b & 15) }
func Lean_uint16_div(a, b uint16) uint16         { return fixedDiv(a, b) }
func Lean_uint16_mod(a, b uint16) uint16         { return fixedMod(a, b) }
func Lean_uint16_dec_eq(a, b uint16) uint8       { return decision(a == b) }
func Lean_uint16_dec_le(a, b uint16) uint8       { return decision(a <= b) }
func Lean_uint16_dec_lt(a, b uint16) uint8       { return decision(a < b) }
func Lean_uint16_of_nat(a V) uint16              { return uint16(fixedNatBits(a)) }
func Lean_uint16_log2(a uint16) uint16           { return uint16(max(0, bits.Len16(a)-1)) }
func Lean_uint16_to_nat(a uint16) V              { return NatFromUint64(uint64(a)) }
func Lean_uint16_of_nat_mk(a V) uint16 {
	value := Lean_uint16_of_nat(a)
	Lean_dec(a)
	return value
}
func Lean_uint16_to_uint8(a uint16) uint8     { return uint8(a) }
func Lean_uint16_to_uint32(a uint16) uint32   { return uint32(a) }
func Lean_uint16_to_uint64(a uint16) uint64   { return uint64(a) }
func Lean_uint16_to_usize(a uint16) uint64    { return uint64(a) }
func Lean_uint16_to_float(a uint16) float64   { return float64(a) }
func Lean_uint16_to_float32(a uint16) float32 { return float32(a) }

func Lean_uint32_add(a, b uint32) uint32         { return a + b }
func Lean_uint32_sub(a, b uint32) uint32         { return a - b }
func Lean_uint32_mul(a, b uint32) uint32         { return a * b }
func Lean_uint32_land(a, b uint32) uint32        { return a & b }
func Lean_uint32_lor(a, b uint32) uint32         { return a | b }
func Lean_uint32_xor(a, b uint32) uint32         { return a ^ b }
func Lean_uint32_neg(a uint32) uint32            { return -a }
func Lean_uint32_complement(a uint32) uint32     { return ^a }
func Lean_uint32_shift_left(a, b uint32) uint32  { return a << (b & 31) }
func Lean_uint32_shift_right(a, b uint32) uint32 { return a >> (b & 31) }
func Lean_uint32_div(a, b uint32) uint32         { return fixedDiv(a, b) }
func Lean_uint32_mod(a, b uint32) uint32         { return fixedMod(a, b) }
func Lean_uint32_dec_eq(a, b uint32) uint8       { return decision(a == b) }
func Lean_uint32_dec_le(a, b uint32) uint8       { return decision(a <= b) }
func Lean_uint32_dec_lt(a, b uint32) uint8       { return decision(a < b) }
func Lean_uint32_of_nat(a V) uint32              { return uint32(fixedNatBits(a)) }
func Lean_uint32_log2(a uint32) uint32           { return uint32(max(0, bits.Len32(a)-1)) }
func Lean_uint32_to_nat(a uint32) V              { return NatFromUint64(uint64(a)) }
func Lean_uint32_of_nat_mk(a V) uint32 {
	value := Lean_uint32_of_nat(a)
	Lean_dec(a)
	return value
}
func Lean_uint32_to_uint8(a uint32) uint8     { return uint8(a) }
func Lean_uint32_to_uint16(a uint32) uint16   { return uint16(a) }
func Lean_uint32_to_uint64(a uint32) uint64   { return uint64(a) }
func Lean_uint32_to_usize(a uint32) uint64    { return uint64(a) }
func Lean_uint32_to_float(a uint32) float64   { return float64(a) }
func Lean_uint32_to_float32(a uint32) float32 { return float32(a) }

func Lean_uint64_add(a, b uint64) uint64         { return a + b }
func Lean_uint64_sub(a, b uint64) uint64         { return a - b }
func Lean_uint64_mul(a, b uint64) uint64         { return a * b }
func Lean_uint64_land(a, b uint64) uint64        { return a & b }
func Lean_uint64_lor(a, b uint64) uint64         { return a | b }
func Lean_uint64_xor(a, b uint64) uint64         { return a ^ b }
func Lean_uint64_neg(a uint64) uint64            { return -a }
func Lean_uint64_complement(a uint64) uint64     { return ^a }
func Lean_uint64_shift_left(a, b uint64) uint64  { return a << (b & 63) }
func Lean_uint64_shift_right(a, b uint64) uint64 { return a >> (b & 63) }
func Lean_uint64_div(a, b uint64) uint64         { return fixedDiv(a, b) }
func Lean_uint64_mod(a, b uint64) uint64         { return fixedMod(a, b) }
func Lean_uint64_dec_eq(a, b uint64) uint8       { return decision(a == b) }
func Lean_uint64_dec_le(a, b uint64) uint8       { return decision(a <= b) }
func Lean_uint64_dec_lt(a, b uint64) uint8       { return decision(a < b) }
func Lean_uint64_of_nat(a V) uint64              { return fixedNatBits(a) }
func Lean_uint64_log2(a uint64) uint64           { return uint64(max(0, bits.Len64(a)-1)) }
func Lean_uint64_to_nat(a uint64) V              { return NatFromUint64(a) }
func Lean_uint64_of_nat_mk(a V) uint64 {
	value := Lean_uint64_of_nat(a)
	Lean_dec(a)
	return value
}
func Lean_uint64_to_uint8(a uint64) uint8     { return uint8(a) }
func Lean_uint64_to_uint16(a uint64) uint16   { return uint16(a) }
func Lean_uint64_to_uint32(a uint64) uint32   { return uint32(a) }
func Lean_uint64_to_usize(a uint64) uint64    { return a }
func Lean_uint64_to_float(a uint64) float64   { return float64(a) }
func Lean_uint64_to_float32(a uint64) float32 { return float32(a) }

func Lean_usize_add(a, b uint64) uint64         { return a + b }
func Lean_usize_sub(a, b uint64) uint64         { return a - b }
func Lean_usize_mul(a, b uint64) uint64         { return a * b }
func Lean_usize_land(a, b uint64) uint64        { return a & b }
func Lean_usize_lor(a, b uint64) uint64         { return a | b }
func Lean_usize_xor(a, b uint64) uint64         { return a ^ b }
func Lean_usize_neg(a uint64) uint64            { return -a }
func Lean_usize_complement(a uint64) uint64     { return ^a }
func Lean_usize_shift_left(a, b uint64) uint64  { return a << (b & 63) }
func Lean_usize_shift_right(a, b uint64) uint64 { return a >> (b & 63) }
func Lean_usize_div(a, b uint64) uint64         { return fixedDiv(a, b) }
func Lean_usize_mod(a, b uint64) uint64         { return fixedMod(a, b) }
func Lean_usize_dec_eq(a, b uint64) uint8       { return decision(a == b) }
func Lean_usize_dec_le(a, b uint64) uint8       { return decision(a <= b) }
func Lean_usize_dec_lt(a, b uint64) uint8       { return decision(a < b) }
func Lean_usize_of_nat(a V) uint64              { return fixedNatBits(a) }
func Lean_usize_log2(a uint64) uint64           { return uint64(max(0, bits.Len64(a)-1)) }
func Lean_usize_to_nat(a uint64) V              { return NatFromUint64(a) }
func Lean_usize_of_nat_mk(a V) uint64 {
	value := Lean_usize_of_nat(a)
	Lean_dec(a)
	return value
}
func Lean_usize_to_uint8(a uint64) uint8     { return uint8(a) }
func Lean_usize_to_uint16(a uint64) uint16   { return uint16(a) }
func Lean_usize_to_uint32(a uint64) uint32   { return uint32(a) }
func Lean_usize_to_uint64(a uint64) uint64   { return a }
func Lean_usize_to_float(a uint64) float64   { return float64(a) }
func Lean_usize_to_float32(a uint64) float32 { return float32(a) }

func Lean_int8_add(a, b uint8) uint8         { return a + b }
func Lean_int8_sub(a, b uint8) uint8         { return a - b }
func Lean_int8_mul(a, b uint8) uint8         { return a * b }
func Lean_int8_land(a, b uint8) uint8        { return a & b }
func Lean_int8_lor(a, b uint8) uint8         { return a | b }
func Lean_int8_xor(a, b uint8) uint8         { return a ^ b }
func Lean_int8_neg(a uint8) uint8            { return -a }
func Lean_int8_complement(a uint8) uint8     { return ^a }
func Lean_int8_shift_left(a, b uint8) uint8  { return a << (b & 7) }
func Lean_int8_shift_right(a, b uint8) uint8 { return uint8(int8(a) >> (b & 7)) }
func Lean_int8_div(a, b uint8) uint8         { return uint8(fixedDiv(int8(a), int8(b))) }
func Lean_int8_mod(a, b uint8) uint8         { return uint8(fixedMod(int8(a), int8(b))) }
func Lean_int8_dec_eq(a, b uint8) uint8      { return decision(int8(a) == int8(b)) }
func Lean_int8_dec_le(a, b uint8) uint8      { return decision(int8(a) <= int8(b)) }
func Lean_int8_dec_lt(a, b uint8) uint8      { return decision(int8(a) < int8(b)) }
func Lean_int8_of_nat(a V) uint8             { return uint8(fixedNatBits(a)) }
func Lean_int8_of_int(a V) uint8             { return uint8(fixedIntBits(a)) }
func Lean_int8_abs(a uint8) uint8            { return uint8(fixedAbs(int8(a))) }
func Lean_int8_to_uint8(a uint8) uint8       { return a }
func Lean_int8_to_uint16(a uint8) uint16     { return uint16(int8(a)) }
func Lean_int8_to_uint32(a uint8) uint32     { return uint32(int8(a)) }
func Lean_int8_to_uint64(a uint8) uint64     { return uint64(int8(a)) }
func Lean_int8_to_usize(a uint8) uint64      { return uint64(int8(a)) }
func Lean_int8_to_int(a uint8) V             { return IntFromInt64(int64(int8(a))) }
func Lean_int8_to_int16(a uint8) uint16      { return uint16(int8(a)) }
func Lean_int8_to_int32(a uint8) uint32      { return uint32(int8(a)) }
func Lean_int8_to_int64(a uint8) uint64      { return uint64(int8(a)) }
func Lean_int8_to_isize(a uint8) uint64      { return uint64(int8(a)) }
func Lean_int8_to_float(a uint8) float64     { return float64(int8(a)) }
func Lean_int8_to_float32(a uint8) float32   { return float32(int8(a)) }

func Lean_int16_add(a, b uint16) uint16         { return a + b }
func Lean_int16_sub(a, b uint16) uint16         { return a - b }
func Lean_int16_mul(a, b uint16) uint16         { return a * b }
func Lean_int16_land(a, b uint16) uint16        { return a & b }
func Lean_int16_lor(a, b uint16) uint16         { return a | b }
func Lean_int16_xor(a, b uint16) uint16         { return a ^ b }
func Lean_int16_neg(a uint16) uint16            { return -a }
func Lean_int16_complement(a uint16) uint16     { return ^a }
func Lean_int16_shift_left(a, b uint16) uint16  { return a << (b & 15) }
func Lean_int16_shift_right(a, b uint16) uint16 { return uint16(int16(a) >> (b & 15)) }
func Lean_int16_div(a, b uint16) uint16         { return uint16(fixedDiv(int16(a), int16(b))) }
func Lean_int16_mod(a, b uint16) uint16         { return uint16(fixedMod(int16(a), int16(b))) }
func Lean_int16_dec_eq(a, b uint16) uint8       { return decision(int16(a) == int16(b)) }
func Lean_int16_dec_le(a, b uint16) uint8       { return decision(int16(a) <= int16(b)) }
func Lean_int16_dec_lt(a, b uint16) uint8       { return decision(int16(a) < int16(b)) }
func Lean_int16_of_nat(a V) uint16              { return uint16(fixedNatBits(a)) }
func Lean_int16_of_int(a V) uint16              { return uint16(fixedIntBits(a)) }
func Lean_int16_abs(a uint16) uint16            { return uint16(fixedAbs(int16(a))) }
func Lean_int16_to_uint8(a uint16) uint8        { return uint8(a) }
func Lean_int16_to_uint16(a uint16) uint16      { return a }
func Lean_int16_to_uint32(a uint16) uint32      { return uint32(int16(a)) }
func Lean_int16_to_uint64(a uint16) uint64      { return uint64(int16(a)) }
func Lean_int16_to_usize(a uint16) uint64       { return uint64(int16(a)) }
func Lean_int16_to_int(a uint16) V              { return IntFromInt64(int64(int16(a))) }
func Lean_int16_to_int8(a uint16) uint8         { return uint8(a) }
func Lean_int16_to_int32(a uint16) uint32       { return uint32(int16(a)) }
func Lean_int16_to_int64(a uint16) uint64       { return uint64(int16(a)) }
func Lean_int16_to_isize(a uint16) uint64       { return uint64(int16(a)) }
func Lean_int16_to_float(a uint16) float64      { return float64(int16(a)) }
func Lean_int16_to_float32(a uint16) float32    { return float32(int16(a)) }

func Lean_int32_add(a, b uint32) uint32         { return a + b }
func Lean_int32_sub(a, b uint32) uint32         { return a - b }
func Lean_int32_mul(a, b uint32) uint32         { return a * b }
func Lean_int32_land(a, b uint32) uint32        { return a & b }
func Lean_int32_lor(a, b uint32) uint32         { return a | b }
func Lean_int32_xor(a, b uint32) uint32         { return a ^ b }
func Lean_int32_neg(a uint32) uint32            { return -a }
func Lean_int32_complement(a uint32) uint32     { return ^a }
func Lean_int32_shift_left(a, b uint32) uint32  { return a << (b & 31) }
func Lean_int32_shift_right(a, b uint32) uint32 { return uint32(int32(a) >> (b & 31)) }
func Lean_int32_div(a, b uint32) uint32         { return uint32(fixedDiv(int32(a), int32(b))) }
func Lean_int32_mod(a, b uint32) uint32         { return uint32(fixedMod(int32(a), int32(b))) }
func Lean_int32_dec_eq(a, b uint32) uint8       { return decision(int32(a) == int32(b)) }
func Lean_int32_dec_le(a, b uint32) uint8       { return decision(int32(a) <= int32(b)) }
func Lean_int32_dec_lt(a, b uint32) uint8       { return decision(int32(a) < int32(b)) }
func Lean_int32_of_nat(a V) uint32              { return uint32(fixedNatBits(a)) }
func Lean_int32_of_int(a V) uint32              { return uint32(fixedIntBits(a)) }
func Lean_int32_abs(a uint32) uint32            { return uint32(fixedAbs(int32(a))) }
func Lean_int32_to_uint8(a uint32) uint8        { return uint8(a) }
func Lean_int32_to_uint16(a uint32) uint16      { return uint16(a) }
func Lean_int32_to_uint32(a uint32) uint32      { return a }
func Lean_int32_to_uint64(a uint32) uint64      { return uint64(int32(a)) }
func Lean_int32_to_usize(a uint32) uint64       { return uint64(int32(a)) }
func Lean_int32_to_int(a uint32) V              { return IntFromInt64(int64(int32(a))) }
func Lean_int32_to_int8(a uint32) uint8         { return uint8(a) }
func Lean_int32_to_int16(a uint32) uint16       { return uint16(a) }
func Lean_int32_to_int64(a uint32) uint64       { return uint64(int32(a)) }
func Lean_int32_to_isize(a uint32) uint64       { return uint64(int32(a)) }
func Lean_int32_to_float(a uint32) float64      { return float64(int32(a)) }
func Lean_int32_to_float32(a uint32) float32    { return float32(int32(a)) }

func Lean_int64_add(a, b uint64) uint64         { return a + b }
func Lean_int64_sub(a, b uint64) uint64         { return a - b }
func Lean_int64_mul(a, b uint64) uint64         { return a * b }
func Lean_int64_land(a, b uint64) uint64        { return a & b }
func Lean_int64_lor(a, b uint64) uint64         { return a | b }
func Lean_int64_xor(a, b uint64) uint64         { return a ^ b }
func Lean_int64_neg(a uint64) uint64            { return -a }
func Lean_int64_complement(a uint64) uint64     { return ^a }
func Lean_int64_shift_left(a, b uint64) uint64  { return a << (b & 63) }
func Lean_int64_shift_right(a, b uint64) uint64 { return uint64(int64(a) >> (b & 63)) }
func Lean_int64_div(a, b uint64) uint64         { return uint64(fixedDiv(int64(a), int64(b))) }
func Lean_int64_mod(a, b uint64) uint64         { return uint64(fixedMod(int64(a), int64(b))) }
func Lean_int64_dec_eq(a, b uint64) uint8       { return decision(int64(a) == int64(b)) }
func Lean_int64_dec_le(a, b uint64) uint8       { return decision(int64(a) <= int64(b)) }
func Lean_int64_dec_lt(a, b uint64) uint8       { return decision(int64(a) < int64(b)) }
func Lean_int64_of_nat(a V) uint64              { return fixedNatBits(a) }
func Lean_int64_of_int(a V) uint64              { return fixedIntBits(a) }
func Lean_int64_abs(a uint64) uint64            { return uint64(fixedAbs(int64(a))) }
func Lean_int64_to_uint8(a uint64) uint8        { return uint8(a) }
func Lean_int64_to_uint16(a uint64) uint16      { return uint16(a) }
func Lean_int64_to_uint32(a uint64) uint32      { return uint32(a) }
func Lean_int64_to_uint64(a uint64) uint64      { return a }
func Lean_int64_to_usize(a uint64) uint64       { return a }
func Lean_int64_to_int_sint(a uint64) V         { return IntFromInt64(int64(a)) }
func Lean_int64_to_int8(a uint64) uint8         { return uint8(a) }
func Lean_int64_to_int16(a uint64) uint16       { return uint16(a) }
func Lean_int64_to_int32(a uint64) uint32       { return uint32(a) }
func Lean_int64_to_isize(a uint64) uint64       { return a }
func Lean_int64_to_float(a uint64) float64      { return float64(int64(a)) }
func Lean_int64_to_float32(a uint64) float32    { return float32(int64(a)) }

func Lean_isize_add(a, b uint64) uint64         { return a + b }
func Lean_isize_sub(a, b uint64) uint64         { return a - b }
func Lean_isize_mul(a, b uint64) uint64         { return a * b }
func Lean_isize_land(a, b uint64) uint64        { return a & b }
func Lean_isize_lor(a, b uint64) uint64         { return a | b }
func Lean_isize_xor(a, b uint64) uint64         { return a ^ b }
func Lean_isize_neg(a uint64) uint64            { return -a }
func Lean_isize_complement(a uint64) uint64     { return ^a }
func Lean_isize_shift_left(a, b uint64) uint64  { return a << (b & 63) }
func Lean_isize_shift_right(a, b uint64) uint64 { return uint64(int64(a) >> (b & 63)) }
func Lean_isize_div(a, b uint64) uint64         { return uint64(fixedDiv(int64(a), int64(b))) }
func Lean_isize_mod(a, b uint64) uint64         { return uint64(fixedMod(int64(a), int64(b))) }
func Lean_isize_dec_eq(a, b uint64) uint8       { return decision(int64(a) == int64(b)) }
func Lean_isize_dec_le(a, b uint64) uint8       { return decision(int64(a) <= int64(b)) }
func Lean_isize_dec_lt(a, b uint64) uint8       { return decision(int64(a) < int64(b)) }
func Lean_isize_of_nat(a V) uint64              { return fixedNatBits(a) }
func Lean_isize_of_int(a V) uint64              { return fixedIntBits(a) }
func Lean_isize_abs(a uint64) uint64            { return uint64(fixedAbs(int64(a))) }
func Lean_isize_to_uint8(a uint64) uint8        { return uint8(a) }
func Lean_isize_to_uint16(a uint64) uint16      { return uint16(a) }
func Lean_isize_to_uint32(a uint64) uint32      { return uint32(a) }
func Lean_isize_to_uint64(a uint64) uint64      { return a }
func Lean_isize_to_usize(a uint64) uint64       { return a }
func Lean_isize_to_int(a uint64) V              { return IntFromInt64(int64(a)) }
func Lean_isize_to_int8(a uint64) uint8         { return uint8(a) }
func Lean_isize_to_int16(a uint64) uint16       { return uint16(a) }
func Lean_isize_to_int32(a uint64) uint32       { return uint32(a) }
func Lean_isize_to_int64(a uint64) uint64       { return a }
func Lean_isize_to_float(a uint64) float64      { return float64(int64(a)) }
func Lean_isize_to_float32(a uint64) float32    { return float32(int64(a)) }

func Lean_bool_to_uint8(a uint8) uint8   { return a }
func Lean_bool_to_uint16(a uint8) uint16 { return uint16(a) }
func Lean_bool_to_uint32(a uint8) uint32 { return uint32(a) }
func Lean_bool_to_uint64(a uint8) uint64 { return uint64(a) }
func Lean_bool_to_usize(a uint8) uint64  { return uint64(a) }
func Lean_bool_to_int8(a uint8) uint8    { return a }
func Lean_bool_to_int16(a uint8) uint16  { return uint16(a) }
func Lean_bool_to_int32(a uint8) uint32  { return uint32(a) }
func Lean_bool_to_int64(a uint8) uint64  { return uint64(a) }
func Lean_bool_to_isize(a uint8) uint64  { return uint64(a) }

func Lean_uint64_mix_hash(h, k uint64) uint64 {
	const m = 0xc6a4a7935bd1e995
	k *= m
	k ^= k >> 47
	k ^= m
	return (h ^ k) * m
}

func Lean_unsigned_to_nat(n uint32) V  { return NatFromUint64(uint64(n)) }
func Lean_big_usize_to_nat(n uint64) V { return NatFromUint64(n) }
func Lean_int64_to_int(n uint64) V     { return IntFromInt64(int64(n)) }
