<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

/** A Lean definition and its callable signature. */
final readonly class Translated
{
    /**
     * @param array<string, Type> $parameters
     * @param list<string> $dependencies
     */
    public function __construct(
        public Declaration $model,
        public array $parameters,
        public Type $result,
        public bool $fails,
        public string $source,
        public array $dependencies,
    ) {}
}
