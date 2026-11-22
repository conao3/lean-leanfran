<?php

declare(strict_types=1);

use App\Basket;
use App\Pricing;
use App\Pricing\Range;
use App\Receipt;

require __DIR__ . '/vendor/autoload.php';

$range = new Range(lo: 2, hi: 5);
echo Pricing::width($range), "\n";
echo Basket::twiceWidth($range), "\n";
echo Basket::sameRange($range)->lo, "\n";
echo Receipt::receiptWidth($range), "\n";
