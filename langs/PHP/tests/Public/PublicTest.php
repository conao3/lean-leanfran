<?php

declare(strict_types=1);

use App\Lean\Pricing\Bigger;
use App\Lean\Pricing\Bounds;
use App\Lean\Pricing\Choices;
use App\Lean\Pricing\DiscountFixed;
use App\Lean\Pricing\DiscountLimited;
use App\Lean\Pricing\DiscountNone;
use App\Lean\Pricing\DiscountPercent;
use App\Lean\Pricing\Packed;
use App\Lean\Pricing\PairNatBool;
use App\Lean\Pricing\Pricing;
use App\Lean\Pricing\Range;
use App\Lean\Pricing\SingleOne;
use App\Lean\Pricing\Sized;
use App\Lean\Pricing\Small;
use Conao3\Leanfran\Err;
use Conao3\Leanfran\LeanIOError;
use Conao3\Leanfran\Ok;
use Conao3\Leanfran\ValidationError;
use PHPUnit\Framework\TestCase;

final class PublicTest extends TestCase
{
    public function testPricing(): void
    {
        self::assertSame(1800, Pricing::total([1200, 800], new DiscountPercent(10)));
        self::assertSame(5, Pricing::total([8, 2], new DiscountFixed(5)));
        self::assertSame(4, Pricing::total([4], new DiscountNone()));
        self::assertSame(2, Pricing::rangeWidth(new Range(lo: 1, hi: 3)));
        self::assertSame('{"lo":1,"hi":3}', Range::fromJson('{"lo": 1, "hi": 3}')->toJson());
        self::assertSame('{"percent":{"p":10}}', Pricing::discountEcho(new DiscountPercent(10))->toJson());
        self::assertSame('{"fixed":{"amount":5}}', new DiscountFixed(5)->toJson());
        self::assertSame('{"limited":2}', Pricing::discountEcho(new DiscountLimited(2))->toJson());
        self::assertSame('{"one":{"n":42}}', Pricing::singleEcho(new SingleOne(42))->toJson());

        self::assertIssues(
            static fn() => new Range(lo: 5, hi: 3),
            'Range.ok: lo ≤ hi',
            [['message' => 'lo ≤ hi', 'path' => ['Range', 'ok']]],
        );
        self::assertIssues(
            static fn() => new DiscountPercent('101'),
            'Discount.percent.h: p ≤ 100',
            [['message' => 'p ≤ 100', 'path' => ['Discount', 'percent', 'h']]],
        );
    }

    public function testSubtypeAndBounds(): void
    {
        self::assertSame(18, Pricing::small(9));
        self::assertSame(9, Pricing::smallEcho(new Small(9))->val);
        self::assertSame('9', Small::fromArray(['val' => 9])->toJson());
        self::assertSame(9, Small::fromJson('9')->toArray()['val']);
        self::assertSame('9', json_encode(new Small(9), JSON_THROW_ON_ERROR));
        self::assertIssues(
            static fn() => new Small('10'),
            'Small.property: val < 10',
            [['message' => 'val < 10', 'path' => ['Small', 'property']]],
        );
        self::assertIssues(
            static fn() => Pricing::small(gmp_init(10)),
            'n.Subtype.property: val < 10',
            [['message' => 'val < 10', 'path' => ['n', 'Subtype', 'property']]],
        );

        self::assertSame(['tag' => '字', 'items' => [1, 2]], Pricing::sizedEcho(new Sized('字', [1, 2]))->toArray());
        $fields = Sized::desc()->variants[0]['fields'];
        self::assertSame(['minLength' => '1'], $fields[0]['bounds']);
        self::assertSame(['maxItems' => '3'], $fields[1]['bounds']);
        self::assertIssues(
            static fn() => Sized::fromArray(['tag' => '', 'items' => [1, 2, 3, 4]]),
            'Sized.tagOk: 0 < tag.length',
            [
                ['message' => '0 < tag.length', 'path' => ['Sized', 'tagOk']],
                ['message' => 'items.length ≤ 3', 'path' => ['Sized', 'itemsOk']],
            ],
        );
    }

    public function testNestedFailures(): void
    {
        $bad = ['lo' => 5, 'hi' => 3];
        self::assertIssues(
            static fn() => Bounds::fromArray(['first' => $bad, 'rest' => [['lo' => 0, 'hi' => 1], $bad]]),
            'first.Range.ok: lo ≤ hi',
            [
                ['message' => 'lo ≤ hi', 'path' => ['first', 'Range', 'ok']],
                ['message' => 'lo ≤ hi', 'path' => ['rest', 1, 'Range', 'ok']],
            ],
        );
        self::assertIssues(
            static fn() => Bounds::fromJson('{"first":{"lo":5,"hi":3},"rest":[{"lo":4,"hi":2}]}'),
            'first.Range.ok: lo ≤ hi',
            [
                ['message' => 'lo ≤ hi', 'path' => ['first', 'Range', 'ok']],
                ['message' => 'lo ≤ hi', 'path' => ['rest', 0, 'Range', 'ok']],
            ],
        );
        self::assertIssues(
            static fn() => Pricing::total([1, gmp_init(-2), gmp_init(-3)], new DiscountNone()),
            'prices.1: Expected a non-negative integer.',
            [
                ['message' => 'Expected a non-negative integer.', 'path' => ['prices', 1]],
                ['message' => 'Expected a non-negative integer.', 'path' => ['prices', 2]],
            ],
        );
        $range = new Range(1, gmp_init('9223372036854775808', 10));
        $hi = $range->hi;
        self::assertInstanceOf(GMP::class, $hi);
        gmp_clrbit($hi, 63);
        self::assertIssues(
            static fn() => Pricing::ranges([$range]),
            'xs.0.Range.ok: lo ≤ hi',
            [['message' => 'lo ≤ hi', 'path' => ['xs', 0, 'Range', 'ok']]],
        );
    }

