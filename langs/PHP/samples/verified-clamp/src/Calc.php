<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;
use Conao3\Leanfran\Model;

#[Lean(<<<'LEAN'
    def clampSpec (x lo hi : Int) : Int := max lo (min hi x)
    def ordered (_x lo hi : Int) : Bool := lo ≤ hi
    def inRange (_x lo hi : Int) (r : Int) : Bool := lo ≤ r && r ≤ hi
    LEAN)]
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
}
