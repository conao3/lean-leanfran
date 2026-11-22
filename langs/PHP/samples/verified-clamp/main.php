<?php

declare(strict_types=1);

use App\Calc;
use Conao3\Leanfran\Verify;

require __DIR__ . '/vendor/autoload.php';

Verify::checkClass(Calc::class);
echo Calc::clamp(12, 0, 10), PHP_EOL;
