<?php

declare(strict_types=1);

use App\Catalog;
use App\Input\Code;
use App\OrderInput;
use Conao3\Leanfran\ValidationError;

require __DIR__ . '/vendor/autoload.php';

$reflection = new ReflectionClass(OrderInput::class);
$valid = [
    'percent' => 100,
    'count' => 1,
    'remaining' => 0,
    'debt' => -1,
    'delta' => -2,
    'label' => 'name',
    'colors' => [],
    'items' => [1],
    'pair' => [0, Code::Standard],
    'note' => 'note',
    'detail' => null,
    'units' => 2,
    'class' => 2,
];
Catalog::order($reflection->newInstanceArgs($valid));
foreach ([
    'percent' => [101, ['o', 'percent']],
    'count' => [0, ['o', 'count']],
    'remaining' => [-1, ['o', 'remaining']],
    'debt' => [0, ['o', 'debt']],
    'delta' => [-1, ['o', 'delta']],
    'label' => ['', ['o', 'label']],
    'items' => [[0], ['o', 'items']],
    'pair' => [[11, Code::Standard], ['o', 'pair']],
    'note' => ['', ['o', 'note']],
    'units' => [1, ['o', 'units']],
] as $name => [$value, $path]) {
    try {
        Catalog::order($reflection->newInstanceArgs([$name => $value] + $valid));
        throw new RuntimeException("An invalid model value was accepted for $name.");
    } catch (ValidationError $error) {
        if ($error->issues[0]['path'] !== $path) {
            throw $error;
        }
        echo $error->getMessage(), "\n";
    }
}

foreach ([[], ['1']] as $index => $items) {
    try {
        Catalog::order($reflection->newInstanceArgs(['items' => $items] + $valid));
        throw new RuntimeException('An invalid list was accepted.');
    } catch (ValidationError $error) {
        $path = $index === 0 ? ['o', 'items'] : ['o', 'items', 0];
        if ($error->issues[0]['path'] !== $path) {
            throw $error;
        }
        echo $error->getMessage(), "\n";
    }
}
