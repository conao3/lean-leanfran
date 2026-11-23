package rt

import (
	"math"
	"math/big"
	"strconv"
)

func Lean_box_float(a float64) V     { return V{n: math.Float64bits(a)} }
func Lean_unbox_float(a V) float64   { return math.Float64frombits(a.n) }
func Lean_box_float32(a float32) V   { return V{n: uint64(math.Float32bits(a))} }
func Lean_unbox_float32(a V) float32 { return math.Float32frombits(uint32(a.n)) }

func Lean_float_add(a, b float64) float64     { return float64(a + b) }
func Lean_float_sub(a, b float64) float64     { return float64(a - b) }
func Lean_float_mul(a, b float64) float64     { return float64(a * b) }
func Lean_float_div(a, b float64) float64     { return float64(a / b) }
func Lean_float_negate(a float64) float64     { return -a }
func Lean_float_beq(a, b float64) uint8       { return decision(a == b) }
func Lean_float_decLt(a, b float64) uint8     { return decision(a < b) }
func Lean_float_decLe(a, b float64) uint8     { return decision(a <= b) }
func Lean_float_isnan(a float64) uint8        { return decision(math.IsNaN(a)) }
func Lean_float_isfinite(a float64) uint8     { return decision(!math.IsNaN(a) && !math.IsInf(a, 0)) }
func Lean_float_isinf(a float64) uint8        { return decision(math.IsInf(a, 0)) }
func Lean_float_of_bits(a uint64) float64     { return math.Float64frombits(a) }
func Lean_float_to_bits(a float64) uint64     { return math.Float64bits(a) }
func Lean_float_to_float32(a float64) float32 { return float32(a) }

func Lean_float32_add(a, b float32) float32   { return float32(a + b) }
func Lean_float32_sub(a, b float32) float32   { return float32(a - b) }
func Lean_float32_mul(a, b float32) float32   { return float32(a * b) }
func Lean_float32_div(a, b float32) float32   { return float32(a / b) }
func Lean_float32_negate(a float32) float32   { return -a }
func Lean_float32_beq(a, b float32) uint8     { return decision(a == b) }
func Lean_float32_decLt(a, b float32) uint8   { return decision(a < b) }
func Lean_float32_decLe(a, b float32) uint8   { return decision(a <= b) }
func Lean_float32_isnan(a float32) uint8      { return Lean_float_isnan(float64(a)) }
func Lean_float32_isfinite(a float32) uint8   { return Lean_float_isfinite(float64(a)) }
func Lean_float32_isinf(a float32) uint8      { return Lean_float_isinf(float64(a)) }
func Lean_float32_of_bits(a uint32) float32   { return math.Float32frombits(a) }
func Lean_float32_to_bits(a float32) uint32   { return math.Float32bits(a) }
func Lean_float32_to_float(a float32) float64 { return float64(a) }

func floatString(a float64) V {
	switch {
	case math.IsNaN(a):
		return Lean_mk_string("NaN")
	case math.IsInf(a, -1):
		return Lean_mk_string("-inf")
	case math.IsInf(a, 1):
		return Lean_mk_string("inf")
	default:
		return Lean_mk_string(strconv.FormatFloat(a, 'f', 6, 64))
	}
}

func Lean_float_to_string(a float64) V   { return floatString(a) }
func Lean_float32_to_string(a float32) V { return floatString(float64(a)) }

func Lean_float_frexp(a float64) V {
	fraction, exponent := math.Frexp(a)
	return ctor(0, Lean_box_float(fraction), IntFromInt64(int64(exponent)))
}

func Lean_float32_frexp(a float32) V {
	fraction, exponent := math.Frexp(float64(a))
	return ctor(0, Lean_box_float32(float32(fraction)), IntFromInt64(int64(exponent)))
}

func Lean_float_scaleb(a float64, exponent V) float64 {
	if exponent.p != nil || int64(exponent.n) < math.MinInt32 || int64(exponent.n) > math.MaxInt32 {
		if a == 0 || Lean_int_dec_nonneg(exponent) == 0 {
			return 0
		}
		return a * math.Inf(1)
	}
	return math.Ldexp(a, int(int64(exponent.n)))
}

func Lean_float32_scaleb(a float32, exponent V) float32 {
	return float32(Lean_float_scaleb(float64(a), exponent))
}

func Lean_float_of_nat(a V) float64 {
	if a.p == nil {
		return float64(a.n)
	}
	value, _ := natBig(a).Float64()
	return value
}

func Lean_float32_of_nat(a V) float32 {
	if a.p == nil {
		return float32(a.n)
	}
	value, _ := new(big.Float).SetInt(natBig(a)).Float32()
	return value
}

func floatToUnsigned(a float64, width int) uint64 {
	if !(a > 0) {
		return 0
	}
	if a >= math.Ldexp(1, width) {
		return math.MaxUint64 >> (64 - width)
	}
	return uint64(a)
}

func floatToSigned(a float64, width int) uint64 {
	if math.IsNaN(a) {
		return 0
	}
	limit := math.Ldexp(1, width-1)
	switch {
	case a <= -limit:
		return uint64(1) << (width - 1)
	case a >= limit:
		return math.MaxUint64 >> (65 - width)
	default:
		return uint64(int64(a))
	}
}

