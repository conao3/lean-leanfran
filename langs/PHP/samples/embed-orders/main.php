<?php

declare(strict_types=1);

use App\Checkout;
use App\LineItem;
use App\Orders\Order;

require __DIR__ . '/vendor/autoload.php';

$order = new Order(item: new LineItem(sku: 'tea', quantity: 2, unitPrice: 450), shipping: 100);

echo Checkout::orderedItem($order)->sku, ': ', Checkout::total($order), PHP_EOL;
