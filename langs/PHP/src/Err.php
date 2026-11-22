<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

/**
 * A failed Lean Except result.
 * @template-covariant E
 * @implements Except<E, never>
 */
final readonly class Err implements Except
{
    /** @param E $error */
    public function __construct(
        public mixed $error,
    ) {}
}
