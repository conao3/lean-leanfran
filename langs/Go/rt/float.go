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

func Lean_float_add(a, b float64) float64 { return float64(a + b) }
func Lean_float_sub(a, b float64) float64 { return float64(a - b) }
func Lean_float_mul(a, b float64) float64 { return float64(a * b) }
func Lean_float_div(a, b float64) float64 { return float64(a / b) }
func Lean_float_negate(a float64) float64 { return -a }
func Lean_float_beq(a, b float64) uint8   { return decision(a == b) }
func Lean_float_decLt(a, b float64) uint8 { return decision(a < b) }
func Lean_float_decLe(a, b float64) uint8 { return decision(a <= b) }
func Lean_float_isnan(a float64) uint8    { return decision(math.IsNaN(a)) }
func Lean_float_isfinite(a float64) uint8 { return decision(!math.IsNaN(a) && !math.IsInf(a, 0)) }
func Lean_float_isinf(a float64) uint8    { return decision(math.IsInf(a, 0)) }
func Lean_float_of_bits(a uint64) float64 {
	f := math.Float64frombits(a)
	if math.IsNaN(f) {
		return math.Float64frombits(0x7ff8000000000000)
	}
	return f
}

func Lean_float_to_bits(a float64) uint64 {
	if math.IsNaN(a) {
		return 0x7ff8000000000000
	}
	return math.Float64bits(a)
}
func Lean_float_to_float32(a float64) float32 { return float32(a) }

func Lean_float32_add(a, b float32) float32 { return float32(a + b) }
func Lean_float32_sub(a, b float32) float32 { return float32(a - b) }
func Lean_float32_mul(a, b float32) float32 { return float32(a * b) }
func Lean_float32_div(a, b float32) float32 { return float32(a / b) }
func Lean_float32_negate(a float32) float32 { return -a }
func Lean_float32_beq(a, b float32) uint8   { return decision(a == b) }
func Lean_float32_decLt(a, b float32) uint8 { return decision(a < b) }
func Lean_float32_decLe(a, b float32) uint8 { return decision(a <= b) }
func Lean_float32_isnan(a float32) uint8    { return Lean_float_isnan(float64(a)) }
func Lean_float32_isfinite(a float32) uint8 { return Lean_float_isfinite(float64(a)) }
func Lean_float32_isinf(a float32) uint8    { return Lean_float_isinf(float64(a)) }
func Lean_float32_of_bits(a uint32) float32 {
	if a&math.MaxInt32 > 0x7f800000 {
		a = 0x7fc00000
	}
	return math.Float32frombits(a)
}

func Lean_float32_to_bits(a float32) uint32 {
	b := math.Float32bits(a)
	if b&math.MaxInt32 > 0x7f800000 {
		return 0x7fc00000
	}
	return b
}
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
	if a == 0 || Lean_float32_isfinite(a) == 0 {
		return ctor(0, Lean_box_float32(a), V{})
	}
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
	if exponent.p == nil && int64(exponent.n) >= math.MinInt32 && int64(exponent.n) <= math.MaxInt32 && Lean_float32_isfinite(a) == 0 {
		return a
	}
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

func Lean_float_of_int(a V) float64 {
	if a.p == nil {
		return float64(int64(a.n))
	}
	value, _ := intBig(a).Float64()
	return value
}

func Lean_float32_of_int(a V) float32 {
	if a.p == nil {
		return float32(int64(a.n))
	}
	value, _ := new(big.Float).SetInt(intBig(a)).Float32()
	return value
}

func scientific(mantissa V, negative uint8, exponent V, width, limit int) float64 {
	if mantissa == (V{}) {
		return 0
	}
	digits := NatString(mantissa)
	if negative != 0 {
		limit += len(digits)
	}
	if exponent.p != nil || exponent.n > uint64(limit) {
		if negative != 0 {
			return 0
		}
		return math.Inf(1)
	}
	power := int(exponent.n)
	if negative != 0 {
		power = -power
	}
	value, _ := strconv.ParseFloat(digits+"e"+strconv.Itoa(power), width)
	return value
}

func Lean_float_of_scientific(mantissa V, negative uint8, exponent V) float64 {
	return scientific(mantissa, negative, exponent, 64, 325)
}

