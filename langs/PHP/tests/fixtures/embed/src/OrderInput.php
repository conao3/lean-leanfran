<?php

declare(strict_types=1);

namespace App;

use App\Input\Code;
use App\Input\Color as Shade;
use App\Input\Detail;

final readonly class OrderInput
{
    /**
     * @param int<0, 100> $percent
     * @param non-negative-int $remaining
     * @param negative-int $debt
     * @param int<min, -2> $delta
     * @param list<Shade> $colors
     * @param non-empty-list<positive-int> $items
     * @param array{0: int<-10, 10>, 1: Code} $pair
     * @param ?non-empty-string $note
     * @param Detail|null $detail
     * @param int<2, max> $units
     */
    public function __construct(
        public int $percent,
        /** @var positive-int */
        public int $count,
        public int $remaining,
        public int $debt,
        public int $delta,
        /** @var non-empty-string */
        public string $label,
        public array $colors,
        public array $items,
        public array $pair,
        public ?string $note,
        public ?Detail $detail,
        public int $units,
        public int $class,
    ) {}
}
