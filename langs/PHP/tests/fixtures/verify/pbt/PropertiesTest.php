<?php

declare(strict_types=1);

use App\Calc;
use App\Color;
use App\Properties;
use Conao3\Leanfran\Verify;
use Conao3\Leanfran\Verify\PropertyFailure;
use PHPUnit\Framework\TestCase;

final class PropertiesTest extends TestCase
{
    public function testClassAndFunctionMatchTheirSpecs(): void
    {
        Verify::checkClass(Calc::class);
        require_once __DIR__ . '/../src/Functions.php';
        Verify::checkModel(App\increment(...));
        self::assertSame(3, App\increment(2));
    }

    public function testOffByOneReportsTheCounterexample(): void
    {
        try {
            Verify::checkModel([Properties::class, 'offByOne'], seed: 23);
            self::fail('Expected the offset boundary to fail');
        } catch (PropertyFailure $error) {
            self::assertSame('App\\Properties\\offByOne', $error->function);
            self::assertSame('refines', $error->label);
            self::assertSame(23, $error->seed);
            self::assertSame([0, 0, 0], $error->input);
            self::assertSame(-1, $error->actual);
            self::assertSame(0, $error->expected);
            self::assertStringContainsString('seed=23, input=[0, 0, 0]', $error->getMessage());
        }
    }

    public function testSameSeedProducesTheSameValidInputs(): void
    {
        Verify::checkModel(Properties::record(...), runs: 120, seed: 29);
        $first = Properties::$observed;
        Properties::$observed = [];
        Verify::checkModel(Properties::record(...), runs: 120, seed: 29);
        self::assertSame($first, Properties::$observed);
        Properties::$observed = [];
        Verify::checkModel(Properties::record(...), runs: 120, seed: 31);
        self::assertNotSame($first, Properties::$observed);

        self::assertCount(120, $first);
        self::assertContains(PHP_INT_MIN, array_column($first, 0));
        self::assertContains(PHP_INT_MAX, array_column($first, 0));
        self::assertContains('', array_column($first, 2));
        self::assertContains('é', array_column($first, 2));
        self::assertContains(PHP_FLOAT_MAX, array_column($first, 3));
        self::assertContains(null, array_column($first, 4));
        self::assertContains([], array_column($first, 5));
        self::assertContains([1], array_column($first, 5));
        self::assertContains([1, 'a'], array_column($first, 6));
        self::assertContains(Color::Red, array_column($first, 7));
        self::assertContains(Color::Blue, array_column($first, 7));
        foreach ($first as [, , $text, , , , , , , $lo, $hi]) {
            self::assertSame(1, preg_match('//u', $text));
            self::assertLessThanOrEqual($hi, $lo);
        }
    }

    public function testImpossiblePreconditionReportsTheAcceptedCount(): void
    {
        $this->expectExceptionMessage('collected 0 of 3 inputs in 300 attempts (seed=7)');
        Verify::checkModel(Properties::rejected(...), runs: 3, seed: 7);
    }

    public function testOverflowIsReportedWithTheExactLeanResult(): void
    {
        try {
            Verify::checkModel(Properties::uncheckedAdd(...));
            self::fail('Expected PHP integer overflow to fail');
        } catch (PropertyFailure $error) {
            self::assertSame('refines', $error->label);
            self::assertSame([PHP_INT_MAX, PHP_INT_MAX], $error->input);
            self::assertInstanceOf(TypeError::class, $error->actual);
            self::assertSame($error->actual, $error->getPrevious());
            self::assertInstanceOf(GMP::class, $error->expected);
            self::assertSame('18446744073709551614', gmp_strval($error->expected));
            self::assertStringContainsString('spec expected 18446744073709551614', $error->getMessage());
        }
    }

    public function testPostconditionReportsItsLabelAndResult(): void
    {
        try {
            Verify::checkModel(Properties::badPostcondition(...));
            self::fail('Expected the postcondition to fail');
        } catch (PropertyFailure $error) {
            self::assertSame('in_range', $error->label);
            self::assertSame(1, $error->actual);
            self::assertFalse($error->predicate);
            self::assertTrue($error->expected);
        }
    }

    public function testThrowingWithOnlyAnEnsuresClauseIsACounterexample(): void
    {
        try {
            Verify::checkModel(Properties::throwing(...));
            self::fail('Expected the exception to fail the check');
        } catch (PropertyFailure $error) {
            self::assertSame('in_range', $error->label);
            self::assertInstanceOf(DomainException::class, $error->actual);
            self::assertNull($error->predicate);
        }
    }
}
