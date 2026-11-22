<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_int8_add(int $a, int $b): int
{
    return lean_uint8_add($a, $b);
}

function lean_int8_sub(int $a, int $b): int
{
    return lean_uint8_sub($a, $b);
}

function lean_int8_mul(int $a, int $b): int
{
    return lean_uint8_mul($a, $b);
}

function lean_int8_land(int $a, int $b): int
{
    return lean_uint8_land($a, $b);
}

function lean_int8_lor(int $a, int $b): int
{
    return lean_uint8_lor($a, $b);
}

function lean_int8_xor(int $a, int $b): int
{
    return lean_uint8_xor($a, $b);
}

function lean_int8_dec_eq(int $a, int $b): int
{
    return lean_uint8_dec_eq($a, $b);
}

function lean_int8_shift_left(int $a, int $b): int
{
    return lean_uint8_shift_left($a, $b);
}

function lean_int8_dec_lt(int $a, int $b): int
{
    return (int) (numericSignExtend($a, 8) < numericSignExtend($b, 8));
}

function lean_int8_dec_le(int $a, int $b): int
{
    return (int) (numericSignExtend($a, 8) <= numericSignExtend($b, 8));
}

function lean_int8_div(int $a, int $b): int
{
    return $b === 0 ? 0 : intdiv(numericSignExtend($a, 8), numericSignExtend($b, 8)) & 0xff;
}

function lean_int8_mod(int $a, int $b): int
{
    return $b === 0 ? $a : (numericSignExtend($a, 8) % numericSignExtend($b, 8)) & 0xff;
}

function lean_int8_shift_right(int $a, int $b): int
{
    return (numericSignExtend($a, 8) >> ($b & 7)) & 0xff;
}

function lean_int8_complement(int $a): int
{
    return lean_uint8_complement($a);
}

function lean_int8_neg(int $a): int
{
    return lean_uint8_neg($a);
}

function lean_int8_abs(int $a): int
{
    return numericSignExtend($a, 8) < 0 ? lean_int8_neg($a) : $a;
}

function lean_int8_of_nat(int|\GMP $a): int
{
    return lean_uint8_of_nat($a);
}

function lean_int8_of_int(int|\GMP $a): int
{
    return numericLowBits($a, 8);
}

function lean_int8_to_int(int $a): int
{
    return numericSignExtend($a, 8);
}

function lean_int8_to_float(int $a): float
{
    return (float) lean_int8_to_int($a);
}

function lean_int8_to_float32(int $a): float
{
    return numericFloat32(lean_int8_to_float($a));
}

function lean_int8_to_int16(int $a): int
{
    return numericSignExtend($a, 8) & 0xffff;
}

function lean_int8_to_int32(int $a): int
{
    return numericSignExtend($a, 8) & 0xffffffff;
}

function lean_int8_to_int64(int $a): int
{
    return numericSignExtend($a, 8);
}

function lean_int8_to_isize(int $a): int
{
    return numericSignExtend($a, 8);
}

function lean_bool_to_int8(int $a): int
{
    return (int) ($a !== 0);
}

function lean_int16_add(int $a, int $b): int
{
    return lean_uint16_add($a, $b);
}

function lean_int16_sub(int $a, int $b): int
{
    return lean_uint16_sub($a, $b);
}

function lean_int16_mul(int $a, int $b): int
{
    return lean_uint16_mul($a, $b);
}

function lean_int16_land(int $a, int $b): int
{
    return lean_uint16_land($a, $b);
}

function lean_int16_lor(int $a, int $b): int
{
    return lean_uint16_lor($a, $b);
}

function lean_int16_xor(int $a, int $b): int
{
    return lean_uint16_xor($a, $b);
}

function lean_int16_dec_eq(int $a, int $b): int
{
    return lean_uint16_dec_eq($a, $b);
}

function lean_int16_shift_left(int $a, int $b): int
{
    return lean_uint16_shift_left($a, $b);
}

function lean_int16_dec_lt(int $a, int $b): int
{
    return (int) (numericSignExtend($a, 16) < numericSignExtend($b, 16));
}

function lean_int16_dec_le(int $a, int $b): int
{
    return (int) (numericSignExtend($a, 16) <= numericSignExtend($b, 16));
}

function lean_int16_div(int $a, int $b): int
{
    return $b === 0 ? 0 : intdiv(numericSignExtend($a, 16), numericSignExtend($b, 16)) & 0xffff;
}

function lean_int16_mod(int $a, int $b): int
{
    return $b === 0 ? $a : (numericSignExtend($a, 16) % numericSignExtend($b, 16)) & 0xffff;
}

function lean_int16_shift_right(int $a, int $b): int
{
    return (numericSignExtend($a, 16) >> ($b & 15)) & 0xffff;
}

