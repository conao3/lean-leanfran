<?php

declare(strict_types=1);

use Conao3\Leanfran\Runtime\LArray;
use Conao3\Leanfran\Runtime\LByteArray;
use Conao3\Leanfran\Runtime\LString;
use Leanfran\Generated\Complexity;

require 'vendor/autoload.php';
require 'test-out/Complexity.php';

$suffix = new LString('é猫');
Conao3\Leanfran\Runtime\lean_mark_persistent($suffix);

$cases = [
    'Array.push' => [
        Complexity::l_LeanPhpTest_ControlComplexity_arrayPush(...),
        static fn(int $n) => new LArray(),
        static fn(LArray $a, int $n) => count($a->a) === $n && $a->a[0] === $n && $a->a[$n - 1] === 1,
    ],
    'Array.set' => [
        Complexity::l_LeanPhpTest_ControlComplexity_arraySet(...),
        static fn(int $n) => new LArray(array_fill(0, $n, 0)),
        static fn(LArray $a, int $n) => count($a->a) === $n && $a->a[0] === 1 && $a->a[$n - 1] === $n,
    ],
    'String.push' => [
        Complexity::l_LeanPhpTest_ControlComplexity_stringPush(...),
        static fn(int $n) => new LString(''),
        static fn(LString $s, int $n) => $s->s === str_repeat('猫', $n),
    ],
    'String.++' => [
        static fn(int $n, LString $s) => Complexity::l_LeanPhpTest_ControlComplexity_stringAppend($n, $s, $suffix),
        static fn(int $n) => new LString(''),
        static fn(LString $s, int $n) => $s->s === str_repeat('é猫', $n),
    ],
    'ByteArray.push' => [
        Complexity::l_LeanPhpTest_ControlComplexity_bytePush(...),
        static fn(int $n) => new LByteArray(),
        static fn(LByteArray $a, int $n) => $a->b === str_repeat("\xff", $n),
    ],
    'ByteArray.set' => [
        Complexity::l_LeanPhpTest_ControlComplexity_byteSet(...),
        static fn(int $n) => new LByteArray(str_repeat("\0", $n)),
        static fn(LByteArray $a, int $n) => $a->b === str_repeat("\xff", $n),
    ],
];

$n = 30_000;
$failed = false;
foreach ($cases as $name => [$run, $input, $check]) {
    $run(100, $input(100));
    $times = [$n => [], 4 * $n => []];
    for ($i = 0; $i < 3; ++$i) {
        foreach ([$n, 4 * $n] as $size) {
            $startValue = $input($size);
            $start = hrtime(true);
            $result = $run($size, $startValue);
            $times[$size][] = (hrtime(true) - $start) / 1e6;
            if (!$check($result, $size)) {
                throw new RuntimeException("$name returned incorrect contents for $size updates.");
            }
        }
    }
    sort($times[$n]);
    sort($times[4 * $n]);
    $small = $times[$n][1];
    $large = $times[4 * $n][1];
    $ratio = $large / $small;
    printf("%s n=%d %.3f ms, 4n=%d %.3f ms, ratio %.2f\n", $name, $n, $small, 4 * $n, $large, $ratio);
    if ($ratio >= 8) {
        fwrite(STDERR, "$name exceeded the complexity limit (ratio < 8).\n");
        $failed = true;
    }
}
exit((int) $failed);
