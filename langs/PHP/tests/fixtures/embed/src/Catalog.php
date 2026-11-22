<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;

#[Lean(<<<'LEAN'
    def order (o : OrderInput) : OrderInput :=
      { o with «class» := o.«class» - 1 }
    LEAN, models: [OrderInput::class])]
final class Catalog
{
    use Catalog\Functions;
}
