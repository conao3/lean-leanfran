<?php

declare(strict_types=1);

$report = json_decode(stream_get_contents(STDIN), true, flags: JSON_THROW_ON_ERROR);
$expected = [
    11 => 'expects int<0, 255>',
    12 => 'expects list<App\\Lean\\Pricing\\Range>',
    13 => 'expects non-empty-string',
    14 => 'expects array{string, bool}',
    15 => 'expects Conao3\\Leanfran\\Except<string,',
];
$files = $report['files'];
if ($report['errors'] !== [] || count($files) !== 1 || count(current($files)['messages']) !== count($expected)) {
    throw new RuntimeException('Unexpected PHPStan diagnostics: ' . json_encode($report, JSON_THROW_ON_ERROR));
}
foreach (current($files)['messages'] as $error) {
    $line = $error['line'];
    if (
        !isset($expected[$line])
        || $error['identifier'] !== 'argument.type'
        || !str_contains($error['message'], $expected[$line])
    ) {
        throw new RuntimeException('Unexpected PHPStan diagnostic: ' . $error['message']);
    }
    echo $error['message'], PHP_EOL;
    unset($expected[$line]);
}
