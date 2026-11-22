<?php

declare(strict_types=1);

use App\Basket;
use App\Input\Code;
use App\Input\Color;
use App\Input\Detail;
use App\OrderInput;
use App\Pricing;
use App\Pricing\Range;
use App\Receipt;

require __DIR__ . '/vendor/autoload.php';

$range = new Range(lo: 2, hi: 5);
echo Pricing::width($range), "\n";
echo Basket::twiceWidth($range), "\n";
echo Basket::sameRange($range)->lo, "\n";
echo Receipt::receiptWidth($range), "\n";

$order = Receipt::receiptOrder(new OrderInput(
    percent: 100,
    count: 2,
    remaining: 0,
    debt: -7,
    delta: -2,
    label: '♥',
    colors: [Color::Blue],
    items: [1, 2],
    pair: [-10, Code::Special],
    note: null,
    detail: new Detail(active: true, weight: 2.5),
    units: 2,
    class: 4,
));
echo $order->percent, "\n", $order->count, "\n", $order->remaining, "\n", $order->debt, "\n", $order->delta, "\n";
echo $order->label, "\n", $order->colors[0]->name, "\n", implode(',', $order->items), "\n";
echo $order->pair[0], "\n", $order->pair[1]->name, "\n";
echo $order->note ?? '(none)', "\n";
$detail = $order->detail ?? throw new RuntimeException('Expected the returned detail.');
echo $detail->active ? 'true' : 'false', "\n";
echo number_format($detail->weight, 6, '.', ''), "\n", $order->units, "\n", $order->class, "\n";
