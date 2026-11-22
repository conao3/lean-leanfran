<?php

declare(strict_types=1);

namespace App\Input;

final readonly class Detail
{
    public function __construct(
        public bool $active,
        public float $weight,
    ) {}
}
