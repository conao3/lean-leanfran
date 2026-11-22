<?php

declare(strict_types=1);

use App\Lean\Json\Color;
use App\Lean\Json\Data;
use App\Lean\Json\ShapeNone;
use App\Lean\Json\TreeLeaf;
use App\Lean\Pricing\Bigger;
use App\Lean\Pricing\Bounds;
use App\Lean\Pricing\Choices;
use App\Lean\Pricing\DiscountNone;
use App\Lean\Pricing\Packed;
use App\Lean\Pricing\Sized;
use App\Lean\Pricing\Small;

require __DIR__ . '/bootstrap.php';

$types = [
    'Bigger' => Bigger::class,
    'Bounds' => Bounds::class,
    'Choices' => Choices::class,
    'Color' => Color::class,
    'Data' => Data::class,
    'Discount' => DiscountNone::class,
    'Packed' => Packed::class,
    'Shape' => ShapeNone::class,
    'Sized' => Sized::class,
    'Small' => Small::class,
    'Tree' => TreeLeaf::class,
];
$targets = ['draft-2020-12', 'draft-07', 'openapi-3.0'];

function normalizeSchema(mixed $value): mixed
{
    if ($value instanceof stdClass) {
        $fields = get_object_vars($value);
        ksort($fields, SORT_STRING);
        return (object) array_map(normalizeSchema(...), $fields);
    }
    if (is_array($value)) {
        return array_map(normalizeSchema(...), $value);
    }
    return is_int($value) && abs($value) >= (2 ** 53) ? (float) $value : $value;
}

$oracleFile = $argv[1] ?? throw new InvalidArgumentException('Expected the TypeScript schema fixture path.');
$source = file_get_contents($oracleFile);
if ($source === false) {
    throw new RuntimeException('Could not read ' . $oracleFile);
}
$oracle = json_decode($source, flags: JSON_THROW_ON_ERROR);
if (!is_array($oracle)) {
    throw new RuntimeException('Expected a list of TypeScript schemas.');
}

$actual = [];
foreach ($types as $type => $class) {
    foreach ($targets as $target) {
        $actual[] = ['type' => $type, 'target' => $target, 'schema' => $class::jsonSchema($target)];
    }
}
$rows = json_decode(json_encode($actual, JSON_THROW_ON_ERROR), flags: JSON_THROW_ON_ERROR);
if (!is_array($rows) || count($rows) !== count($oracle)) {
    throw new RuntimeException('PHP and TypeScript schema counts differ.');
}
foreach ($rows as $index => $row) {
    $expected = json_encode(normalizeSchema($oracle[$index]), JSON_THROW_ON_ERROR);
    $actual = json_encode(normalizeSchema($row), JSON_THROW_ON_ERROR);
    if ($actual !== $expected) {
        throw new RuntimeException("Schema mismatch at row $index.\nExpected $expected\nActual   $actual");
    }
}
if (Color::jsonSchema() !== Color::jsonSchema('draft-2020-12')) {
    throw new RuntimeException('Expected the default target to be draft-2020-12.');
}
try {
    Color::jsonSchema('draft-04');
    throw new RuntimeException('Expected an unsupported-target exception.');
} catch (InvalidArgumentException $e) {
    if (!str_contains($e->getMessage(), 'draft-04')) {
        throw $e;
    }
}
printf(
    "JSON Schema: %d types, %d targets, %d schemas match TypeScript\n",
    count($types),
    count($targets),
    count($rows),
);
