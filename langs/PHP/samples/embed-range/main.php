<?php

declare(strict_types=1);

use App\Pricing;
use App\Pricing\Range;

require __DIR__ . '/vendor/autoload.php';

echo Pricing::width(new Range(lo: 2, hi: 5)), PHP_EOL;
