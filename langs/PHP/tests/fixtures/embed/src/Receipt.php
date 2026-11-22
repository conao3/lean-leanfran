<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;

#[Lean(<<<'LEAN'
    def receiptWidth := twiceWidth
    def receiptOrder := order
    LEAN, uses: [Basket::class, Catalog::class])]
final class Receipt
{
    use Receipt\Functions;
}
