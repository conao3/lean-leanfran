<?php

declare(strict_types=1);

use Conao3\Leanfran\Runtime as L;
use PHPUnit\Framework\TestCase;

final class NumericRuntimeTest extends TestCase
{
    public function testNativeIntegersAtBothBoundaries(): void
    {
        self::assertSame(PHP_INT_MAX, L\lean_cstr_to_nat('9223372036854775807'));
        self::assertSame(PHP_INT_MIN, L\lean_cstr_to_int('-9223372036854775808'));
        self::assertSame(0, L\lean_cstr_to_int('-000'));
        self::assertSame(42, L\lean_cstr_to_nat('00042'));
        self::assertSame(PHP_INT_MIN, L\lean_int_neg_succ_of_nat(PHP_INT_MAX));

        $positive = L\lean_nat_succ(PHP_INT_MAX);
        self::assertInstanceOf(GMP::class, $positive);
        self::assertSame('9223372036854775808', L\lean_nat_repr($positive)->s);
        self::assertSame(PHP_INT_MAX, L\lean_nat_pred($positive));
        self::assertSame(PHP_INT_MIN, L\lean_int_neg($positive));
        self::assertSame(0, L\lean_nat_sub(1, $positive));

        $negative = L\lean_int_sub(PHP_INT_MIN, 1);
        self::assertInstanceOf(GMP::class, $negative);
        self::assertSame('-9223372036854775809', L\lean_int_repr($negative)->s);
        self::assertSame(PHP_INT_MIN, L\lean_int_add($negative, 1));
        self::assertSame(0, L\lean_int_to_nat($negative));
    }

    public function testMultiplicationShiftAndDivisionNormalize(): void
    {
        $product = L\lean_nat_mul(PHP_INT_MAX, 2);
        self::assertInstanceOf(GMP::class, $product);
        self::assertSame(PHP_INT_MAX, L\lean_nat_div($product, 2));
        self::assertSame(0, L\lean_nat_mod($product, 2));
        self::assertSame(2, L\lean_nat_gcd($product, 4));
        self::assertSame(PHP_INT_MAX, L\lean_nat_shiftr($product, 1));
        self::assertSame('9223372036854775808', (string) L\lean_nat_shiftl(1, 63));
        self::assertSame('9223372036854775808', (string) L\lean_int_div(PHP_INT_MIN, -1));
        self::assertSame('9223372036854775808', (string) L\lean_nat_abs(PHP_INT_MIN));
    }

    public function testLeanDivisionConventions(): void
    {
        self::assertSame(0, L\lean_nat_div(9, 0));
        self::assertSame(9, L\lean_nat_mod(9, 0));
        self::assertSame(0, L\lean_int_ediv(-7, 0));
        self::assertSame(-7, L\lean_int_emod(-7, 0));
        self::assertSame(-2, L\lean_int_div(-7, 3));
        self::assertSame(-1, L\lean_int_mod(-7, 3));
        self::assertSame(-3, L\lean_int_ediv(-7, 3));
        self::assertSame(2, L\lean_int_emod(-7, 3));
        self::assertSame(3, L\lean_int_ediv(-7, -3));
        self::assertSame(2, L\lean_int_emod(-7, -3));
    }

    public function testUnsignedAndSignedBitPatterns(): void
    {
        self::assertSame(PHP_INT_MIN, L\lean_uint64_add(PHP_INT_MAX, 1));
        self::assertSame(-1, L\lean_uint64_sub(0, 1));
        self::assertSame(1, L\lean_uint64_mul(-1, -1));
        self::assertSame(PHP_INT_MAX, L\lean_uint64_div(-1, 2));
        self::assertSame(1, L\lean_uint64_mod(-1, 2));
        self::assertSame(PHP_INT_MAX, L\lean_uint64_shift_right(-1, 65));
        self::assertSame('18446744073709551615', (string) L\lean_uint64_to_nat(-1));
        self::assertSame(0, L\lean_usize_of_nat(L\lean_cstr_to_nat('18446744073709551616')));
        self::assertSame(0xff, L\lean_int8_shift_right(0x80, 0xff));
        self::assertSame(0x80, L\lean_int8_div(0x80, 0xff));
        self::assertSame(PHP_INT_MIN, L\lean_int64_div(PHP_INT_MIN, -1));
    }

    public function testFloatRoundingAndCanonicalBits(): void
    {
        self::assertSame(0x5e800000, L\lean_float32_to_bits(L\lean_uint64_to_float32(4611686293305294848)));
        self::assertSame(0x5e800001, L\lean_float32_to_bits(L\lean_uint64_to_float32(4611686293305294849)));
        self::assertSame(0x7fc00000, L\lean_float32_to_bits(L\lean_float32_of_bits(0xff800001)));
        self::assertSame(0x7ff8000000000000, L\lean_float_to_bits(L\lean_float_of_bits(-4503599627370495)));
        self::assertSame(0x80000000, L\lean_float32_to_bits(L\lean_float32_mul(-0.0, 1.0)));
        self::assertSame('-0.000000', L\lean_float_to_string(-0.0)->s);
        self::assertSame(-INF, L\lean_float_div(1.0, -0.0));
        self::assertSame(0, L\lean_float_to_int64(NAN));
    }

    public function testMalformedDecimalIsRejected(): void
    {
        $this->expectException(InvalidArgumentException::class);
        L\lean_cstr_to_int('1e3');
    }

    public function testInexactDivisionIsRejected(): void
    {
        $this->expectException(DomainException::class);
        L\lean_int_div_exact(PHP_INT_MIN, 3);
    }
}
