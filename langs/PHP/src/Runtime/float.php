<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function numericUnpackFloat(string $format, string $bytes): float
{
    $result = unpack($format, $bytes)[1] ?? null;
    if (!is_float($result)) {
        throw new \LogicException('Expected packed floating-point bytes.');
    }
    return $result;
}

function numericUnpackBits(string $format, string $bytes): int
{
    $result = unpack($format, $bytes)[1] ?? null;
    if (!is_int($result)) {
        throw new \LogicException('Expected packed integer bits.');
    }
    return $result;
}

function lean_float_of_bits(int $bits): float
{
    $value = numericUnpackFloat('e', pack('P', $bits));
    return is_nan($value) ? NAN : $value;
}

function lean_float_to_bits(float $a): int
{
    return is_nan($a) ? 0x7ff8000000000000 : numericUnpackBits('P', pack('e', $a));
}

function lean_float32_of_bits(int $bits): float
{
    $value = numericUnpackFloat('g', pack('V', $bits));
    return is_nan($value) ? NAN : $value;
}

function lean_float32_to_bits(float $a): int
{
    return is_nan($a) ? 0x7fc00000 : numericUnpackBits('V', pack('g', $a));
}

function numericFloat32(float $a): float
{
    return numericUnpackFloat('g', pack('g', $a));
}

function lean_float_to_float32(float $a): float
{
    return numericFloat32($a);
}

function lean_float32_to_float(float $a): float
{
    return $a;
}

function numericPowerOfTwo(int $exponent): float
{
    if ($exponent < -1022) {
        return lean_float_of_bits(1 << ($exponent + 1074));
    }
    return lean_float_of_bits(($exponent + 1023) << 52);
}

/** @return array{int, int} Significand magnitude and binary exponent. */
function numericFloatParts(float $a): array
{
    $bits = lean_float_to_bits($a);
    $exponent = ($bits >> 52) & 0x7ff;
    $mantissa = $bits & 0xfffffffffffff;
    return $exponent === 0 ? [$mantissa, -1074] : [$mantissa | (1 << 52), $exponent - 1075];
}

function numericRoundRatio(\GMP $numerator, \GMP $denominator, int $shift): \GMP
{
    if ($shift >= 0) {
        $numerator <<= $shift;
    } else {
        $denominator <<= -$shift;
    }
    $quotient = gmp_div_q($numerator, $denominator);
    $remainder = gmp_div_r($numerator, $denominator);
    $comparison = gmp_cmp($remainder << 1, $denominator);
    if ($comparison > 0 || $comparison === 0 && gmp_testbit($quotient, 0)) {
        return gmp_add($quotient, 1);
    }
    return $quotient;
}

function numericRoundedFloat(\GMP $numerator, \GMP $denominator, int $exponent, bool $single): float
{
    $sign = gmp_sign($numerator);
    if ($sign === 0) {
        return 0.0;
    }
    $magnitude = gmp_abs($numerator);
    $order = lean_nat_log2($magnitude) - lean_nat_log2($denominator);
    $belowPower = $order >= 0
        ? gmp_cmp($magnitude, $denominator << $order) < 0
        : gmp_cmp($magnitude << -$order, $denominator) < 0;
    $order += $exponent - (int) $belowPower;
    $maxOrder = $single ? 127 : 1023;
    $minStep = $single ? -149 : -1074;
    if ($order > $maxOrder) {
        return $sign < 0 ? -INF : INF;
    }
    if ($order < ($minStep - 1)) {
        return $sign < 0 ? -0.0 : 0.0;
    }
    $step = max($minStep, $order - ($single ? 23 : 52));
    $rounded = numericRoundRatio($magnitude, $denominator, $exponent - $step);
    $result = (float) gmp_intval($rounded) * numericPowerOfTwo($step);
    if ($single) {
        $result = numericFloat32($result);
    }
    return $sign < 0 ? -$result : $result;
}

function numericIntegerFloat32(int|\GMP $a): float
{
    if (is_int($a) && $a >= -16777216 && $a <= 16777216) {
        return (float) $a;
    }
    return numericRoundedFloat(is_int($a) ? gmp_init($a) : $a, gmp_init(1), 0, true);
}

