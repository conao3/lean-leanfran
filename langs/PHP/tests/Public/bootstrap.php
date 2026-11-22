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
