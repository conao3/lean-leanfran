<?php

declare(strict_types=1);

namespace App;

final readonly class Box
{
    public function __construct(
        public int $value,
    ) {}
}
