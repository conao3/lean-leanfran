<?php

declare(strict_types=1);

use App\Lean\Pricing\DiscountPercent;
use App\Lean\Pricing\Pricing;
use App\Lean\Pricing\Range;
use Conao3\Leanfran\ValidationError;

require __DIR__ . '/vendor/autoload.php';

$discount = DiscountPercent::fromJson('{"percent":{"p":10}}');
echo Pricing::total([1200, 800], $discount), PHP_EOL;
echo $discount->toJson(), PHP_EOL;

$range = Range::fromJson('{"lo":1,"hi":3}');
echo $range->toJson(), PHP_EOL;

try {
    new Range(lo: 5, hi: 3);
} catch (ValidationError $error) {
    echo $error->getMessage(), PHP_EOL;
}

echo json_encode(Range::jsonSchema(), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES), PHP_EOL;
