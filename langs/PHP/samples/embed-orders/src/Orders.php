<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;

#[Lean(<<<'LEAN'
    structure Order where
      item : LineItem
      shipping : Nat

    def subtotal (order : Order) : Nat :=
      order.item.quantity * order.item.unitPrice
    LEAN, models: [LineItem::class])]
final class Orders
{
    use Orders\Functions;
}
