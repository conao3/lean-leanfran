<?php

declare(strict_types=1);

use Leanfran\Generated\LeanSumTo;

require __DIR__ . '/vendor/autoload.php';

echo LeanSumTo::l_sumTo(100, 0), PHP_EOL;
echo LeanSumTo::l_sumTo(1, PHP_INT_MAX), PHP_EOL;
