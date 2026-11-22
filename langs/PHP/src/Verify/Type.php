<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\PhpDocType;

/** The native shape of a verified PHP value. */
final readonly class Type
{
    /** @param list<self> $args */
    public function __construct(
        public string $kind,
        public array $args = [],
        public string $name = '',
    ) {}

    /** Returns the Lean type without PHPDoc refinements. */
    public function lean(): string
    {
        return match ($this->kind) {
            'int' => 'Int',
            'nat' => 'Nat',
            'float' => 'Float',
            'bool' => 'Bool',
            'string' => 'String',
            'option' => '(Option ' . $this->at(0)->lean() . ')',
            'list' => '(List ' . $this->at(0)->lean() . ')',
            'pair' => '(' . $this->at(0)->lean() . ' × ' . $this->at(1)->lean() . ')',
            'object', 'enum' => '_root_.' . $this->name,
            default => throw new \LogicException("No Lean type for $this->kind"),
        };
    }

    /** Returns an element type. */
    public function at(int $index): self
    {
        return $this->args[$index] ?? throw new \LogicException("Missing component $index of $this->kind");
    }

    /** Derives the type expected by the native PHP declaration. */
    public function native(): string
    {
        return match ($this->kind) {
            'pair', 'list' => 'array',
            'option' => '?' . $this->at(0)->native(),
            default => $this->kind,
        };
    }

    /** Erases bounds and length refinements from a PHPDoc type. */
    public static function doc(PhpDocType $type, Objects $objects): self
    {
        if (str_starts_with($type->kind, '\\')) {
            return $objects->type(substr($type->kind, 1));
        }
        $shape = $type->shape();
        return new self($shape->kind, array_map(static fn(PhpDocType $arg): self => self::doc(
            $arg,
            $objects,
        ), $shape->args));
    }
}
