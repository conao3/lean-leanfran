<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

use Attribute;

/** Declares a Lean source block on a PHP class. */
#[Attribute(Attribute::TARGET_CLASS)]
final readonly class Lean
{
    public const VERSION = '0.14.0';
    public const GENERATOR_VERSION = '7';
    public const LEAN_VERSION = '4.35.0';

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
