<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;

#[Lean(<<<'LEAN'
    def total (order : Order) : Nat :=
      subtotal order + order.shipping

    def orderedItem (order : Order) := order.item
    LEAN, uses: [Orders::class])]
final class Checkout
{
    use Checkout\Functions;
}
