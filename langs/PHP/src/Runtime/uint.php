<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function numericLowBits(int|\GMP $value, int $width): int
{
    if (is_int($value)) {
        return $width === 64 ? $value : $value & ((1 << $width) - 1);
    }
    $residue = gmp_mod($value, gmp_init(1) << $width);
    if ($width === 64 && gmp_cmp($residue, PHP_INT_MAX) > 0) {
        $residue = gmp_sub($residue, gmp_init(1) << 64);
    }
    return (int) gmp_strval($residue);
}

function numericSignExtend(int $bits, int $width): int
{
    $shift = 64 - $width;
    return ($bits << $shift) >> $shift;
}

function numericUnsignedCompare(int $a, int $b): int
{
    return ($a ^ PHP_INT_MIN) <=> ($b ^ PHP_INT_MIN);
}

function lean_uint8_add(int $a, int $b): int
{
    return ($a + $b) & 0xff;
}

function lean_uint8_sub(int $a, int $b): int
{
    return ($a - $b) & 0xff;
}

function lean_uint8_mul(int $a, int $b): int
{
    return ($a * $b) & 0xff;
}

function lean_uint8_div(int $a, int $b): int
{
    return $b === 0 ? 0 : intdiv($a, $b);
}

function lean_uint8_mod(int $a, int $b): int
{
    return $b === 0 ? $a : $a % $b;
}

function lean_uint8_shift_right(int $a, int $b): int
{
    return $a >> ($b & 7);
}

function lean_uint8_land(int $a, int $b): int
{
    return $a & $b;
}

function lean_uint8_lor(int $a, int $b): int
{
    return $a | $b;
}

function lean_uint8_xor(int $a, int $b): int
{
    return $a ^ $b;
}

function lean_uint8_dec_eq(int $a, int $b): int
{
    return (int) ($a === $b);
}

function lean_uint8_dec_lt(int $a, int $b): int
{
    return (int) ($a < $b);
}

function lean_uint8_dec_le(int $a, int $b): int
{
    return (int) ($a <= $b);
}

function lean_uint8_shift_left(int $a, int $b): int
{
    return ($a << ($b & 7)) & 0xff;
}

function lean_uint8_complement(int $a): int
{
    return ~$a & 0xff;
}

function lean_uint8_neg(int $a): int
{
    return -$a & 0xff;
}

function lean_uint8_log2(int $a): int
{
    return lean_nat_log2($a);
}

function lean_uint8_of_nat(int|\GMP $a): int
{
    return numericLowBits($a, 8);
}

function lean_uint8_of_nat_mk(int|\GMP $a): int
{
    return lean_uint8_of_nat($a);
}

function lean_uint8_to_nat(int $a): int
{
    return $a;
}

function lean_uint8_to_float(int $a): float
{
    return (float) $a;
}

function lean_uint8_to_float32(int $a): float
{
    return numericFloat32((float) $a);
}

function lean_uint8_to_uint16(int $a): int
{
    return $a;
}

function lean_uint8_to_uint32(int $a): int
{
    return $a;
}

function lean_uint8_to_uint64(int $a): int
{
    return $a;
}

function lean_uint8_to_usize(int $a): int
{
    return $a;
}

function lean_bool_to_uint8(int $a): int
{
    return (int) ($a !== 0);
}

function lean_uint16_add(int $a, int $b): int
{
    return ($a + $b) & 0xffff;
}

function lean_uint16_sub(int $a, int $b): int
{
    return ($a - $b) & 0xffff;
}

function lean_uint16_mul(int $a, int $b): int
{
    return ($a * $b) & 0xffff;
}

function lean_uint16_div(int $a, int $b): int
{
    return $b === 0 ? 0 : intdiv($a, $b);
}

function lean_uint16_mod(int $a, int $b): int
{
    return $b === 0 ? $a : $a % $b;
}

function lean_uint16_shift_right(int $a, int $b): int
{
    return $a >> ($b & 15);
}

