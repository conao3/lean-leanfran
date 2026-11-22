<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Schema;

use function Conao3\Leanfran\Runtime\lean_float_to_string;

/** A finite float in Lean's JSON number format. */
final readonly class JsonFloat
{
    public string $decimal;

    /** Format a finite float using Lean's decimal precision. */
    public function __construct(float $value)
    {
        if (!is_finite($value)) {
            throw new \LogicException('Expected a finite float.');
        }
        $decimal = rtrim(rtrim(lean_float_to_string($value)->s, '0'), '.');
        $this->decimal = $decimal === '-0' ? '0' : $decimal;
    }
}
