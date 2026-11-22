<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_mk_empty_array(): LArray
{
    return new LArray();
}

function checkCapacity(int|\GMP $capacity): void
{
    if (!is_int($capacity) || $capacity < 0) {
        lean_internal_panic('out of memory');
    }
}

function lean_mk_empty_array_with_capacity(int|\GMP $capacity): LArray
{
    checkCapacity($capacity);
    return new LArray();
}

function lean_array_mk(Ctor|int $list): LArray
{
    $a = new LArray();
    for ($node = $list; $node instanceof Ctor; $node = $node->objs[1]) {
        $a->a[] = lean_inc_ret($node->objs[0]);
    }
    lean_dec($list);
    return $a;
}

function lean_array_to_list(LArray $a): Ctor|int
{
    $list = 0;
    for ($i = count($a->a) - 1; $i >= 0; --$i) {
        $list = new Ctor(1, [lean_inc_ret($a->a[$i]), $list]);
    }
    lean_dec($a);
    return $list;
}

function lean_array_size(LArray $a): int
{
    return count($a->a);
}

function lean_array_get_size(LArray $a): int
{
    return lean_array_size($a);
}

function lean_array_sz(LArray $a): int
{
    $size = lean_array_size($a);
    lean_dec($a);
    return $size;
}

function indexInBounds(int|\GMP $index, int $size): bool
{
    return is_int($index) && $index >= 0 && $index < $size;
}

function checkIndex(int $index, int $size): void
{
    if (!indexInBounds($index, $size)) {
        throw new \OutOfBoundsException("Invalid Lean index $index for size $size.");
    }
}

function lean_array_uget_borrowed(LArray $a, int $i): mixed
{
    checkIndex($i, count($a->a));
    return $a->a[$i];
}

function lean_array_uget(LArray $a, int $i): mixed
{
    return lean_inc_ret(lean_array_uget_borrowed($a, $i));
}

function lean_array_fget_borrowed(LArray $a, int $i): mixed
{
    return lean_array_uget_borrowed($a, $i);
}

function lean_array_fget(LArray $a, int $i): mixed
{
    return lean_array_uget($a, $i);
}

function lean_array_get_panic(mixed $default): mixed
{
    return lean_panic_fn($default, new LString('Error: index out of bounds'));
}

function lean_array_get(mixed $default, LArray $a, int|\GMP $i): mixed
{
    return indexInBounds($i, count($a->a)) ? lean_array_uget($a, $i) : lean_array_get_panic(lean_inc_ret($default));
}

function lean_array_get_borrowed(mixed $default, LArray $a, int|\GMP $i): mixed
{
    return indexInBounds($i, count($a->a)) ? $a->a[$i] : lean_array_get_panic(lean_inc_ret($default));
}

function lean_ensure_exclusive_array(LArray $a): LArray
{
    if (lean_is_exclusive($a)) {
        return $a;
    }
    $copy = new LArray($a->a);
    foreach ($copy->a as $value) {
        lean_inc($value);
    }
    lean_dec($a);
    return $copy;
}

function lean_array_push(LArray $a, mixed $v): LArray
{
    $a = lean_ensure_exclusive_array($a);
    $a->a[] = $v;
    return $a;
}

function lean_array_uset(LArray $a, int $i, mixed $v): LArray
{
    checkIndex($i, count($a->a));
    $a = lean_ensure_exclusive_array($a);
    lean_dec($a->a[$i]);
    $a->a[$i] = $v;
    return $a;
}

function lean_array_fset(LArray $a, int $i, mixed $v): LArray
{
    return lean_array_uset($a, $i, $v);
}

function lean_array_set_panic(LArray $a, mixed $v): LArray
{
    lean_dec($v);
    return lean_panic_fn($a, new LString('Error: index out of bounds'));
}

function lean_array_set(LArray $a, int|\GMP $i, mixed $v): LArray
{
    return indexInBounds($i, count($a->a)) ? lean_array_uset($a, $i, $v) : lean_array_set_panic($a, $v);
}

function lean_array_pop(LArray $a): LArray
{
    if ($a->a !== []) {
        $a = lean_ensure_exclusive_array($a);
        lean_dec(array_pop($a->a));
    }
    return $a;
}

function lean_array_uswap(LArray $a, int $i, int $j): LArray
{
    checkIndex($i, count($a->a));
    checkIndex($j, count($a->a));
    $a = lean_ensure_exclusive_array($a);
    [$a->a[$i], $a->a[$j]] = [$a->a[$j], $a->a[$i]];
    return $a;
}

function lean_array_fswap(LArray $a, int $i, int $j): LArray
{
    return lean_array_uswap($a, $i, $j);
}