function lean_float_of_nat(int|\GMP $a): float
{
    return (float) (is_int($a) ? $a : gmp_strval($a));
}

function lean_float_of_int(int|\GMP $a): float
{
    return lean_float_of_nat($a);
}

function lean_float32_of_nat(int|\GMP $a): float
{
    return numericIntegerFloat32($a);
}

function lean_float32_of_int(int|\GMP $a): float
{
    return numericIntegerFloat32($a);
}

function numericScientific(int|\GMP $a, int $negativeExponent, int|\GMP $exponent, bool $single): float
{
    if ($a === 0 || $exponent === 0) {
        return $single ? numericIntegerFloat32($a) : lean_float_of_nat($a);
    }
    $digits = is_int($a) ? (string) $a : gmp_strval($a);
    $limit = $single ? 50 : 325;
    if ($negativeExponent === 0 && numericCompare($exponent, $limit) > 0) {
        return INF;
    }
    if ($negativeExponent !== 0 && numericCompare($exponent, strlen($digits) + $limit) > 0) {
        return 0.0;
    }
    $exponent = (int) (is_int($exponent) ? $exponent : gmp_strval($exponent));
    if (!$single) {
        return (float) ($digits . 'e' . ($negativeExponent === 0 ? $exponent : -$exponent));
    }
    $mantissa = is_int($a) ? gmp_init($a) : $a;
    $power = gmp_pow(10, $exponent);
    return $negativeExponent === 0
        ? numericRoundedFloat(gmp_mul($mantissa, $power), gmp_init(1), 0, true)
        : numericRoundedFloat($mantissa, $power, 0, true);
}

function lean_float_of_scientific(int|\GMP $a, int $negativeExponent, int|\GMP $exponent): float
{
    return numericScientific($a, $negativeExponent, $exponent, false);
}

function lean_float32_of_scientific(int|\GMP $a, int $negativeExponent, int|\GMP $exponent): float
{
    return numericScientific($a, $negativeExponent, $exponent, true);
}

function numericFloatToUnsigned(float $a, int $width): int
{
    if (!($a > 0.0)) {
        return 0;
    }
    if ($a >= numericPowerOfTwo($width)) {
        return $width === 64 ? -1 : (1 << $width) - 1;
    }
    if ($width === 64 && $a >= 9223372036854775808.0) {
        return (int) ($a - 9223372036854775808.0) | PHP_INT_MIN;
    }
    return (int) $a;
}

function numericFloatToSigned(float $a, int $width): int
{
    if (is_nan($a)) {
        return 0;
    }
    $limit = numericPowerOfTwo($width - 1);
    if ($a <= -$limit) {
        return 1 << ($width - 1);
    }
    if ($a >= $limit) {
        return $width === 64 ? PHP_INT_MAX : (1 << ($width - 1)) - 1;
    }
    return numericLowBits((int) $a, $width);
}

function lean_float_to_string(float $a): LString
{
    if (is_nan($a)) {
        return new LString('NaN');
    }
    $sign = lean_float_to_bits($a) < 0 ? '-' : '';
    if (is_infinite($a)) {
        return new LString($sign . 'inf');
    }
    [$mantissa, $exponent] = numericFloatParts($a);
    $decimal = numericRoundRatio(gmp_mul($mantissa, 1000000), gmp_init(1), $exponent);
    $digits = str_pad(gmp_strval($decimal), 7, '0', STR_PAD_LEFT);
    return new LString($sign . substr($digits, 0, -6) . '.' . substr($digits, -6));
}

function lean_float32_to_string(float $a): LString
{
    return lean_float_to_string($a);
}

function lean_float_frexp(float $a): Ctor
{
    if (!is_finite($a) || $a === 0.0) {
        return new Ctor(0, [$a, 0]);
    }
    [$mantissa, $exponent] = numericFloatParts($a);
    $width = lean_nat_log2($mantissa) + 1;
    $fraction = (float) $mantissa * numericPowerOfTwo(-$width);
    return new Ctor(0, [$a < 0 ? -$fraction : $fraction, $exponent + $width]);
}

function lean_float32_frexp(float $a): Ctor
{
    return lean_float_frexp($a);
}

