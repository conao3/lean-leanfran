<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

/** A translated expression and its PHP value shape. */
final readonly class Value
{
    /** Associates a Lean term with its checked PHP type. */
    public function __construct(
        public string $code,
        public Type $type,
        public bool $effect = false,
    ) {}
}
