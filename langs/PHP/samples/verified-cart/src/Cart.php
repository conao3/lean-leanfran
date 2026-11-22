<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;
use Conao3\Leanfran\Model;

#[Lean(<<<'LEAN'
    def totalSpec (prices : List Int) : Int := prices.sum

    def bounded (prices : List Int) : Bool :=
      prices.length ≤ 1000 && prices.all (fun price => 0 ≤ price && price ≤ 1000000)
    LEAN)]
final class Cart
{
    use Cart\Functions;

    /** @param list<int> $prices */
    #[Model(refines: 'totalSpec', requires: 'bounded')]
    public static function total(array $prices): int
    {
        $total = 0;
        foreach ($prices as $price) {
            $total += $price;
        }
        return $total;
    }
}
