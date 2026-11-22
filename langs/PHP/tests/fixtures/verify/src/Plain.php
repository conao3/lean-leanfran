<?php

declare(strict_types=1);

namespace App;

final readonly class Plain
{
    /** @param int<0, 100> $value */
    public function __construct(
        public int $value,
    ) {}
}
