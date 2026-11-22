<?php

declare(strict_types=1);

use Random\Engine\Mt19937;
use Random\Randomizer;

if ($argc !== 3) {
    fwrite(STDERR, "Usage: fuzz-gen.php SEED COUNT\n");
    exit(2);
}

$seed = filter_var($argv[1], FILTER_VALIDATE_INT, ['options' => ['min_range' => 0, 'max_range' => 0xffffffff]]);
$count = filter_var($argv[2], FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
if ($seed === false || $count === false) {
    fwrite(STDERR, "Expected a seed in 0..4294967295 and a nonnegative count.\n");
    exit(2);
}

$edges = [
    ['NAT', '0', '0'],
    ['NAT', '1', '2'],
    ['NAT', '9223372036854775807', '1'],
    ['NAT', '9223372036854775808', '9223372036854775809'],
    ['NAT', '18446744073709551616', '18446744073709551615'],
    ['NAT', '123456789012345678901234567890', '18446744073709551616'],
    ['INT', '0', '0'],
    ['INT', '-7', '2'],
    ['INT', '7', '-2'],
    ['INT', '-7', '-2'],
    ['INT', '-9223372036854775808', '-1'],
    ['INT', '-9223372036854775809', '9223372036854775808'],
    ['U64', '0', '0'],
    ['U64', '18446744073709551615', '1'],
    ['U64', '18446744073709551615', '9223372036854775808'],
    ['U64', '9223372036854775808', '63'],
    ['U64', '9223372036854775808', '64'],
    ['U64', '4611686293305294849', '9223372036854775807'],
    ['STR', '', ''],
    ['STR', 'é', '猫'],
    ['STR', 'a ', ''],
    ['STR', '🍣', 'é'],
    ['STR', '\\$', '𐀀'],
    ['ARR'],
    ['ARR', '0'],
    ['ARR', '1', '9223372036854775808', '18446744073709551616'],
];
foreach ($edges as $row) {
    echo implode("\t", $row), "\n";
}

$random = new Randomizer(new Mt19937($seed));
$nat = static fn(int $bytes): string => gmp_strval(gmp_import($random->getBytes($bytes)));
$signed = static fn(int $bytes): string => ($random->getInt(0, 1) === 0 ? '' : '-') . $nat($bytes);
$alphabet = ['a', 'Z', '$', '\\', ' ', 'é', '́', '猫', '🌱', '𐀀', '𐌀'];
$string = static function () use ($random, $alphabet): string {
    $size = $random->getInt(0, 16);
    $value = '';
    for ($i = 0; $i < $size; ++$i) {
        $value .= $alphabet[$random->getInt(0, count($alphabet) - 1)];
    }
    return $value;
};
$array = static function () use ($random, $nat): array {
    $size = $random->getInt(0, 16);
    $row = ['ARR'];
    for ($i = 0; $i < $size; ++$i) {
        $row[] = $nat($random->getInt(1, 12));
    }
    return $row;
};

for ($i = 0; $i < $count; ++$i) {
    $row = match ($random->getInt(0, 4)) {
        0 => ['NAT', $nat($random->getInt(1, 16)), $nat($random->getInt(1, 16))],
        1 => ['INT', $signed($random->getInt(1, 16)), $signed($random->getInt(1, 16))],
        2 => ['U64', $nat(8), $random->getInt(0, 1) === 0 ? $nat(8) : $random->getInt(0, 128)],
        3 => ['STR', $string(), $string()],
        4 => $array(),
    };
    echo implode("\t", $row), "\n";
}