func Lean_float32_of_scientific(mantissa V, negative uint8, exponent V) float32 {
	return float32(scientific(mantissa, negative, exponent, 32, 46))
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

func Fabs(a float64) float64   { return math.Abs(a) }
func Fabsf(a float32) float32  { return math.Float32frombits(math.Float32bits(a) & math.MaxInt32) }
func Acos(a float64) float64   { return math.Acos(a) }
func Acosf(a float32) float32  { return float32(math.Acos(float64(a))) }
func Acosh(a float64) float64  { return math.Acosh(a) }
func Acoshf(a float32) float32 { return float32(math.Acosh(float64(a))) }
func Asin(a float64) float64   { return math.Asin(a) }
func Asinf(a float32) float32  { return float32(math.Asin(float64(a))) }
func Asinh(a float64) float64  { return math.Asinh(a) }
func Asinhf(a float32) float32 { return float32(math.Asinh(float64(a))) }
func Atan(a float64) float64   { return math.Atan(a) }
func Atanf(a float32) float32  { return float32(math.Atan(float64(a))) }
func Atan2(a, b float64) float64 {
	if a != 0 && b < 0 && a/b == 0 {
		return math.Copysign(math.Pi, a)
	}
	return math.Atan2(a, b)
}
func Atan2f(a, b float32) float32 { return float32(Atan2(float64(a), float64(b))) }
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
func Log(a float64) float64 {
	if a > 0 && a < 0x1p-1022 {
		return math.Log(a*0x1p52) - 52*math.Ln2
	}
	return math.Log(a)
}
func Logf(a float32) float32 { return float32(Log(float64(a))) }
func Log10(a float64) float64 {
	if a > 0 && a < 0x1p-1022 {
		return Log(a) / math.Ln10
	}
	return math.Log10(a)
}
func Log10f(a float32) float32 { return float32(Log10(float64(a))) }
func Log2(a float64) float64 {
	if a >= 0.75 && a <= 1.5 {
		return math.Log1p(a-1) / math.Ln2
	}
	return math.Log2(a)
}
func Log2f(a float32) float32 { return float32(Log2(float64(a))) }
func Pow(a, b float64) float64 {
	if a == 0 || a == 1 || a == -1 || b == 0 || b == 1 ||
		Lean_float_isfinite(a) == 0 || !(math.Abs(b) < 0x1p63) {
		return math.Pow(a, b)
	}
	whole, fraction := math.Modf(b)
	if a < 0 && fraction != 0 {
		return math.NaN()
	}
	magnitude := math.Abs(a)
	sign := 1.0
	if a < 0 && uint64(math.Abs(whole))&1 != 0 {
		sign = -1
	}
	power := new(big.Float).SetPrec(128).SetFloat64(1)
	base := new(big.Float).SetPrec(128).SetFloat64(magnitude)
	for exponent := uint64(math.Abs(whole)); exponent != 0; exponent >>= 1 {
		if exponent&1 != 0 {
			power.Mul(power, base)
		}
		if exponent <= 1 {
			break
		}
		base.Mul(base, base)
		if e := base.MantExp(nil); e < -4096 || e > 4096 {
			if (magnitude > 1) == (b > 0) {
				return math.Inf(int(sign))
			}
			return math.Copysign(0, sign)
		}
	}
	if whole < 0 {
		power.Quo(big.NewFloat(1), power)
	}
	if fraction != 0 {
		mantissa, exponent := math.Frexp(magnitude)
		scaled := float64(exponent) * fraction
		shift := math.Round(scaled)
		remainder := math.FMA(float64(exponent), fraction, -shift)
		factor := math.Pow(mantissa, fraction) * math.Exp2(remainder)
		power.Mul(power, new(big.Float).SetMantExp(big.NewFloat(factor), int(shift)))
	}
	result, _ := power.Float64()
	return math.Copysign(result, sign)
}
func Powf(a, b float32) float32 { return float32(math.Pow(float64(a), float64(b))) }
func Round(a float64) float64   { return math.Round(a) }
func Roundf(a float32) float32  { return float32(math.Round(float64(a))) }
func Sin(a float64) float64     { return math.Sin(a) }
func Sinf(a float32) float32    { return float32(math.Sin(float64(a))) }
func Sinh(a float64) float64    { return math.Sinh(a) }
func Sinhf(a float32) float32   { return float32(math.Sinh(float64(a))) }
func Sqrt(a float64) float64    { return math.Sqrt(a) }
func Sqrtf(a float32) float32   { return float32(math.Sqrt(float64(a))) }
func Tan(a float64) float64     { return math.Tan(a) }
func Tanf(a float32) float32    { return float32(math.Tan(float64(a))) }
func Tanh(a float64) float64    { return math.Tanh(a) }
func Tanhf(a float32) float32   { return float32(math.Tanh(float64(a))) }

func Fmod(a, b float64) float64 {
	if a == 0 {
		if b == 0 || math.IsNaN(b) {
			return math.NaN()
		}
		return a
	}
	return math.Mod(a, b)
}

func Fmodf(a, b float32) float32 { return float32(Fmod(float64(a), float64(b))) }

func Fmaf(a, b, c float32) float32 {
	if Lean_float32_isfinite(a) == 0 || Lean_float32_isfinite(b) == 0 || Lean_float32_isfinite(c) == 0 {
		return float32(math.FMA(float64(a), float64(b), float64(c)))
	}
	if a == 0 || b == 0 {
		return float32(a*b) + c
	}
	product := new(big.Float).SetPrec(600).Mul(big.NewFloat(float64(a)), big.NewFloat(float64(b)))
	sum, _ := product.Add(product, big.NewFloat(float64(c))).Float32()
	return sum
}
