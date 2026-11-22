<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Model;

#[Model(spec: Calc::class, refines: 'nextSpec', requires: 'nextFits')]
function increment(int $a): int
{
    return $a + 1;
}
