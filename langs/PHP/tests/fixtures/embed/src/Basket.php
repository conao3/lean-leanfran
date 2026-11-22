<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean as Verified;

#[Verified(source: <<<'LEAN'
    def twiceWidth (r : Range) : Nat := offset (width r + width r)
    def sameRange (r : Range) : Range := r
    LEAN, imports: ['Support'], uses: [Pricing::class])]
final class Basket
{
    use Basket\Functions;
}
