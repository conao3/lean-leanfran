<?php

declare(strict_types=1);

use App\Lean\External\Frame;
use App\Lean\External\PublicExternal;
use App\Lean\Names\List_;
use App\Lean\Names\PublicNames;
use App\Lean\Names\Read;
use App\Lean\Pricing\DiscountFixed;
use App\Lean\Pricing\Range;
use PHPUnit\Framework\TestCase;

final class NamesTest extends TestCase
{
    public function testNames(): void
    {
        $summary = json_decode(
            file_get_contents(__DIR__ . '/../../test-out/public/names.json'),
            true,
            flags: JSON_THROW_ON_ERROR,
        );
        $files = array_map(basename(...), $summary['files']);
        self::assertContains('List_.php', $files);
        self::assertCount(2, array_filter(
            $files,
            static fn(string $name): bool => preg_match('/^name(?:_2)?\.php$/i', $name) === 1,
        ));
        self::assertSame([], $summary['skipped']);
        self::assertSame(7, PublicNames::class_(new List_(7)));
        $outputs = [PublicNames::doThing(1), PublicNames::doThing_2(1)];
        sort($outputs);
        self::assertSame([2, 3], $outputs);
        self::assertSame(7, PublicNames::names_primePrime(7));
        self::assertSame('class', Read::Class_->value);
        self::assertNotSame(strtolower(Read::from('lower')->name), strtolower(Read::from('Lower')->name));
    }

    public function testForeignTypes(): void
    {
        self::assertSame('{"lo":1,"hi":3}', PublicExternal::echoRange(new Range(1, 3))->toJson());
        self::assertSame('{"fixed":{"amount":5}}', PublicExternal::echoDiscount(new DiscountFixed(5))->toJson());
        $f = new Frame(1, 3, 'hello');
        self::assertSame('{"lo":1,"hi":3,"tag":"hello"}', PublicExternal::echoFrame($f)->toJson());
        self::assertFileDoesNotExist(__DIR__ . '/../../test-out/public/external/Range.php');
        self::assertFileDoesNotExist(__DIR__ . '/../../test-out/public/external/Discount.php');
    }
}