    public function testPackedScalars(): void
    {
        $values = [
            'flag' => true,
            'u8' => 255,
            'u16' => 65535,
            'u32' => 4294967295,
            'u64' => '18446744073709551615',
            'usize' => '9223372036854775808',
            'i8' => -128,
            'i16' => -32768,
            'i32' => -2147483648,
            'i64' => PHP_INT_MIN,
            'isize' => -12345,
            'f64' => 0.125,
            'f32' => 0.75,
            'c' => '𐐷',
            's' => 'é日',
            'n' => '100000000000000000000',
            'i' => '-100000000000000000000',
            'unit' => null,
        ];
        self::assertSame(255, Pricing::byteEcho(255));
        $packed = new Packed(...$values);
        $out = Pricing::packedEcho($packed);
        self::assertEquals($packed, $out);
        self::assertSame('9223372036854775807', gmp_strval(Pricing::packedRead($packed)));
        self::assertIsInt(Pricing::packedRead($packed));
        self::assertSame('18446744073709551615', gmp_strval($out->u64));
        self::assertSame('100000000000000000000', gmp_strval($out->n));
        self::assertSame('-100000000000000000000', gmp_strval($out->i));

        $bigger = new Bigger(...$values + ['extra' => 5]);
        self::assertEquals($bigger, Pricing::biggerEcho($bigger));
        self::assertSame($values['s'], $bigger->s);
        self::assertSame(5, $bigger->extra);

        self::assertIssues(
            static fn() => Packed::fromArray(array_replace($values, ['u8' => 256, 'c' => 'ab', 's' => "\xFF"])),
            'u8: Expected an unsigned 8-bit integer.',
            [
                ['message' => 'Expected an unsigned 8-bit integer.', 'path' => ['u8']],
                ['message' => 'Expected one Unicode scalar.', 'path' => ['c']],
                ['message' => 'Expected a valid UTF-8 string.', 'path' => ['s']],
            ],
        );
    }

    public function testContainersAndIo(): void
    {
        self::assertEquals(
            [3, [[-1, 2], [['a', true], new Ok(8)]]],
            Pricing::containers(3, [-1, 2], ['a', true], new Ok(8)),
        );
        self::assertEquals(
            [null, [[], [['b', false], new Err('empty')]]],
            Pricing::containers(null, [], ['b', false], new Err('empty')),
        );
        $choices = new Choices(9, gmp_init('9223372036854775808', 10), ['a', true], new Err('empty'), null);
        self::assertEquals($choices, Pricing::choicesEcho($choices));
        self::assertSame(
            '{"fit":9,"large":9223372036854775808,"pair":["a",true],"result":{"error":"empty"},"maybe":null}',
            $choices->toJson(),
        );
        self::assertEquals($choices, Choices::fromJson($choices->toJson()));
        self::assertIssues(
            static fn() => Choices::fromArray([
                'fit' => 10,
                'large' => 0,
                'pair' => ['a', true],
                'result' => ['ok' => 0],
            ]),
            'fit: Expected an integer less than 10.',
            [['message' => 'Expected an integer less than 10.', 'path' => ['fit']]],
        );
        self::assertSame(PHP_INT_MAX, Pricing::finEcho(PHP_INT_MAX));
        self::assertSame('9223372036854775808', gmp_strval(Pricing::bigFinEcho(gmp_init('9223372036854775808', 10))));
        self::assertIssues(
            static fn() => Pricing::bigFinEcho(gmp_init('1208925819614629174706176', 10)),
            'n: Expected an integer less than 1208925819614629174706176.',
            [['message' => 'Expected an integer less than 1208925819614629174706176.', 'path' => ['n']]],
        );
        $containers = new ReflectionMethod(Pricing::class, 'containers');
        self::assertIssues(
            static fn() => $containers->invoke(null, -1, [1 => 0], ['a', true], new Ok(-3)),
            'o: Expected a non-negative integer.',
            [
                ['message' => 'Expected a non-negative integer.', 'path' => ['o']],
                ['message' => 'Expected a list.', 'path' => ['a']],
                ['message' => 'Expected a non-negative integer.', 'path' => ['e', 'ok']],
            ],
        );
        self::assertEquals(new PairNatBool(5, true), Pricing::pairEcho(new PairNatBool(5, true)));
        self::assertSame(null, Pricing::unitEcho(null));
        self::assertSame('hello!', Pricing::ioEcho('hello'));
        $this->expectException(LeanIOError::class);
        $this->expectExceptionMessage('nope');
        Pricing::ioFail(null);
    }

    /** @param list<array{message: string, path: list<string|int>}> $issues */
    private static function assertIssues(Closure $invoke, string $message, array $issues): void
    {
        try {
            $invoke();
            self::fail('Expected ValidationError.');
        } catch (ValidationError $e) {
            self::assertSame($message, $e->getMessage());
            self::assertSame($issues, $e->issues);
        }
    }
}
