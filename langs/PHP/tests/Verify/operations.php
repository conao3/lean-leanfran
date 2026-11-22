<?php

declare(strict_types=1);

use Conao3\Leanfran\Runtime\Ctor;
use Conao3\Leanfran\Runtime\LString;
use Random\Engine\Mt19937;
use Random\Randomizer;
use Verification\Semantics as Model;

require __DIR__ . '/../../vendor/autoload.php';
require $argv[1];

function requireEqual(string $op, mixed $actual, mixed $expected, mixed ...$args): void
{
    if (is_float($actual) && is_float($expected)) {
        $equal = is_nan($actual) && is_nan($expected) || pack('d', $actual) === pack('d', $expected);
    } else {
        $equal = $actual === $expected;
    }
    if (!$equal) {
        throw new RuntimeException(
            $op . ' ' . var_export($args, true) . ': wanted ' . var_export($expected, true) . ', got '
                . var_export($actual, true),
        );
    }
}

function outcome(Ctor $result): mixed
{
    $value = $result->objs[0];
    if ($result->tag === 1) {
        return $value;
    }
    return match ($value) {
        0 => 'overflow',
        1 => 'divisionByZero',
        2 => 'arithmeticError',
        3 => 'undefinedIndex',
        4 => 'unhandledMatch',
        default => throw new RuntimeException('unknown exception'),
    };
}

function nativeNumber(callable $evaluate): mixed
{
    try {
        return $evaluate();
    } catch (DivisionByZeroError) {
        return 'divisionByZero';
    } catch (ArithmeticError) {
        return 'arithmeticError';
    }
}

function leanList(array $items): Ctor|int
{
    $out = 0;
    foreach (array_reverse($items) as $item) {
        $out = new Ctor(1, [$item, $out]);
    }
    return $out;
}

function compareMask(int|float|bool $a, int|float|bool $b): int
{
    return ($a === $b ? 1 : 0) + ($a < $b ? 2 : 0) + ($a <= $b ? 4 : 0) + ($a > $b ? 8 : 0) + ($a >= $b ? 16 : 0);
}

function integers(int $a, int $b): void
{
    foreach ([
        'add' => [$a + $b, Model::l_Php_add($a, $b)],
        'sub' => [$a - $b, Model::l_Php_sub($a, $b)],
        'mul' => [$a * $b, Model::l_Php_mul($a, $b)],
        'neg' => [-$a, Model::l_Php_neg($a)],
        'abs' => [abs($a), Model::l_Php_abs($a)],
        'intdiv' => [nativeNumber(static fn() => intdiv($a, $b)), Model::l_Php_intdiv($a, $b)],
        'mod' => [nativeNumber(static fn() => $a % $b), Model::l_Php_mod($a, $b)],
    ] as $op => [$native, $model]) {
        requireEqual($op, outcome($model), is_float($native) ? 'overflow' : $native, $a, $b);
    }
    requireEqual('intCompare', Model::l_Semantics_intCompare($a, $b), compareMask($a, $b), $a, $b);
    requireEqual('min', Model::l_Semantics_intMin($a, $b), min($a, $b), $a, $b);
    requireEqual('max', Model::l_Semantics_intMax($a, $b), max($a, $b), $a, $b);
}

function floats(float $a, float $b): void
{
    requireEqual('fdiv', outcome(Model::l_Php_fdiv($a, $b)), nativeNumber(static fn() => $a / $b), $a, $b);
    requireEqual('floatAdd', Model::l_Semantics_floatAdd($a, $b), $a + $b, $a, $b);
    requireEqual('floatSub', Model::l_Semantics_floatSub($a, $b), $a - $b, $a, $b);
    requireEqual('floatMul', Model::l_Semantics_floatMul($a, $b), $a * $b, $a, $b);
    requireEqual('floatNeg', Model::l_Semantics_floatNeg($a), -$a, $a);
    requireEqual('floatAbs', Model::l_Semantics_floatAbs($a), abs($a), $a);
    requireEqual('minFloat', Model::l_Php_minFloat($a, $b), min($a, $b), $a, $b);
    requireEqual('maxFloat', Model::l_Php_maxFloat($a, $b), max($a, $b), $a, $b);
    requireEqual('floatCompare', Model::l_Semantics_floatCompare($a, $b), compareMask($a, $b), $a, $b);
}

