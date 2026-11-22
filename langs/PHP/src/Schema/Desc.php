<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Schema;

/** Describes the public and Lean runtime representations of a value. */
final readonly class Desc
{
    /**
     * @param class-string|null $cls
     * @param list<LeanVariant> $variants
     * @param list<string> $cases
     * @param array<string, string> $bounds
     * @param (\Closure(): self)|null $get
     */
    public function __construct(
        public string $kind,
        public string $name = '',
        public ?string $cls = null,
        public ?self $a = null,
        public ?self $b = null,
        public int $bits = 0,
        public string $bound = '0',
        public array $variants = [],
        public array $cases = [],
        public ?int $trivial = null,
        public array $bounds = [],
        public ?\Closure $get = null,
    ) {}

    /** Resolve a reference to its descriptor. */
    public function resolve(): self
    {
        return $this->kind === 'ref'
            ? ($this->get ?? throw new \LogicException('Missing descriptor reference.'))()->resolve()
            : $this;
    }

    /** Return the first component descriptor. */
    public function first(): self
    {
        return $this->a ?? throw new \LogicException('Missing component descriptor.');
    }

    /** Return the second component descriptor. */
    public function second(): self
    {
        return $this->b ?? throw new \LogicException('Missing component descriptor.');
    }
}