function numericFloatScale(float $a, int|\GMP $b, bool $single): float
{
    if (!is_int($b) || $b < -2147483648 || $b > 2147483647) {
        return $a === 0.0 || numericCompare($b, 0) < 0 ? 0.0 : $a * INF;
    }
    if (!is_finite($a) || $a === 0.0 || $b === 0) {
        return $a;
    }
    [$mantissa, $exponent] = numericFloatParts($a);
    return numericRoundedFloat(gmp_init($a < 0 ? -$mantissa : $mantissa), gmp_init(1), $exponent + $b, $single);
}

function lean_float_scaleb(float $a, int|\GMP $b): float
{
    return numericFloatScale($a, $b, false);
}

function lean_float32_scaleb(float $a, int|\GMP $b): float
{
    return numericFloatScale($a, $b, true);
}

function numericFma(float $a, float $b, float $c, bool $single): float
{
    if (!is_finite($a) || !is_finite($b)) {
        return ($a * $b) + $c;
    }
    if (!is_finite($c)) {
        return $c;
    }
    if ($a === 0.0 || $b === 0.0) {
        return ($a * $b) + $c;
    }
    [$ma, $ea] = numericFloatParts($a);
    [$mb, $eb] = numericFloatParts($b);
    [$mc, $ec] = numericFloatParts($c);
    $product = gmp_mul($ma, $mb);
    if ($a < 0 !== $b < 0) {
        $product = gmp_neg($product);
    }
    $productExponent = $ea + $eb;
    $exponent = min($productExponent, $ec);
    $addend = gmp_init($c < 0 ? -$mc : $mc) << ($ec - $exponent);
    $sum = gmp_add($product << ($productExponent - $exponent), $addend);
    return numericRoundedFloat($sum, gmp_init(1), $exponent, $single);
}

function fma(float $a, float $b, float $c): float
{
    return numericFma($a, $b, $c, false);
}

function fmaf(float $a, float $b, float $c): float
{
    return numericFma($a, $b, $c, true);
}

function round(float $a): float
{
    if (!is_finite($a) || $a === 0.0 || \abs($a) >= 4503599627370496.0) {
        return $a;
    }
    $magnitude = \abs($a);
    $whole = \floor($magnitude);
    $rounded = $whole + (float) (($magnitude - $whole) >= 0.5);
    return $a < 0 ? -$rounded : $rounded;
}

function fabs(float $a): float
{
    return \abs($a);
}

function pow(float $a, float $b): float
{
    if ($a === 0.0 && $b < 0.0) {
        return lean_float_to_bits($a) < 0 && is_finite($b) && fmod($b, 2.0) === -1.0 ? -INF : INF;
    }
    return \pow($a, $b);
}

function exp2(float $a): float
{
    return \pow(2.0, $a);
}

function numericFixedLog(\GMP $numerator, \GMP $denominator): \GMP
{
    $term = gmp_div_q($numerator << 128, $denominator);
    $square = gmp_mul($term, $term) >> 128;
    $sum = $term;
    for ($odd = 3; gmp_sign($term) !== 0; $odd += 2) {
        $term = gmp_mul($term, $square) >> 128;
        $sum = gmp_add($sum, gmp_div_q($term, $odd));
    }
    return $sum;
}

function log2(float $a): float
{
    if ($a <= 0.0 || !is_finite($a)) {
        return \log($a);
    }
    [$mantissa, $exponent] = numericFloatParts($a);
    $order = lean_nat_log2($mantissa);
    $leadingBit = 1 << $order;
    if ($mantissa === $leadingBit) {
        return (float) ($exponent + $order);
    }
    static $logTwo = null;
    if (!$logTwo instanceof \GMP) {
        $logTwo = numericFixedLog(gmp_init(1), gmp_init(3));
    }
    $fraction = numericFixedLog(gmp_init($mantissa - $leadingBit), gmp_init($mantissa + $leadingBit));
    $fixed = gmp_add(gmp_init($exponent + $order) << 128, gmp_div_q($fraction << 128, $logTwo));
    return numericRoundedFloat($fixed, gmp_init(1), -128, false);
}