function lean_uint16_land(int $a, int $b): int
{
    return $a & $b;
}

function lean_uint16_lor(int $a, int $b): int
{
    return $a | $b;
}

function lean_uint16_xor(int $a, int $b): int
{
    return $a ^ $b;
}

function lean_uint16_dec_eq(int $a, int $b): int
{
    return (int) ($a === $b);
}

function lean_uint16_dec_lt(int $a, int $b): int
{
    return (int) ($a < $b);
}

function lean_uint16_dec_le(int $a, int $b): int
{
    return (int) ($a <= $b);
}

function lean_uint16_shift_left(int $a, int $b): int
{
    return ($a << ($b & 15)) & 0xffff;
}

function lean_uint16_complement(int $a): int
{
    return ~$a & 0xffff;
}

function lean_uint16_neg(int $a): int
{
    return -$a & 0xffff;
}

function lean_uint16_log2(int $a): int
{
    return lean_nat_log2($a);
}

function lean_uint16_of_nat(int|\GMP $a): int
{
    return numericLowBits($a, 16);
}

function lean_uint16_of_nat_mk(int|\GMP $a): int
{
    return lean_uint16_of_nat($a);
}

function lean_uint16_to_nat(int $a): int
{
    return $a;
}

function lean_uint16_to_float(int $a): float
{
    return (float) $a;
}

function lean_uint16_to_float32(int $a): float
{
    return numericFloat32((float) $a);
}

function lean_uint16_to_uint8(int $a): int
{
    return $a & 0xff;
}

function lean_uint16_to_uint32(int $a): int
{
    return $a;
}

function lean_uint16_to_uint64(int $a): int
{
    return $a;
}

function lean_uint16_to_usize(int $a): int
{
    return $a;
}

function lean_bool_to_uint16(int $a): int
{
    return (int) ($a !== 0);
}

function lean_uint32_add(int $a, int $b): int
{
    return ($a + $b) & 0xffffffff;
}

function lean_uint32_sub(int $a, int $b): int
{
    return ($a - $b) & 0xffffffff;
}

function lean_uint32_mul(int $a, int $b): int
{
    return (numericSignExtend($a, 32) * numericSignExtend($b, 32)) & 0xffffffff;
}

function lean_uint32_div(int $a, int $b): int
{
    return $b === 0 ? 0 : intdiv($a, $b);
}

function lean_uint32_mod(int $a, int $b): int
{
    return $b === 0 ? $a : $a % $b;
}

function lean_uint32_shift_right(int $a, int $b): int
{
    return $a >> ($b & 31);
}

function lean_uint32_land(int $a, int $b): int
{
    return $a & $b;
}

function lean_uint32_lor(int $a, int $b): int
{
    return $a | $b;
}

function lean_uint32_xor(int $a, int $b): int
{
    return $a ^ $b;
}

function lean_uint32_dec_eq(int $a, int $b): int
{
    return (int) ($a === $b);
}

function lean_uint32_dec_lt(int $a, int $b): int
{
    return (int) ($a < $b);
}

function lean_uint32_dec_le(int $a, int $b): int
{
    return (int) ($a <= $b);
}

function lean_uint32_shift_left(int $a, int $b): int
{
    return ($a << ($b & 31)) & 0xffffffff;
}

function lean_uint32_complement(int $a): int
{
    return ~$a & 0xffffffff;
}

function lean_uint32_neg(int $a): int
{
    return -$a & 0xffffffff;
}

function lean_uint32_log2(int $a): int
{
    return lean_nat_log2($a);
}

function lean_uint32_of_nat(int|\GMP $a): int
{
    return numericLowBits($a, 32);
}

function lean_uint32_of_nat_mk(int|\GMP $a): int
{
    return lean_uint32_of_nat($a);
}

function lean_uint32_to_nat(int $a): int
{
    return $a;
}

function lean_uint32_to_float(int $a): float
{
    return (float) $a;
}

