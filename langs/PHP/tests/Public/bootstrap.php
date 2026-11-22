<?php

declare(strict_types=1);

require_once __DIR__ . '/../../vendor/autoload.php';

spl_autoload_register(static function (string $class): void {
    foreach ([
        'App\\Lean\\Pricing\\' => 'pricing',
        'App\\Lean\\Json\\' => 'json',
        'App\\Lean\\Names\\' => 'names',
        'App\\Lean\\External\\' => 'external',
    ] as $prefix => $dir) {
        if (str_starts_with($class, $prefix)) {
            $path =
                __DIR__
                . '/../../test-out/public/'
                . $dir
                . '/'
                . str_replace('\\', '/', substr($class, strlen($prefix)))
                . '.php';
            if (is_file($path)) {
                require $path;
            }
            return;
        }
    }
});

/** @return array{files: list<string>, skipped: list<array{name: string, reason: string}>} */
function publicSummary(string $fixture): array
{
    $source = file_get_contents(__DIR__ . '/../../test-out/public/' . $fixture . '.json');
    if ($source === false) {
        throw new RuntimeException('Could not read the generation summary for ' . $fixture);
    }
    $summary = json_decode($source, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($summary) || !is_array($summary['files'] ?? null) || !is_array($summary['skipped'] ?? null)) {
        throw new RuntimeException('Expected files and skipped definitions in the generation summary.');
    }
    $files = [];
    foreach ($summary['files'] as $file) {
        if (!is_string($file)) {
            throw new RuntimeException('Expected a file path in the generation summary.');
        }
        $files[] = $file;
    }
    $skipped = [];
    foreach ($summary['skipped'] as $definition) {
        if (
            !is_array($definition)
            || !is_string($definition['name'] ?? null)
            || !is_string($definition['reason'] ?? null)
        ) {
            throw new RuntimeException('Expected a definition name and reason in the generation summary.');
        }
        $skipped[] = ['name' => $definition['name'], 'reason' => $definition['reason']];
    }
    return ['files' => $files, 'skipped' => $skipped];
}
