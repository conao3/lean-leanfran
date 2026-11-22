<?php

declare(strict_types=1);

$root = __DIR__ . '/../..';
require $root . '/langs/PHP/vendor/autoload.php';

function readExternRoster(string $path): array
{
    $data = $path === '-' ? stream_get_contents(STDIN) : @file_get_contents($path);
    if ($data === false || !preg_match_all('/^  "([^"]+)",?$/m', $data, $matches)) {
        fwrite(STDERR, 'Could not read the extern roster at ' . $path . "\n");
        exit(2);
    }
    $names = array_unique($matches[1]);
    sort($names, SORT_STRING);
    return $names;
}

if ($argc > 2) {
    fwrite(STDERR, "Usage: php extern-gap.php [baseline RuntimeExterns.lean or - for stdin]\n");
    exit(2);
}

$python = readExternRoster($root . '/langs/Python/LeanPython/RuntimeExterns.lean');
$baseline = readExternRoster($argv[1] ?? $root . '/langs/PHP/LeanPhp/RuntimeExterns.lean');
$gap = array_diff($python, $baseline);
$excluded = [];
$required = array_diff($python, array_keys($excluded));
$missing = array_values(array_filter(
    $required,
    static fn(string $name): bool => !function_exists('Conao3\\Leanfran\\Runtime\\' . $name),
));
$implement = array_diff($gap, array_keys($excluded));
$omit = array_intersect_key($excluded, array_flip($gap));

echo 'Implement (', count($implement), ")\n";
foreach ($implement as $name) {
    echo $name, in_array($name, $missing, true) ? ' (missing)' : '', "\n";
}
echo 'Do not implement (', count($omit), ")\n";
foreach ($omit as $name => $reason) {
    echo $name, ' (', $reason, ")\n";
}
if ($missing !== []) {
    fwrite(STDERR, 'Missing PHP externs: ' . implode(', ', $missing) . "\n");
    exit(1);
}
echo 'PHP runtime definitions verified: ', count($required), "\n";
