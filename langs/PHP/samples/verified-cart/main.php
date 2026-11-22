<?php

declare(strict_types=1);

use App\Cart;
use Conao3\Leanfran\Verify;

require __DIR__ . '/vendor/autoload.php';

Verify::checkClass(Cart::class);
echo Cart::total([120, 25, 50]), PHP_EOL;
