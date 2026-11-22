<?php

declare(strict_types=1);

use Leanfran\Generated\LeanLeanPhpTest_Vectors as Vectors;

require 'test-out/Vectors.php';

switch ($argv[1]) {
    case 'twice':
        $status = Vectors::runMain(['first']);
        exit($status === 0 ? Vectors::runMain(['second']) : $status);
    case 'invalid-tag':
        Vectors::l_LeanPhpTest_ControlIr_showLabel(255);
        break;
    case 'unreachable':
        Vectors::l_LeanPhpTest_ControlIr_impossible(0);
        break;
    default:
        throw new InvalidArgumentException("Unknown control test: $argv[1]");
}
