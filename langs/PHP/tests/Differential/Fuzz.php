<?php

declare(strict_types=1);

use Conao3\Leanfran\Runtime as L;
use Leanfran\Generated\Fuzz;

require 'vendor/autoload.php';
require $argv[1];

$number = 0;
while (($line = fgets(STDIN)) !== false) {
    ++$number;
    $row = str_ends_with($line, "\n") ? substr($line, 0, -1) : $line;
    $result = Fuzz::l_LeanPhpTest_Fuzz_evalRow(new L\LString($row));
    if (!$result instanceof L\Ctor || $result->tag !== 1) {
        fwrite(STDERR, "Invalid fuzz input on line $number: $row\n");
        exit(1);
    }
    echo $result->objs[0]->s, "\n";
    L\lean_dec($result);
}
if (!feof(STDIN)) {
    throw new RuntimeException('Could not read fuzz input.');
}