function lean_uint32_to_float32(int $a): float
{
    return numericFloat32((float) $a);
}

function lean_uint32_to_uint8(int $a): int
{
    return $a & 0xff;
}

function lean_uint32_to_uint16(int $a): int
{
    return $a & 0xffff;
}

function lean_uint32_to_uint64(int $a): int
{
    return $a;
}

function lean_uint32_to_usize(int $a): int
{
    return $a;
}

function lean_bool_to_uint32(int $a): int
{
    return (int) ($a !== 0);
}

function lean_uint64_add(int $a, int $b): int
{
    $low = ($a & 0xffffffff) + ($b & 0xffffffff);
    $high = ($a >> 32) + ($b >> 32) + ($low >> 32);
    return ($high << 32) | ($low & 0xffffffff);
}

function lean_uint64_sub(int $a, int $b): int
{
    $low = ($a & 0xffffffff) - ($b & 0xffffffff);
    $high = ($a >> 32) - ($b >> 32) + ($low >> 32);
    return ($high << 32) | ($low & 0xffffffff);
}

function lean_uint64_mul(int $a, int $b): int
{
    $aLow = $a & 0x3fffff;
    $aMid = ($a >> 22) & 0x3fffff;
    $aHigh = ($a >> 44) & 0xfffff;
    $bLow = $b & 0x3fffff;
    $bMid = ($b >> 22) & 0x3fffff;
    $bHigh = ($b >> 44) & 0xfffff;
    $low = $aLow * $bLow;
    $mid = ($aLow * $bMid) + ($aMid * $bLow) + ($low >> 22);
    $high = ($aLow * $bHigh) + ($aMid * $bMid) + ($aHigh * $bLow) + ($mid >> 22);
    return ($low & 0x3fffff) | (($mid & 0x3fffff) << 22) | ($high << 44);
}

function lean_uint64_div(int $a, int $b): int
{
    if ($b === 0) {
        return 0;
    }
    if ($b < 0) {
        return (int) (numericUnsignedCompare($a, $b) >= 0);
    }
    if ($a >= 0) {
        return intdiv($a, $b);
    }
    $half = ($a >> 1) & PHP_INT_MAX;
    $quotient = intdiv($half, $b);
    $remainder = $half - ($quotient * $b);
    return ($quotient << 1) | (int) ($remainder >= ($b - $remainder - ($a & 1)));
}

function lean_uint64_mod(int $a, int $b): int
{
    if ($b === 0) {
        return $a;
    }
    if ($b < 0) {
        return numericUnsignedCompare($a, $b) >= 0 ? $a - $b : $a;
    }
    if ($a >= 0) {
        return $a % $b;
    }
    $remainder = (($a >> 1) & PHP_INT_MAX) % $b;
    $threshold = $b - $remainder - ($a & 1);
    return $remainder >= $threshold ? $remainder - $threshold : (2 * $remainder) + ($a & 1);
}

function lean_uint64_shift_right(int $a, int $b): int
{
    $shift = $b & 63;
    return $shift === 0 ? $a : ($a >> $shift) & (PHP_INT_MAX >> ($shift - 1));
}

function lean_uint64_land(int $a, int $b): int
{
    return $a & $b;
}

function lean_uint64_lor(int $a, int $b): int
{
    return $a | $b;
}

function lean_uint64_xor(int $a, int $b): int
{
    return $a ^ $b;
}

function lean_uint64_dec_eq(int $a, int $b): int
{
    return (int) ($a === $b);
}

function lean_uint64_dec_lt(int $a, int $b): int
{
    return (int) (numericUnsignedCompare($a, $b) < 0);
}

function lean_uint64_dec_le(int $a, int $b): int
{
    return (int) (numericUnsignedCompare($a, $b) <= 0);
}

function lean_uint64_shift_left(int $a, int $b): int
{
    return $a << ($b & 63);
}

function lean_uint64_complement(int $a): int
{
    return ~$a;
}

