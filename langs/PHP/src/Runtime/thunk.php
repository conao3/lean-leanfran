<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_mk_thunk(LClosure $fn): LThunk
{
    return new LThunk($fn);
}

function lean_thunk_pure(mixed $value): LThunk
{
    return new LThunk(null, $value);
}

function lean_thunk_get(LThunk $thunk): mixed
{
    if ($thunk->fn !== null) {
        $thunk->value = lean_apply($thunk->fn, [0]);
        $thunk->fn = null;
        if ($thunk->rc < 0) {
            lean_mark_persistent($thunk->value);
        }
    }
    return $thunk->value;
}

function lean_thunk_get_own(LThunk $thunk): mixed
{
    return lean_inc_ret(lean_thunk_get($thunk));
}

function lean_st_mk_ref(mixed $value): LRef
{
    return new LRef($value);
}

function lean_st_ref_get(LRef $ref): mixed
{
    if ($ref->value === null) {
        lean_internal_panic('null reference read');
    }
    return lean_inc_ret($ref->value);
}

function lean_st_ref_put(LRef $ref, mixed $value): int
{
    if ($ref->value !== null) {
        lean_internal_panic('ref.put on a nonempty reference');
    }
    $ref->value = $value;
    return 0;
}

function lean_st_ref_take(LRef $ref): mixed
{
    return lean_st_ref_swap($ref, null);
}

function lean_st_ref_swap(LRef $ref, mixed $value): mixed
{
    $old = $ref->value;
    if ($old === null) {
        lean_internal_panic('null reference read');
    }
    $ref->value = $value;
    return $old;
}

function lean_st_ref_ptr_eq(LRef $lhs, LRef $rhs): int
{
    return (int) ($lhs === $rhs);
}
