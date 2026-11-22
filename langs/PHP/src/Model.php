<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

use Attribute;

/**
 * Connects a function to an embedded Lean specification.
 * Verified inputs use valid UTF-8 and the list and tuple shapes declared in PHPDoc.
 */
#[Attribute(Attribute::TARGET_FUNCTION | Attribute::TARGET_METHOD)]
final readonly class Model
{
    /** @param array<string, string> $ensures */
    public function __construct(
        public ?string $refines = null,
        public ?string $requires = null,
        public array $ensures = [],
        public ?string $spec = null,
    ) {}
}