function lean_uint64_neg(int $a): int
{
    return lean_uint64_sub(0, $a);
}

function lean_uint64_log2(int $a): int
{
    return strlen(decbin($a)) - 1;
}

function lean_uint64_of_nat(int|\GMP $a): int
{
    return numericLowBits($a, 64);
}

function lean_uint64_of_nat_mk(int|\GMP $a): int
{
    return lean_uint64_of_nat($a);
}

function lean_uint64_to_nat(int $a): int|\GMP
{
    return $a >= 0 ? $a : gmp_init(sprintf('%u', $a), 10);
}

function lean_uint64_to_float(int $a): float
{
    return $a >= 0 ? (float) $a : (float) sprintf('%u', $a);
}

function lean_uint64_to_float32(int $a): float
{
    return numericIntegerFloat32(lean_uint64_to_nat($a));
}

function lean_uint64_to_uint8(int $a): int
{
    return $a & 0xff;
}

function lean_uint64_to_uint16(int $a): int
{
    return $a & 0xffff;
}

function lean_uint64_to_uint32(int $a): int
{
    return $a & 0xffffffff;
}

function lean_uint64_to_usize(int $a): int
{
    return $a;
}

function lean_bool_to_uint64(int $a): int
{
    return (int) ($a !== 0);
}

function lean_usize_add(int $a, int $b): int
{
    return lean_uint64_add($a, $b);
}

function lean_usize_sub(int $a, int $b): int
{
    return lean_uint64_sub($a, $b);
}

function lean_usize_mul(int $a, int $b): int
{
    return lean_uint64_mul($a, $b);
}

function lean_usize_div(int $a, int $b): int
{
    return lean_uint64_div($a, $b);
}

function lean_usize_mod(int $a, int $b): int
{
    return lean_uint64_mod($a, $b);
}

function lean_usize_shift_right(int $a, int $b): int
{
    return lean_uint64_shift_right($a, $b);
}

function lean_usize_land(int $a, int $b): int
{
    return $a & $b;
}

function lean_usize_lor(int $a, int $b): int
{
    return $a | $b;
}

function lean_usize_xor(int $a, int $b): int
{
    return $a ^ $b;
}

function lean_usize_dec_eq(int $a, int $b): int
{
    return (int) ($a === $b);
}

function lean_usize_dec_lt(int $a, int $b): int
{
    return (int) (numericUnsignedCompare($a, $b) < 0);
}

function lean_usize_dec_le(int $a, int $b): int
{
    return (int) (numericUnsignedCompare($a, $b) <= 0);
}

function lean_usize_shift_left(int $a, int $b): int
{
    return $a << ($b & 63);
}

function lean_usize_complement(int $a): int
{
    return ~$a;
}

function lean_usize_neg(int $a): int
{
    return lean_uint64_sub(0, $a);
}

function lean_usize_log2(int $a): int
{
    return strlen(decbin($a)) - 1;
}

function lean_usize_of_nat(int|\GMP $a): int
{
    return numericLowBits($a, 64);
}

function lean_usize_of_nat_mk(int|\GMP $a): int
{
    return lean_usize_of_nat($a);
}

function lean_usize_to_nat(int $a): int|\GMP
{
    return $a >= 0 ? $a : gmp_init(sprintf('%u', $a), 10);
}

function lean_usize_to_float(int $a): float
{
    return $a >= 0 ? (float) $a : (float) sprintf('%u', $a);
}

function lean_usize_to_float32(int $a): float
{
    return numericIntegerFloat32(lean_usize_to_nat($a));
}

function lean_usize_to_uint8(int $a): int
{
    return $a & 0xff;
}

function lean_usize_to_uint16(int $a): int
{
    return $a & 0xffff;
}

function lean_usize_to_uint32(int $a): int
{
    return $a & 0xffffffff;
}

function lean_usize_to_uint64(int $a): int
{
    return $a;
}

function lean_bool_to_usize(int $a): int
{
    return (int) ($a !== 0);
}
