<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_cstr_to_nat(string $value): int|\GMP
{
    if (preg_match('/\A[0-9]+\z/', $value) !== 1) {
        throw new \InvalidArgumentException('Expected a decimal natural number.');
    }
    return strlen($value) < 19 ? (int) $value : numericNormalize(gmp_init($value, 10));
}

function lean_nat_repr(int|\GMP $a): LString
{
    return lean_int_repr($a);
}

function lean_nat_add(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return lean_int_add($a, $b);
}

function lean_nat_sub(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return lean_int_to_nat(lean_int_sub($a, $b));
}

function lean_nat_mul(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return lean_int_mul($a, $b);
}

function lean_nat_div(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return lean_int_div($a, $b);
}

function lean_nat_mod(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return lean_int_mod($a, $b);
}

function lean_nat_div_exact(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return lean_int_div_exact($a, $b);
}

function numericPower(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if ($b === 0) {
        return 1;
    }
    if ($a === 0 || $a === 1) {
        return $a;
    }
    if ($a === -1) {
        return lean_nat_mod($b, 2) === 0 ? 1 : -1;
    }
    if (!is_int($b) || $b > 0xffffffff) {
        lean_internal_panic('Nat.pow exponent is too big');
    }
    if (is_int($a)) {
        $result = $a ** $b;
        if (is_int($result)) {
            return $result;
        }
    }
    return numericNormalize(gmp_pow($a, $b));
}

function lean_nat_pow(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return numericPower($a, $b);
}

function lean_int_pow(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return numericPower($a, $b);
}

function lean_nat_powmod(int|\GMP $a, int|\GMP $b, int|\GMP $m): int|\GMP
{
    return $m === 0 ? lean_nat_pow($a, $b) : numericNormalize(gmp_powm($a, $b, $m));
}

function lean_nat_gcd(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if (!is_int($a) || !is_int($b)) {
        return numericNormalize(gmp_gcd($a, $b));
    }
    while ($b !== 0) {
        [$a, $b] = [$b, $a % $b];
    }
    return $a;
}

function lean_nat_log2(int|\GMP $a): int
{
    return strlen(is_int($a) ? decbin($a) : gmp_strval($a, 2)) - 1;
}

function lean_nat_land(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return is_int($a) && is_int($b) ? $a & $b : numericNormalize(gmp_and($a, $b));
}

function lean_nat_lor(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return is_int($a) && is_int($b) ? $a | $b : numericNormalize(gmp_or($a, $b));
}

function lean_nat_lxor(int|\GMP $a, int|\GMP $b): int|\GMP
{
    return is_int($a) && is_int($b) ? $a ^ $b : numericNormalize(gmp_xor($a, $b));
}

function lean_nat_shiftl(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if ($a === 0 || $b === 0) {
        return $a;
    }
    if (!is_int($b) || $b > 0xffffffff) {
        lean_internal_panic('Nat.shiftl exponent is too big');
    }
    if (is_int($a) && $b < 63 && $a <= (PHP_INT_MAX >> $b)) {
        return $a << $b;
    }
    $value = is_int($a) ? gmp_init($a) : $a;
    return numericNormalize($value << $b);
}

function lean_nat_shiftr(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if (!is_int($b)) {
        return 0;
    }
    if (is_int($a)) {
        return $a >> $b;
    }
    return $b > lean_nat_log2($a) ? 0 : numericNormalize($a >> $b);
}

function lean_int_shift_right(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if (numericCompare($a, 0) >= 0) {
        return lean_nat_shiftr($a, $b);
    }
    return lean_int_sub(-1, lean_nat_shiftr(lean_int_sub(-1, $a), $b));
}

function lean_nat_dec_eq(int|\GMP $a, int|\GMP $b): int
{
    return lean_int_dec_eq($a, $b);
}

function lean_nat_dec_lt(int|\GMP $a, int|\GMP $b): int
{
    return lean_int_dec_lt($a, $b);
}

function lean_nat_dec_le(int|\GMP $a, int|\GMP $b): int
{
    return lean_int_dec_le($a, $b);
}

function lean_nat_pred(int|\GMP $a): int|\GMP
{
    return lean_nat_sub($a, 1);
}

function lean_nat_succ(int|\GMP $a): int|\GMP
{
    return lean_nat_add($a, 1);
}