function strings(string $a, string $b): void
{
    requireEqual('strlen', Model::l_Php_strlen(new LString($a)), strlen($a), $a);
    requireEqual('concat', Model::l_Php_concat(new LString($a), new LString($b))->s, $a . $b, $a, $b);
    requireEqual(
        'stringEqual',
        Model::l_Semantics_stringEqual(new LString($a), new LString($b)),
        (int) ($a === $b),
        $a,
        $b,
    );
}

function lists(array $items, int $i): void
{
    $warned = false;
    set_error_handler(static function (int $level, string $message) use (&$warned): bool {
        $warned = $level === E_WARNING && str_contains($message, 'Undefined array key');
        return $warned;
    });
    try {
        $native = $items[$i];
    } finally {
        restore_error_handler();
    }
    requireEqual(
        'index',
        outcome(Model::l_Semantics_index(leanList($items), $i)),
        $native === null && $warned ? 'undefinedIndex' : $native,
        $items,
        $i,
    );
    requireEqual('count', Model::l_Semantics_count(leanList($items)), count($items), $items);
}

function other(bool $a, bool $b, ?int $x, int $i): void
{
    requireEqual('boolCompare', Model::l_Semantics_boolCompare((int) $a, (int) $b), compareMask($a, $b), $a, $b);
    requireEqual(
        'nullable',
        Model::l_Semantics_natOption($x === null ? 0 : new Ctor(1, [$x])),
        (int) ($x === null),
        $x,
    );
    try {
        $expected = match ($i) { 1 => 5 };
    } catch (UnhandledMatchError) {
        $expected = 'unhandledMatch';
    }
    requireEqual('matchOne', outcome(Model::l_Semantics_matchOne($i)), $expected, $i);
}

$ints = [PHP_INT_MIN, PHP_INT_MIN + 1, -3037000500, -1, 0, 1, 2, 3037000500, PHP_INT_MAX - 1, PHP_INT_MAX];
foreach ($ints as $a) {
    foreach ($ints as $b) {
        integers($a, $b);
    }
}
$floatValues = [NAN, -INF, -PHP_FLOAT_MAX, -2.0, -PHP_FLOAT_MIN, -0.0, 0.0, PHP_FLOAT_MIN, 2.0, PHP_FLOAT_MAX, INF];
foreach ($floatValues as $a) {
    foreach ($floatValues as $b) {
        floats($a, $b);
    }
}
foreach (['', 'é', '🌱', "A\0猫", "e\u{301}"] as $a) {
    foreach (['', 'é', '🌱', "A\0猫", "e\u{301}"] as $b) {
        strings($a, $b);
    }
}
foreach ([[], [7], [1, 2, 3]] as $items) {
    foreach ([PHP_INT_MIN, -1, 0, 1, 2, 3, PHP_INT_MAX] as $i) {
        lists($items, $i);
    }
}
$random = new Randomizer(new Mt19937(94243));
for ($i = 0; $i < 2048; $i++) {
    $a = $random->getInt(PHP_INT_MIN, PHP_INT_MAX);
    $b = $random->getInt(-1000, 1000);
    integers($a, $b);
    floats($random->getInt(-1000000, 1000000) / 17, $random->getInt(-1000000, 1000000) / 31);
    $prefix = implode('', $random->pickArrayKeys(array_flip(['a', 'z', 'é', '🌱', "\0", '猫']), $random->getInt(1, 6)));
    strings($prefix . $b, ($i % 3) === 0 ? $prefix . $b : $prefix . $a);
    lists(array_slice([$a, $b, $i], 0, $random->getInt(0, 3)), $random->getInt(-3, 4));
    other(($i % 2) === 0, ($i % 3) === 0, ($i % 5) === 0 ? null : $a, $random->getInt(-3, 3));
}
requireEqual('invalid UTF-8 strlen', strlen("\xff"), 1);
requireEqual('invalid UTF-8 equality', "\xff" === "\x80", false);
try {
    new LString("\xff");
    throw new RuntimeException('Lean strings accepted an invalid UTF-8 byte');
} catch (InvalidArgumentException) {
    echo "Invalid UTF-8 is outside the model input contract.\n";
}
echo 'PHP ', PHP_VERSION, ": model operations matched 2048 seeded random inputs per operation plus boundary cases.\n";
