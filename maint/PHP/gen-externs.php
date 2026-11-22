<?php

declare(strict_types=1);

require __DIR__ . '/../../langs/PHP/vendor/autoload.php';

$prefix = 'conao3\\leanfran\\runtime\\';
$libm = [];
foreach ([
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'atan2',
    'sinh',
    'cosh',
    'tanh',
    'asinh',
    'acosh',
    'atanh',
    'exp',
    'exp2',
    'log',
    'log2',
    'log10',
    'pow',
    'sqrt',
    'cbrt',
    'ceil',
    'floor',
    'round',
    'fabs',
    'fmod',
    'fma',
] as $name) {
    $libm[$name] = true;
    $libm[$name . 'f'] = true;
}
$names = [];
foreach (get_defined_functions()['user'] as $function) {
    if (!str_starts_with($function, $prefix)) {
        continue;
    }
    $name = substr(new ReflectionFunction($function)->getName(), strlen($prefix));
    if (str_starts_with($name, 'lean_') || isset($libm[$name])) {
        $names[] = $name;
    }
}
sort($names, SORT_STRING);

echo "namespace LeanPhp\n\ndef runtimeExterns : Array String := #[\n";
foreach ($names as $name) {
    echo '  "', $name, "\",\n";
}
echo "]\n\nend LeanPhp\n";
