<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

use Attribute;

/** Declares a Lean source block on a PHP class. */
#[Attribute(Attribute::TARGET_CLASS)]
final readonly class Lean
{
    public const GENERATOR_VERSION = '6';

    /**
     * @param list<string> $imports
     * @param list<string> $uses
     * @param list<string> $models
     */
    public function __construct(
        public string $source,
        public array $imports = [],
        public array $uses = [],
        public array $models = [],
    ) {}
}