function lean_int16_complement(int $a): int
{
    return lean_uint16_complement($a);
}

function lean_int16_neg(int $a): int
{
    return lean_uint16_neg($a);
}

function lean_int16_abs(int $a): int
{
    return numericSignExtend($a, 16) < 0 ? lean_int16_neg($a) : $a;
}

function lean_int16_of_nat(int|\GMP $a): int
{
    return lean_uint16_of_nat($a);
}

function lean_int16_of_int(int|\GMP $a): int
{
    return numericLowBits($a, 16);
}

function lean_int16_to_int(int $a): int
{
    return numericSignExtend($a, 16);
}

function lean_int16_to_float(int $a): float
{
    return (float) lean_int16_to_int($a);
}

function lean_int16_to_float32(int $a): float
{
    return numericFloat32(lean_int16_to_float($a));
}

function lean_int16_to_int8(int $a): int
{
    return $a & 0xff;
}

function lean_int16_to_int32(int $a): int
{
    return numericSignExtend($a, 16) & 0xffffffff;
}

function lean_int16_to_int64(int $a): int
{
    return numericSignExtend($a, 16);
}

function lean_int16_to_isize(int $a): int
{
    return numericSignExtend($a, 16);
}

function lean_bool_to_int16(int $a): int
{
    return (int) ($a !== 0);
}

function lean_int32_add(int $a, int $b): int
{
    return lean_uint32_add($a, $b);
}

function lean_int32_sub(int $a, int $b): int
{
    return lean_uint32_sub($a, $b);
}

function lean_int32_mul(int $a, int $b): int
{
    return lean_uint32_mul($a, $b);
}

function lean_int32_land(int $a, int $b): int
{
    return lean_uint32_land($a, $b);
}

function lean_int32_lor(int $a, int $b): int
{
    return lean_uint32_lor($a, $b);
}

function lean_int32_xor(int $a, int $b): int
{
    return lean_uint32_xor($a, $b);
}

function lean_int32_dec_eq(int $a, int $b): int
{
    return lean_uint32_dec_eq($a, $b);
}

function lean_int32_shift_left(int $a, int $b): int
{
    return lean_uint32_shift_left($a, $b);
}

function lean_int32_dec_lt(int $a, int $b): int
{
    return (int) (numericSignExtend($a, 32) < numericSignExtend($b, 32));
}

function lean_int32_dec_le(int $a, int $b): int
{
    return (int) (numericSignExtend($a, 32) <= numericSignExtend($b, 32));
}

function lean_int32_div(int $a, int $b): int
{
    return $b === 0 ? 0 : intdiv(numericSignExtend($a, 32), numericSignExtend($b, 32)) & 0xffffffff;
}

function lean_int32_mod(int $a, int $b): int
{
    return $b === 0 ? $a : (numericSignExtend($a, 32) % numericSignExtend($b, 32)) & 0xffffffff;
}

function lean_int32_shift_right(int $a, int $b): int
{
    return (numericSignExtend($a, 32) >> ($b & 31)) & 0xffffffff;
}

function lean_int32_complement(int $a): int
{
    return lean_uint32_complement($a);
}

function lean_int32_neg(int $a): int
{
    return lean_uint32_neg($a);
}

function lean_int32_abs(int $a): int
{
    return numericSignExtend($a, 32) < 0 ? lean_int32_neg($a) : $a;
}

function lean_int32_of_nat(int|\GMP $a): int
{
    return lean_uint32_of_nat($a);
}

function lean_int32_of_int(int|\GMP $a): int
{
    return numericLowBits($a, 32);
}

function lean_int32_to_int(int $a): int
{
    return numericSignExtend($a, 32);
}

function lean_int32_to_float(int $a): float
{
    return (float) lean_int32_to_int($a);
}

function lean_int32_to_float32(int $a): float
{
    return numericFloat32(lean_int32_to_float($a));
}

function lean_int32_to_int8(int $a): int
{
    return $a & 0xff;
}

function lean_int32_to_int16(int $a): int
{
    return $a & 0xffff;
}

function lean_int32_to_int64(int $a): int
{
    return numericSignExtend($a, 32);
}

function lean_int32_to_isize(int $a): int
{
    return numericSignExtend($a, 32);
}

function lean_bool_to_int32(int $a): int
{
    return (int) ($a !== 0);
}

function lean_int64_add(int $a, int $b): int
{
    return lean_uint64_add($a, $b);
}

function lean_int64_sub(int $a, int $b): int
{
    return lean_uint64_sub($a, $b);
}

function lean_int64_mul(int $a, int $b): int
{
    return lean_uint64_mul($a, $b);
}

function lean_int64_land(int $a, int $b): int
{
    return lean_uint64_land($a, $b);
}

function lean_int64_lor(int $a, int $b): int
{
    return lean_uint64_lor($a, $b);
}

