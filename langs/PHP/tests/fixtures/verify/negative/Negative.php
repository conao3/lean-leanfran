<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Model;

final class Negative
{
    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function missing(int $x): int
    {
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function mismatch(int $x): int
    {
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function withAxiom(int $x): int
    {
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function withSorry(int $x): int
    {
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'addSpec')]
    public static function unsafeAdd(int $a, int $b): int
    {
        return $a + $b;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function division(int $x): float
    {
        return $x / 2;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function looseEqual(int $x): bool
    {
        return $x == 2;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function looseNotEqual(int $x): bool
    {
        return $x != 2;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function spaceship(int $x): int
    {
        return $x <=> 2;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function reference(int &$x): int
    {
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function referenceAssign(int $x): int
    {
        $y = &$x;
        return $y;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function globalVariable(int $x): int
    {
        global $x;
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function staticVariable(int $x): int
    {
        static $stored = 0;
        return $stored + $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function setProperty(Box $x): int
    {
        $x->value = 2;
        return $x->value;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function dynamicCall(string $call): int
    {
        return $call();
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function interpolation(string $x): string
    {
        return "value $x";
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function stringIndex(string $x): string
    {
        return $x[0];
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function coalesce(?int $x): int
    {
        return $x ?? 2;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function variadic(int ...$x): int
    {
        return 0;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function generator(int $x): \Generator
    {
        yield $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function output(int $x): int
    {
        echo $x;
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function input(int $x): int
    {
        return strlen((string) fread(STDIN, $x));
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function invalidUtf8(int $x): string
    {
        return "\xff";
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function sameObject(Box $x, Box $y): bool
    {
        return $x === $y;
    }

    /** @param list<int> $x
     * @param list<int> $y
     */
    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function sameList(array $x, array $y): bool
    {
        return $x === $y;
    }

    /** @param array{0: int, 1: string} $x
     * @param array{0: int, 1: string} $y
     */
    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function sameTuple(array $x, array $y): bool
    {
        return $x !== $y;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function missingArgumentType($x): int
    {
        return 0;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function missingResultType(int $x)
    {
        return $x;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function mixedArgument(mixed $x): int
    {
        return 0;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function untypedArray(array $x): int
    {
        return 0;
    }

    #[Model(spec: Calc::class, refines: 'idSpec')]
    public static function unionArgument(int|string $x): int
    {
        return 0;
    }
}
