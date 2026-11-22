<?php

declare(strict_types=1);

$backend = __DIR__ . '/../../langs/PHP';
$publicFixtures = [];
$internals = [];
foreach (['pricing', 'json', 'names', 'skipped', 'external'] as $fixture) {
    $directory = $backend . '/test-out/public/' . $fixture;
    $files = glob($directory . '/*.php', GLOB_ERR);
    if (!$files) {
        throw new RuntimeException('Missing generated PHPStan fixture: ' . $fixture);
    }
    array_push($publicFixtures, ...$files);
    $internals[] = $directory . '/Internal';
}

$sample = $backend . '/samples/pricing';
$publicSample = glob($sample . '/src/_lean/*.php', GLOB_ERR);
if (!$publicSample) {
    throw new RuntimeException('Missing generated pricing sample.');
}

return [
    'parameters' => [
        'paths' => [
            $backend . '/src',
            ...$publicFixtures,
            $backend . '/tests/Public',
            ...$publicSample,
            $sample . '/main.php',
        ],
        'scanFiles' => $publicFixtures,
        'scanDirectories' => [...$internals, $sample . '/src/_lean/Internal'],
    ],
];