function lean_array_swap(LArray $a, int|\GMP $i, int|\GMP $j): LArray
{
    if (!indexInBounds($i, count($a->a)) || !indexInBounds($j, count($a->a))) {
        return $a;
    }
    return lean_array_uswap($a, $i, $j);
}

function lean_mk_empty_byte_array(int|\GMP $capacity): LByteArray
{
    checkCapacity($capacity);
    return new LByteArray();
}

function lean_byte_array_mk(LArray $a): LByteArray
{
    $b = new LByteArray();
    foreach ($a->a as $byte) {
        $b->b .= chr($byte);
    }
    lean_dec($a);
    return $b;
}

function lean_byte_array_data(LByteArray $a): LArray
{
    $r = new LArray();
    for ($i = 0, $size = strlen($a->b); $i < $size; ++$i) {
        $r->a[] = ord($a->b[$i]);
    }
    lean_dec($a);
    return $r;
}

function lean_sarray_size(LByteArray|LFloatArray $a): int
{
    return $a instanceof LByteArray ? strlen($a->b) : count($a->a);
}

function lean_byte_array_size(LByteArray $a): int
{
    return lean_sarray_size($a);
}

function lean_sarray_dec_eq(LByteArray $a, LByteArray $b): int
{
    return (int) ($a->b === $b->b);
}

function lean_byte_array_uget(LByteArray $a, int $i): int
{
    checkIndex($i, strlen($a->b));
    return ord($a->b[$i]);
}

function lean_byte_array_fget(LByteArray $a, int $i): int
{
    return lean_byte_array_uget($a, $i);
}

function lean_byte_array_get(LByteArray $a, int|\GMP $i): int
{
    return indexInBounds($i, strlen($a->b)) ? ord($a->b[$i]) : 0;
}

function exclusiveBytes(LByteArray $a): LByteArray
{
    if (lean_is_exclusive($a)) {
        return $a;
    }
    $copy = new LByteArray($a->b);
    lean_dec($a);
    return $copy;
}

function lean_byte_array_push(LByteArray $a, int $v): LByteArray
{
    $a = exclusiveBytes($a);
    $a->b .= chr($v);
    return $a;
}

function lean_byte_array_uset(LByteArray $a, int $i, int $v): LByteArray
{
    checkIndex($i, strlen($a->b));
    $a = exclusiveBytes($a);
    $a->b[$i] = chr($v);
    return $a;
}

function lean_byte_array_fset(LByteArray $a, int $i, int $v): LByteArray
{
    return lean_byte_array_uset($a, $i, $v);
}

function lean_byte_array_set(LByteArray $a, int|\GMP $i, int $v): LByteArray
{
    return indexInBounds($i, strlen($a->b)) ? lean_byte_array_uset($a, $i, $v) : $a;
}

function lean_mk_empty_float_array(int|\GMP $capacity): LFloatArray
{
    checkCapacity($capacity);
    return new LFloatArray();
}

function lean_float_array_mk(LArray $a): LFloatArray
{
    $r = new LFloatArray($a->a);
    lean_dec($a);
    return $r;
}

function lean_float_array_data(LFloatArray $a): LArray
{
    $r = new LArray($a->a);
    lean_dec($a);
    return $r;
}

function lean_float_array_size(LFloatArray $a): int
{
    return lean_sarray_size($a);
}

function lean_float_array_uget(LFloatArray $a, int $i): float
{
    checkIndex($i, count($a->a));
    return $a->a[$i];
}

function lean_float_array_fget(LFloatArray $a, int $i): float
{
    return lean_float_array_uget($a, $i);
}

function lean_float_array_get(LFloatArray $a, int|\GMP $i): float
{
    return indexInBounds($i, count($a->a)) ? $a->a[$i] : 0.0;
}

function exclusiveFloats(LFloatArray $a): LFloatArray
{
    if (lean_is_exclusive($a)) {
        return $a;
    }
    $copy = new LFloatArray($a->a);
    lean_dec($a);
    return $copy;
}

function lean_float_array_push(LFloatArray $a, float $v): LFloatArray
{
    $a = exclusiveFloats($a);
    $a->a[] = $v;
    return $a;
}

function lean_float_array_uset(LFloatArray $a, int $i, float $v): LFloatArray
{
    checkIndex($i, count($a->a));
    $a = exclusiveFloats($a);
    $a->a[$i] = $v;
    return $a;
}

function lean_float_array_fset(LFloatArray $a, int $i, float $v): LFloatArray
{
    return lean_float_array_uset($a, $i, $v);
}

function lean_float_array_set(LFloatArray $a, int|\GMP $i, float $v): LFloatArray
{
    return indexInBounds($i, count($a->a)) ? lean_float_array_uset($a, $i, $v) : $a;
}
