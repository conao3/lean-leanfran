<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

/**
 * A successful Lean Except result.
 * @template-covariant A
 * @implements Except<never, A>
 */
final readonly class Ok implements Except
{
    /** @param A $value */
    public function __construct(
        public mixed $value,
    ) {}
}
