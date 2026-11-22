<?php

declare(strict_types=1);

namespace App\Input;

enum Code: int
{
    case Standard = 10;
    case Special = 42;
}
