<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

use App\Lean\Pricing\DiscountFixed;
use App\Lean\Pricing\DiscountNone;
use App\Lean\Pricing\DiscountPercent;
use App\Lean\Pricing\Pricing;
use App\Lean\Pricing\Range;
use Conao3\Leanfran\ValidationError;

$mode = $argv[1] ?? throw new InvalidArgumentException('Expected the demo or facade mode.');
if ($mode === 'demo') {
    echo Pricing::total([1200, 800], new DiscountPercent(10)), PHP_EOL;
    try {
        new Range(lo: 5, hi: 3);
    } catch (ValidationError $e) {
        echo $e->getMessage(), PHP_EOL;
    }
    $range = Range::fromJson('{"lo": 1, "hi": 3}');
    echo $range->toJson(), PHP_EOL;
    exit();
}
if ($mode !== 'facade') {
    throw new InvalidArgumentException('Unknown public differential test mode: ' . $mode);
}

echo Pricing::total([1200, 800], new DiscountPercent(10)), PHP_EOL;
echo Pricing::total([42], new DiscountFixed(19)), PHP_EOL;
echo Pricing::total([5, 3], new DiscountNone()), PHP_EOL;
echo Pricing::rangeWidth(new Range(1, 3)), PHP_EOL;
echo Pricing::small(9), PHP_EOL;
echo Pricing::ioEcho('hello'), PHP_EOL;
