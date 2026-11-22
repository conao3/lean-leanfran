<?php

declare(strict_types=1);

namespace App;

final readonly class LineItem
{
    /**
     * @param non-empty-string $sku
     * @param positive-int $quantity
     * @param non-negative-int $unitPrice
     */
    public function __construct(
        public string $sku,
        public int $quantity,
        public int $unitPrice,
    ) {}
}