func Lean_float_to_uint8(a float64) uint8   { return uint8(floatToUnsigned(a, 8)) }
func Lean_float_to_uint16(a float64) uint16 { return uint16(floatToUnsigned(a, 16)) }
func Lean_float_to_uint32(a float64) uint32 { return uint32(floatToUnsigned(a, 32)) }
func Lean_float_to_uint64(a float64) uint64 { return floatToUnsigned(a, 64) }
func Lean_float_to_usize(a float64) uint64  { return floatToUnsigned(a, 64) }
func Lean_float_to_int8(a float64) uint8    { return uint8(floatToSigned(a, 8)) }
func Lean_float_to_int16(a float64) uint16  { return uint16(floatToSigned(a, 16)) }
func Lean_float_to_int32(a float64) uint32  { return uint32(floatToSigned(a, 32)) }
func Lean_float_to_int64(a float64) uint64  { return floatToSigned(a, 64) }
func Lean_float_to_isize(a float64) uint64  { return floatToSigned(a, 64) }

func Lean_float32_to_uint8(a float32) uint8   { return uint8(floatToUnsigned(float64(a), 8)) }
func Lean_float32_to_uint16(a float32) uint16 { return uint16(floatToUnsigned(float64(a), 16)) }
func Lean_float32_to_uint32(a float32) uint32 { return uint32(floatToUnsigned(float64(a), 32)) }
func Lean_float32_to_uint64(a float32) uint64 { return floatToUnsigned(float64(a), 64) }
func Lean_float32_to_usize(a float32) uint64  { return floatToUnsigned(float64(a), 64) }
func Lean_float32_to_int8(a float32) uint8    { return uint8(floatToSigned(float64(a), 8)) }
func Lean_float32_to_int16(a float32) uint16  { return uint16(floatToSigned(float64(a), 16)) }
func Lean_float32_to_int32(a float32) uint32  { return uint32(floatToSigned(float64(a), 32)) }
func Lean_float32_to_int64(a float32) uint64  { return floatToSigned(float64(a), 64) }
func Lean_float32_to_isize(a float32) uint64  { return floatToSigned(float64(a), 64) }

func Fabs(a float64) float64      { return math.Abs(a) }
func Fabsf(a float32) float32     { return float32(math.Abs(float64(a))) }
func Acos(a float64) float64      { return math.Acos(a) }
func Acosf(a float32) float32     { return float32(math.Acos(float64(a))) }
func Acosh(a float64) float64     { return math.Acosh(a) }
func Acoshf(a float32) float32    { return float32(math.Acosh(float64(a))) }
func Asin(a float64) float64      { return math.Asin(a) }
func Asinf(a float32) float32     { return float32(math.Asin(float64(a))) }
func Asinh(a float64) float64     { return math.Asinh(a) }
func Asinhf(a float32) float32    { return float32(math.Asinh(float64(a))) }
func Atan(a float64) float64      { return math.Atan(a) }
func Atanf(a float32) float32     { return float32(math.Atan(float64(a))) }
func Atan2(a, b float64) float64  { return math.Atan2(a, b) }
func Atan2f(a, b float32) float32 { return float32(math.Atan2(float64(a), float64(b))) }
func Atanh(a float64) float64     { return math.Atanh(a) }
func Atanhf(a float32) float32    { return float32(math.Atanh(float64(a))) }
func Cbrt(a float64) float64      { return math.Cbrt(a) }
func Cbrtf(a float32) float32     { return float32(math.Cbrt(float64(a))) }
func Ceil(a float64) float64      { return math.Ceil(a) }
func Ceilf(a float32) float32     { return float32(math.Ceil(float64(a))) }
func Cos(a float64) float64       { return math.Cos(a) }
func Cosf(a float32) float32      { return float32(math.Cos(float64(a))) }
func Cosh(a float64) float64      { return math.Cosh(a) }
func Coshf(a float32) float32     { return float32(math.Cosh(float64(a))) }
func Exp(a float64) float64       { return math.Exp(a) }
func Expf(a float32) float32      { return float32(math.Exp(float64(a))) }
func Exp2(a float64) float64      { return math.Exp2(a) }
func Exp2f(a float32) float32     { return float32(math.Exp2(float64(a))) }
func Fma(a, b, c float64) float64 { return math.FMA(a, b, c) }
func Floor(a float64) float64     { return math.Floor(a) }
func Floorf(a float32) float32    { return float32(math.Floor(float64(a))) }
func Log(a float64) float64       { return math.Log(a) }
func Logf(a float32) float32      { return float32(math.Log(float64(a))) }
func Log10(a float64) float64     { return math.Log10(a) }
func Log10f(a float32) float32    { return float32(math.Log10(float64(a))) }
func Log2(a float64) float64      { return math.Log2(a) }
func Log2f(a float32) float32     { return float32(math.Log2(float64(a))) }
func Pow(a, b float64) float64    { return math.Pow(a, b) }
func Powf(a, b float32) float32   { return float32(math.Pow(float64(a), float64(b))) }
func Round(a float64) float64     { return math.Round(a) }
func Roundf(a float32) float32    { return float32(math.Round(float64(a))) }
func Sin(a float64) float64       { return math.Sin(a) }
func Sinf(a float32) float32      { return float32(math.Sin(float64(a))) }
func Sinh(a float64) float64      { return math.Sinh(a) }
func Sinhf(a float32) float32     { return float32(math.Sinh(float64(a))) }
func Sqrt(a float64) float64      { return math.Sqrt(a) }
func Sqrtf(a float32) float32     { return float32(math.Sqrt(float64(a))) }
func Tan(a float64) float64       { return math.Tan(a) }
func Tanf(a float32) float32      { return float32(math.Tan(float64(a))) }
func Tanh(a float64) float64      { return math.Tanh(a) }
func Tanhf(a float32) float32     { return float32(math.Tanh(float64(a))) }