function lean_int64_xor(int $a, int $b): int
{
    return lean_uint64_xor($a, $b);
}

function lean_int64_dec_eq(int $a, int $b): int
{
    return lean_uint64_dec_eq($a, $b);
}

function lean_int64_shift_left(int $a, int $b): int
{
    return lean_uint64_shift_left($a, $b);
}

function lean_int64_dec_lt(int $a, int $b): int
{
    return (int) ($a < $b);
}

function lean_int64_dec_le(int $a, int $b): int
{
    return (int) ($a <= $b);
}

function lean_int64_div(int $a, int $b): int
{
    return $b === 0 ? 0 : ($a === PHP_INT_MIN && $b === -1 ? $a : intdiv($a, $b));
}

function lean_int64_mod(int $a, int $b): int
{
    return $b === 0 ? $a : $a % $b;
}

function lean_int64_shift_right(int $a, int $b): int
{
    return $a >> ($b & 63);
}

function lean_int64_complement(int $a): int
{
    return lean_uint64_complement($a);
}

function lean_int64_neg(int $a): int
{
    return lean_uint64_neg($a);
}

function lean_int64_abs(int $a): int
{
    return $a < 0 ? lean_int64_neg($a) : $a;
}

function lean_int64_of_nat(int|\GMP $a): int
{
    return lean_uint64_of_nat($a);
}

function lean_int64_of_int(int|\GMP $a): int
{
    return numericLowBits($a, 64);
}

function lean_int64_to_int_sint(int $a): int
{
    return $a;
}

function lean_int64_to_float(int $a): float
{
    return (float) lean_int64_to_int_sint($a);
}

function lean_int64_to_float32(int $a): float
{
    return numericIntegerFloat32($a);
}

function lean_int64_to_int8(int $a): int
{
    return $a & 0xff;
}

function lean_int64_to_int16(int $a): int
{
    return $a & 0xffff;
}

function lean_int64_to_int32(int $a): int
{
    return $a & 0xffffffff;
}

function lean_int64_to_isize(int $a): int
{
    return $a;
}

function lean_bool_to_int64(int $a): int
{
    return (int) ($a !== 0);
}

function lean_isize_add(int $a, int $b): int
{
    return lean_usize_add($a, $b);
}

function lean_isize_sub(int $a, int $b): int
{
    return lean_usize_sub($a, $b);
}

function lean_isize_mul(int $a, int $b): int
{
    return lean_usize_mul($a, $b);
}

function lean_isize_land(int $a, int $b): int
{
    return lean_usize_land($a, $b);
}

function lean_isize_lor(int $a, int $b): int
{
    return lean_usize_lor($a, $b);
}

function lean_isize_xor(int $a, int $b): int
{
    return lean_usize_xor($a, $b);
}

function lean_isize_dec_eq(int $a, int $b): int
{
    return lean_usize_dec_eq($a, $b);
}

function lean_isize_shift_left(int $a, int $b): int
{
    return lean_usize_shift_left($a, $b);
}

function lean_isize_dec_lt(int $a, int $b): int
{
    return (int) ($a < $b);
}

function lean_isize_dec_le(int $a, int $b): int
{
    return (int) ($a <= $b);
}

function lean_isize_div(int $a, int $b): int
{
    return $b === 0 ? 0 : ($a === PHP_INT_MIN && $b === -1 ? $a : intdiv($a, $b));
}

function lean_isize_mod(int $a, int $b): int
{
    return $b === 0 ? $a : $a % $b;
}

function lean_isize_shift_right(int $a, int $b): int
{
    return $a >> ($b & 63);
}

function lean_isize_complement(int $a): int
{
    return lean_usize_complement($a);
}

function lean_isize_neg(int $a): int
{
    return lean_usize_neg($a);
}

function lean_isize_abs(int $a): int
{
    return $a < 0 ? lean_isize_neg($a) : $a;
}

function lean_isize_of_nat(int|\GMP $a): int
{
    return lean_usize_of_nat($a);
}

function lean_isize_of_int(int|\GMP $a): int
{
    return numericLowBits($a, 64);
}

function lean_isize_to_int(int $a): int
{
    return $a;
}

function lean_isize_to_float(int $a): float
{
    return (float) lean_isize_to_int($a);
}

function lean_isize_to_float32(int $a): float
{
    return numericIntegerFloat32($a);
}

function lean_isize_to_int8(int $a): int
{
    return $a & 0xff;
}

function lean_isize_to_int16(int $a): int
{
    return $a & 0xffff;
}

function lean_isize_to_int32(int $a): int
{
    return $a & 0xffffffff;
}

function lean_isize_to_int64(int $a): int
{
    return $a;
}

function lean_bool_to_isize(int $a): int
{
    return (int) ($a !== 0);
}
