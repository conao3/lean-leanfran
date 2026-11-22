<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;
use Conao3\Leanfran\Model;

#[Lean(<<<'LEAN'
    def clampSpec (x lo hi : Int) : Int := max lo (min hi x)
    def ordered (_x lo hi : Int) : Bool := lo ≤ hi
    def inRange (_x lo hi : Int) (r : Int) : Bool := lo ≤ r && r ≤ hi

    def addSpec (a b : Int) : Int := a + b
    def addFits (a b : Int) : Bool := -9223372036854775808 ≤ a + b && a + b ≤ 9223372036854775807
    def idSpec (a : Int) : Int := a
    def nextSpec (a : Int) : Int := a + 1
    def nextFits (a : Int) : Bool := -9223372036854775808 ≤ a + 1 && a + 1 ≤ 9223372036854775807
    structure Bounds where
      lo : Int
      hi : Int
      valid : lo ≤ hi

    def boundsLo (b : Bounds) : Int := b.lo
    LEAN, models: [Box::class, Color::class])]
final class Calc
{
    use Calc\Functions;

    #[Model(refines: 'clampSpec', requires: 'ordered', ensures: ['in_range' => 'inRange'])]
    public static function clamp(int $x, int $lo, int $hi): int
    {
        if ($x < $lo) {
            return $lo;
        }
        if ($x > $hi) {
            return $hi;
        }
        return $x;
    }

    #[Model(refines: 'addSpec', requires: 'addFits')]
    public static function add(int $a, int $b): int
    {
        return $a + $b;
    }
}
