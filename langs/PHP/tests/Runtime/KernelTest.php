<?php

declare(strict_types=1);

use Conao3\Leanfran\Runtime as L;
use PHPUnit\Framework\TestCase;

final class KernelTest extends TestCase
{
    public function testArrayAndConstructorOwnership(): void
    {
        $child = new L\LString('shared');
        $array = new L\LArray([$child]);
        L\lean_inc($array);

        $copy = L\lean_array_uset($array, 0, 17);

        self::assertSame([$child], $array->a);
        self::assertSame([17], $copy->a);
        self::assertSame(1, $array->rc);
        self::assertSame(1, $child->rc);

        $parent = new L\Ctor(1, [$array], [8 => 42]);
        self::assertSame(42, L\lean_ctor_get_usize($parent, 1));
        self::assertSame($parent, L\lean_reset($parent, 1));
        self::assertSame(0, $child->rc);
        self::assertSame($parent, L\lean_reuse($parent, 2, true, [$copy]));
        self::assertSame(2, L\lean_obj_tag($parent));
        L\lean_dec($parent);
        self::assertSame(0, $copy->rc);
    }

    public function testDeepRelease(): void
    {
        $leaf = new L\LString('leaf');
        $node = $leaf;
        for ($i = 0; $i < 50000; ++$i) {
            $node = new L\Ctor(1, [$node]);
        }
        L\lean_dec($node);
        self::assertSame(0, $leaf->rc);
    }

    public function testUtf8PositionsAndSharedUpdate(): void
    {
        $s = new L\LString("é🌱\0");
        L\lean_mark_persistent($s);
        $t = L\lean_string_push($s, 33);
        self::assertSame("é🌱\0", $s->s);
        self::assertSame("é🌱\0!", $t->s);
        self::assertSame(4, L\lean_string_length($t));
        self::assertSame(8, L\lean_string_utf8_byte_size($t));
        self::assertSame(0, L\lean_string_is_valid_pos($t, 3));
        self::assertSame(0x1f331, L\lean_string_utf8_get($t, 2));
        self::assertSame(6, L\lean_string_utf8_next_fast($t, 2));
        self::assertSame(2, L\lean_string_utf8_prev($t, 6));
    }

    public function testMalformedUtf8RaisesAnError(): void
    {
        $this->expectException(InvalidArgumentException::class);
        new L\LString("\xed\xa0\x80");
    }

    public function testClosurePartialExactAndOversaturatedApplications(): void
    {
        $child = new L\LString('value');
        $f = new L\LClosure(
            static function (L\LString $value, int $a, int $b): int {
                L\lean_dec($value);
                return (10 * $a) + $b;
            },
            3,
            [$child],
        );
        L\lean_inc($f);
        $part = L\lean_apply($f, [4]);
        self::assertSame(2, $child->rc);
        self::assertSame(47, L\lean_apply($part, [7]));
        self::assertSame(1, $child->rc);
        self::assertSame(23, L\lean_apply($f, [2, 3]));
        self::assertSame(0, $child->rc);

        $outer = new L\LClosure(static fn(int $x) => new L\LClosure(static fn(int $y) => $x * $y, 1), 1);
        self::assertSame(42, L\lean_apply($outer, [6, 7]));
    }

    public function testThunkEvaluatesOnceAndOwnReadsRetainValue(): void
    {
        $calls = 0;
        $thunk = L\lean_mk_thunk(new L\LClosure(static function () use (&$calls): L\LString {
            ++$calls;
            return new L\LString('value');
        }, 1));
        $first = L\lean_thunk_get_own($thunk);
        self::assertSame($first, L\lean_thunk_get($thunk));
        self::assertSame(1, $calls);
        self::assertSame(2, $first->rc);
        L\lean_dec($thunk);
        self::assertSame(1, $first->rc);
    }
}
