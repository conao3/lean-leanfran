<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function numericNormalize(int|\GMP $value): int|\GMP
{
    if ($value instanceof \GMP && gmp_cmp($value, PHP_INT_MIN) >= 0 && gmp_cmp($value, PHP_INT_MAX) <= 0) {
        return (int) gmp_strval($value);
    }
    return $value;
}

function numericCompare(int|\GMP $a, int|\GMP $b): int
{
    return is_int($a) && is_int($b) ? $a <=> $b : gmp_cmp($a, $b);
}

function numericIntResult(int|float $value): ?int
{
    return is_int($value) ? $value : null;
}

function lean_cstr_to_int(string $value): int|\GMP
{
    if (preg_match('/\A-?[0-9]+\z/', $value) !== 1) {
        throw new \InvalidArgumentException('Expected a decimal integer.');
    }
    return strlen(ltrim($value, '-')) < 19 ? (int) $value : numericNormalize(gmp_init($value, 10));
}

function lean_int_repr(int|\GMP $a): LString
{
    return new LString(is_int($a) ? (string) $a : gmp_strval($a));
}

function lean_nat_to_int(int|\GMP $a): int|\GMP
{
    return $a;
}

function lean_int_to_nat(int|\GMP $a): int|\GMP
{
    return numericCompare($a, 0) < 0 ? 0 : $a;
}

function lean_int_neg(int|\GMP $a): int|\GMP
{
    if (is_int($a)) {
        $result = numericIntResult(-$a);
        if ($result !== null) {
            return $result;
        }
    }
    return numericNormalize(gmp_neg($a));
}

function lean_int_neg_succ_of_nat(int|\GMP $a): int|\GMP
{
    return lean_int_sub(-1, $a);
}

function lean_nat_abs(int|\GMP $a): int|\GMP
{
    return numericCompare($a, 0) < 0 ? lean_int_neg($a) : $a;
}

function lean_int_add(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if (is_int($a) && is_int($b)) {
        $result = numericIntResult($a + $b);
        if ($result !== null) {
            return $result;
        }
    }
    return numericNormalize(gmp_add($a, $b));
}

function lean_int_sub(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if (is_int($a) && is_int($b)) {
        $result = numericIntResult($a - $b);
        if ($result !== null) {
            return $result;
        }
    }
    return numericNormalize(gmp_sub($a, $b));
}

function lean_int_mul(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if (is_int($a) && is_int($b)) {
        $result = numericIntResult($a * $b);
        if ($result !== null) {
            return $result;
        }
    }
    return numericNormalize(gmp_mul($a, $b));
}

function lean_int_div(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if ($b === 0) {
        return 0;
    }
    if (is_int($a) && is_int($b) && ($a !== PHP_INT_MIN || $b !== -1)) {
        return intdiv($a, $b);
    }
    return numericNormalize(gmp_div_q($a, $b));
}

function lean_int_mod(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if ($b === 0) {
        return $a;
    }
    if (is_int($a) && is_int($b)) {
        return $a % $b;
    }
    return numericNormalize(gmp_div_r($a, $b));
}

function lean_int_ediv(int|\GMP $a, int|\GMP $b): int|\GMP
{
    $quotient = lean_int_div($a, $b);
    if (numericCompare($a, 0) >= 0 || $b === 0 || lean_int_mod($a, $b) === 0) {
        return $quotient;
    }
    return lean_int_add($quotient, numericCompare($b, 0) > 0 ? -1 : 1);
}

function lean_int_emod(int|\GMP $a, int|\GMP $b): int|\GMP
{
    $remainder = lean_int_mod($a, $b);
    if ($b === 0 || numericCompare($remainder, 0) >= 0) {
        return $remainder;
    }
    return numericCompare($b, 0) > 0 ? lean_int_add($remainder, $b) : lean_int_sub($remainder, $b);
}

function lean_int_div_exact(int|\GMP $a, int|\GMP $b): int|\GMP
{
    if (lean_int_mod($a, $b) !== 0) {
        throw new \DomainException('Int.divExact requires the divisor to divide the dividend.');
    }
    return lean_int_div($a, $b);
}

function lean_int_dec_eq(int|\GMP $a, int|\GMP $b): int
{
    return (int) (numericCompare($a, $b) === 0);
}

function lean_int_dec_lt(int|\GMP $a, int|\GMP $b): int
{
    return (int) (numericCompare($a, $b) < 0);
}

function lean_int_dec_le(int|\GMP $a, int|\GMP $b): int
{
    return (int) (numericCompare($a, $b) <= 0);
}

function lean_int_dec_nonneg(int|\GMP $a): int
{
    return (int) (numericCompare($a, 0) >= 0);
}