/** Evaluate the reference libm polynomial and Halley step on a normalized significand. */
function cbrt(float $a): float
{
    if ($a === 0.0 || !is_finite($a)) {
        return $a;
    }
    [$mantissa, $exponent] = numericFloatParts($a);
    $width = lean_nat_log2($mantissa) + 1;
    $exponent += $width;
    $fraction = (float) $mantissa * numericPowerOfTwo(-$width);
    $estimate = 0.0;
    foreach ([
        -0.145263899385486377,
        0.784932344976639262,
        -1.83469277483613086,
        2.44693122563534430,
        -2.11499494167371287,
        1.50819193781584896,
        0.354895765043919860,
    ] as $coefficient) {
        $estimate = ($estimate * $fraction) + $coefficient;
    }
    $cube = $estimate * $estimate * $estimate;
    $root = ($estimate * ($cube + (2.0 * $fraction))) / ((2.0 * $cube) + $fraction);
    $scale = match ($exponent % 3) {
        -2 => 1.0 / 1.5874010519681994748,
        -1 => 1.0 / 1.2599210498948731648,
        1 => 1.2599210498948731648,
        2 => 1.5874010519681994748,
        default => 1.0,
    };
    $result = $root * $scale * numericPowerOfTwo(intdiv($exponent, 3));
    return $a < 0 ? -$result : $result;
}

function lean_float_add(float $a, float $b): float
{
    return $a + $b;
}

function lean_float_sub(float $a, float $b): float
{
    return $a - $b;
}

function lean_float_mul(float $a, float $b): float
{
    return $a * $b;
}

function lean_float_div(float $a, float $b): float
{
    return fdiv($a, $b);
}

function lean_float_negate(float $a): float
{
    return -$a;
}

function lean_float_beq(float $a, float $b): int
{
    return (int) ($a === $b);
}

function lean_float_decLt(float $a, float $b): int
{
    return (int) ($a < $b);
}

function lean_float_decLe(float $a, float $b): int
{
    return (int) ($a <= $b);
}

function lean_float_isnan(float $a): int
{
    return (int) is_nan($a);
}

function lean_float_isfinite(float $a): int
{
    return (int) is_finite($a);
}

function lean_float_isinf(float $a): int
{
    return (int) is_infinite($a);
}

function lean_float_to_int8(float $a): int
{
    return numericFloatToSigned($a, 8);
}

function lean_float_to_int16(float $a): int
{
    return numericFloatToSigned($a, 16);
}

function lean_float_to_int32(float $a): int
{
    return numericFloatToSigned($a, 32);
}

function lean_float_to_int64(float $a): int
{
    return numericFloatToSigned($a, 64);
}

function lean_float_to_isize(float $a): int
{
    return numericFloatToSigned($a, 64);
}

function lean_float_to_uint8(float $a): int
{
    return numericFloatToUnsigned($a, 8);
}

function lean_float_to_uint16(float $a): int
{
    return numericFloatToUnsigned($a, 16);
}

function lean_float_to_uint32(float $a): int
{
    return numericFloatToUnsigned($a, 32);
}

function lean_float_to_uint64(float $a): int
{
    return numericFloatToUnsigned($a, 64);
}

function lean_float_to_usize(float $a): int
{
    return numericFloatToUnsigned($a, 64);
}

function lean_float32_add(float $a, float $b): float
{
    return numericFloat32($a + $b);
}

function lean_float32_sub(float $a, float $b): float
{
    return numericFloat32($a - $b);
}

function lean_float32_mul(float $a, float $b): float
{
    return numericFloat32($a * $b);
}

function lean_float32_div(float $a, float $b): float
{
    return numericFloat32(fdiv($a, $b));
}

function lean_float32_negate(float $a): float
{
    return -$a;
}

function lean_float32_beq(float $a, float $b): int
{
    return (int) ($a === $b);
}

function lean_float32_decLt(float $a, float $b): int
{
    return (int) ($a < $b);
}

function lean_float32_decLe(float $a, float $b): int
{
    return (int) ($a <= $b);
}

function lean_float32_isnan(float $a): int
{
    return (int) is_nan($a);
}

function lean_float32_isfinite(float $a): int
{
    return (int) is_finite($a);
}

function lean_float32_isinf(float $a): int
{
    return (int) is_infinite($a);
}

