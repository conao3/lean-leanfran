<?php

declare(strict_types=1);

namespace App\Input;

use App\Input\Color as Shade;

abstract readonly class DetailFields
{
    /** @param list<Shade> $colors */
    public function __construct(
        public bool $active,
        public float $weight,
        public array $colors,
    ) {}
}
