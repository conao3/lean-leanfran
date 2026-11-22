<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;

#[Lean('def receiptWidth := twiceWidth', uses: [Basket::class])]
final class Receipt
{
    use Receipt\Functions;
}