function lean_float32_to_int8(float $a): int
{
    return numericFloatToSigned($a, 8);
}

function lean_float32_to_int16(float $a): int
{
    return numericFloatToSigned($a, 16);
}

function lean_float32_to_int32(float $a): int
{
    return numericFloatToSigned($a, 32);
}

function lean_float32_to_int64(float $a): int
{
    return numericFloatToSigned($a, 64);
}

function lean_float32_to_isize(float $a): int
{
    return numericFloatToSigned($a, 64);
}

function lean_float32_to_uint8(float $a): int
{
    return numericFloatToUnsigned($a, 8);
}

function lean_float32_to_uint16(float $a): int
{
    return numericFloatToUnsigned($a, 16);
}

function lean_float32_to_uint32(float $a): int
{
    return numericFloatToUnsigned($a, 32);
}

function lean_float32_to_uint64(float $a): int
{
    return numericFloatToUnsigned($a, 64);
}

function lean_float32_to_usize(float $a): int
{
    return numericFloatToUnsigned($a, 64);
}

function acos(float $a): float
{
    return \acos($a);
}

function acosf(float $a): float
{
    return numericFloat32(\acos($a));
}

function acosh(float $a): float
{
    return \acosh($a);
}

function acoshf(float $a): float
{
    return numericFloat32(\acosh($a));
}

function asin(float $a): float
{
    return \asin($a);
}

function asinf(float $a): float
{
    return numericFloat32(\asin($a));
}

function asinh(float $a): float
{
    return \asinh($a);
}

function asinhf(float $a): float
{
    return numericFloat32(\asinh($a));
}

function atan(float $a): float
{
    return \atan($a);
}

function atanf(float $a): float
{
    return numericFloat32(\atan($a));
}

function atan2(float $a, float $b): float
{
    return \atan2($a, $b);
}

function atan2f(float $a, float $b): float
{
    return numericFloat32(\atan2($a, $b));
}

function atanh(float $a): float
{
    return \atanh($a);
}

function atanhf(float $a): float
{
    return numericFloat32(\atanh($a));
}

function cbrtf(float $a): float
{
    return numericFloat32(cbrt($a));
}

function ceil(float $a): float
{
    return \ceil($a);
}

function ceilf(float $a): float
{
    return numericFloat32(\ceil($a));
}

function cos(float $a): float
{
    return \cos($a);
}

function cosf(float $a): float
{
    return numericFloat32(\cos($a));
}

function cosh(float $a): float
{
    return \cosh($a);
}

function coshf(float $a): float
{
    return numericFloat32(\cosh($a));
}

function exp(float $a): float
{
    return \exp($a);
}

function expf(float $a): float
{
    return numericFloat32(\exp($a));
}

function exp2f(float $a): float
{
    return numericFloat32(exp2($a));
}

function fabsf(float $a): float
{
    return numericFloat32(fabs($a));
}

function floor(float $a): float
{
    return \floor($a);
}

function floorf(float $a): float
{
    return numericFloat32(\floor($a));
}

function log(float $a): float
{
    return \log($a);
}

function logf(float $a): float
{
    return numericFloat32(\log($a));
}

function log10(float $a): float
{
    return \log10($a);
}

function log10f(float $a): float
{
    return numericFloat32(\log10($a));
}

function log2f(float $a): float
{
    return numericFloat32(log2($a));
}

function powf(float $a, float $b): float
{
    return numericFloat32(pow($a, $b));
}

function roundf(float $a): float
{
    return numericFloat32(round($a));
}

function sin(float $a): float
{
    return \sin($a);
}

function sinf(float $a): float
{
    return numericFloat32(\sin($a));
}

function sinh(float $a): float
{
    return \sinh($a);
}

function sinhf(float $a): float
{
    return numericFloat32(\sinh($a));
}

function sqrt(float $a): float
{
    return \sqrt($a);
}

function sqrtf(float $a): float
{
    return numericFloat32(\sqrt($a));
}

function tan(float $a): float
{
    return \tan($a);
}

function tanf(float $a): float
{
    return numericFloat32(\tan($a));
}

function tanh(float $a): float
{
    return \tanh($a);
}

function tanhf(float $a): float
{
    return numericFloat32(\tanh($a));
}
