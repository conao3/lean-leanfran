<?php

declare(strict_types=1);

use App\Lean\Json\Color;
use App\Lean\Pricing\Bounds;
use App\Lean\Pricing\DiscountFixed;
use App\Lean\Pricing\Range;
use Conao3\Leanfran\ValidationError;
use Conao3\Leanfran\Valinor;
use CuyZ\Valinor\Mapper\MappingError;
use CuyZ\Valinor\MapperBuilder;
use PHPUnit\Framework\TestCase;

final class ValinorTest extends TestCase
{
    public function testMapsGeneratedTypes(): void
    {
        $mapper = Valinor::configure(new MapperBuilder())->mapper();
        self::assertEquals(new Range(1, 3), $mapper->map(Range::class, ['lo' => 1, 'hi' => 3]));
        self::assertSame(Color::Red, $mapper->map(Color::class, 'red'));
        self::assertEquals(new DiscountFixed(5), $mapper->map(DiscountFixed::class, ['amount' => 5]));
        $bounds = $mapper->map(Bounds::class, [
            'first' => ['lo' => 1, 'hi' => 3],
            'rest' => [['lo' => 4, 'hi' => 8]],
        ]);
        self::assertEquals(new Bounds(new Range(1, 3), [new Range(4, 8)]), $bounds);
    }

    public function testCollectsValidationErrorAtTheMappedPath(): void
    {
        $mapper = Valinor::configure(new MapperBuilder())->mapper();
        try {
            $mapper->map(Bounds::class, ['first' => ['lo' => 1, 'hi' => 3], 'rest' => [['lo' => 5, 'hi' => 3]]]);
            self::fail('Expected a mapping error.');
        } catch (MappingError $e) {
            $messages = [];
            foreach ($e->messages() as $message) {
                $messages[$message->path()] = (string) $message;
            }
            self::assertSame(['rest.0' => 'Range.ok: lo ≤ hi'], $messages);
        }
    }

    public function testPropagatesValidationErrorWithTheOriginalBuilder(): void
    {
        $builder = new MapperBuilder();
        self::assertNotSame($builder, Valinor::configure($builder));
        $this->expectException(ValidationError::class);
        $this->expectExceptionMessage('Range.ok: lo ≤ hi');
        $builder->mapper()->map(Range::class, ['lo' => 5, 'hi' => 3]);
    }
}
