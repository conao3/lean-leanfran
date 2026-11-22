<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_ptr_addr(mixed $value): int
{
    return 0;
}

function lean_is_exclusive_obj(mixed $value): int
{
    return (int) lean_is_exclusive($value);
}

function lean_array_propagate_mark(LArray $src, LArray $dest): LArray
{
    return $dest;
}

function lean_copy_array(LArray $array): LArray
{
    foreach ($array->a as $value) {
        lean_inc($value);
    }
    return new LArray($array->a);
}

function lean_array_extract(LArray $array, int|\GMP $start, int|\GMP $stop): LArray
{
    $size = count($array->a);
    $end = is_int($stop) ? min($stop, $size) : $size;
    $items = is_int($start) && $start < $end ? array_slice($array->a, $start, $end - $start) : [];
    foreach ($items as $item) {
        lean_inc($item);
    }
    return new LArray($items);
}

function lean_mk_array(int|\GMP $size, mixed $value): LArray
{
    if (!is_int($size) || $size < 0) {
        lean_internal_panic('out of memory');
    }
    if ($size === 0) {
        lean_dec($value);
        return new LArray();
    }
    lean_inc_n($value, $size - 1);
    return new LArray(array_fill(0, $size, $value));
}

function lean_string_lt(LString $a, LString $b): int
{
    return (int) (strcmp($a->s, $b->s) < 0);
}

function lean_string_memcmp(LString $a, LString $b, int|\GMP $left, int|\GMP $right, int|\GMP $length): int
{
    if ($length === 0) {
        return 1;
    }
    if (
        !is_int($left)
        || !is_int($right)
        || !is_int($length)
        || $left < 0
        || $right < 0
        || $length < 0
        || $length > (strlen($a->s) - $left)
        || $length > (strlen($b->s) - $right)
    ) {
        throw new \OutOfBoundsException('String comparison exceeds the available byte range.');
    }
    return (int) (substr($a->s, $left, $length) === substr($b->s, $right, $length));
}

const LEAN_HASH_MULTIPLIER = -4132994306676758123;

function hashMixWord(int $word): int
{
    $word = lean_uint64_mul($word, LEAN_HASH_MULTIPLIER);
    return $word ^ lean_uint64_shift_right($word, 47);
}

function lean_uint64_mix_hash(int $a, int $b): int
{
    return lean_uint64_mul($a ^ hashMixWord($b) ^ LEAN_HASH_MULTIPLIER, LEAN_HASH_MULTIPLIER);
}

function hashReadWord(string $data, int $offset): int
{
    $word = unpack('P', $data, $offset)[1] ?? null;
    if (!is_int($word)) {
        throw new \LogicException('Could not decode a 64-bit hash word.');
    }
    return $word;
}

function hashRuntimeBytes(string $data): int
{
    $size = strlen($data);
    $hash = 11 ^ lean_uint64_mul($size, LEAN_HASH_MULTIPLIER);
    $offset = 0;
    for (; ($offset + 8) <= $size; $offset += 8) {
        $word = hashMixWord(hashReadWord($data, $offset));
        $hash = lean_uint64_mul($hash ^ lean_uint64_mul($word, LEAN_HASH_MULTIPLIER), LEAN_HASH_MULTIPLIER);
    }
    if ($offset < $size) {
        $tail = hashReadWord(str_pad(substr($data, $offset), 8, "\0"), 0);
        $hash = lean_uint64_mul($hash ^ $tail, LEAN_HASH_MULTIPLIER);
    }
    $hash ^= lean_uint64_shift_right($hash, 47);
    $hash = lean_uint64_mul($hash, LEAN_HASH_MULTIPLIER);
    return $hash ^ lean_uint64_shift_right($hash, 47);
}

function lean_string_hash(LString $value): int
{
    return hashRuntimeBytes($value->s);
}

function lean_nat_lcm(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return numericNormalize(gmp_lcm($a, $b));
}

function lean_int_land(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return is_int($a) && is_int($b) ? $a & $b : numericNormalize(gmp_and($a, $b));
}

function lean_int_lor(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return is_int($a) && is_int($b) ? $a | $b : numericNormalize(gmp_or($a, $b));
}

function lean_int_xor(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return is_int($a) && is_int($b) ? $a ^ $b : numericNormalize(gmp_xor($a, $b));
}

function lean_big_usize_to_nat(int $value): int|\GMP
{
    return lean_usize_to_nat($value);
}

function lean_unsigned_to_nat(int $value): int
{
    return $value & 0xffffffff;
}

function lean_int64_to_int(int $value): int
{
    return $value;
}

function fmod(float $a, float $b): float
{
    return \fmod($a, $b);
}

function fmodf(float $a, float $b): float
{
    return numericFloat32(\fmod($a, $b));
}

function lean_int8_to_uint8(int $value): int
{
    return $value & 0xff;
}

function lean_int8_to_uint16(int $value): int
{
    return numericSignExtend($value, 8) & 0xffff;
}

function lean_int8_to_uint32(int $value): int
{
    return numericSignExtend($value, 8) & 0xffffffff;
}

function lean_int8_to_uint64(int $value): int
{
    return numericSignExtend($value, 8);
}

function lean_int8_to_usize(int $value): int
{
    return numericSignExtend($value, 8);
}

function lean_int16_to_uint8(int $value): int
{
    return $value & 0xff;
}

function lean_int16_to_uint16(int $value): int
{
    return $value & 0xffff;
}

function lean_int16_to_uint32(int $value): int
{
    return numericSignExtend($value, 16) & 0xffffffff;
}

function lean_int16_to_uint64(int $value): int
{
    return numericSignExtend($value, 16);
}

function lean_int16_to_usize(int $value): int
{
    return numericSignExtend($value, 16);
}

function lean_int32_to_uint8(int $value): int
{
    return $value & 0xff;
}

function lean_int32_to_uint16(int $value): int
{
    return $value & 0xffff;
}

function lean_int32_to_uint32(int $value): int
{
    return $value & 0xffffffff;
}

function lean_int32_to_uint64(int $value): int
{
    return numericSignExtend($value, 32);
}

function lean_int32_to_usize(int $value): int
{
    return numericSignExtend($value, 32);
}

function lean_int64_to_uint8(int $value): int
{
    return $value & 0xff;
}

function lean_int64_to_uint16(int $value): int
{
    return $value & 0xffff;
}

function lean_int64_to_uint32(int $value): int
{
    return $value & 0xffffffff;
}

function lean_int64_to_uint64(int $value): int
{
    return $value;
}

function lean_int64_to_usize(int $value): int
{
    return $value;
}

function lean_isize_to_uint8(int $value): int
{
    return $value & 0xff;
}

function lean_isize_to_uint16(int $value): int
{
    return $value & 0xffff;
}

function lean_isize_to_uint32(int $value): int
{
    return $value & 0xffffffff;
}

function lean_isize_to_uint64(int $value): int
{
    return $value;
}

function lean_isize_to_usize(int $value): int
{
    return $value;
}

function lean_void_mk(mixed $value): int
{
    lean_dec($value);
    return 0;
}
