<?php

declare(strict_types=1);

namespace App;

use App\Calc\Bounds;
use Conao3\Leanfran\Model;

final class Properties
{
    /** @var list<array<mixed>> */
    public static array $observed = [];

    #[Model(spec: Calc::class, refines: 'clampSpec', requires: 'ordered')]
    public static function offByOne(int $x, int $lo, int $hi): int
    {
        if ($x >= $hi) {
            return $hi - 1;
        }
        return max($x, $lo);
    }

    #[Model(spec: Calc::class, refines: 'idSpec', requires: 'impossible')]
    public static function rejected(int $value): int
    {
        throw new \LogicException("Rejected input reached the implementation: $value");
    }

    /**
     * @param list<int> $list
     * @param array{0: int, 1: string} $tuple
     */
    #[Model(spec: Calc::class, refines: 'Recording.sameBounds')]
    public static function record(
        int $i,
        bool $bool,
        string $text,
        float $float,
        ?int $option,
        array $list,
        array $tuple,
        Color $color,
        Box $box,
        Bounds $bounds,
    ): Bounds {
        self::$observed[] = [
            $i,
            $bool,
            $text,
            $float,
            $option,
            $list,
            $tuple,
            $color,
            $box->value,
            $bounds->lo,
            $bounds->hi,
        ];
        return new Bounds($bounds->lo, $bounds->hi);
    }

    #[Model(spec: Calc::class, refines: 'addSpec')]
    public static function uncheckedAdd(int $a, int $b): int
    {
        return $a + $b;
    }

    #[Model(spec: Calc::class, ensures: ['in_range' => 'inRange'])]
    public static function badPostcondition(int $x, int $lo, int $hi): int
    {
        return 1;
    }

    #[Model(spec: Calc::class, ensures: ['in_range' => 'inRange'])]
    public static function throwing(int $x, int $lo, int $hi): int
    {
        throw new \DomainException('example failure');
    }
}
