<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Throwable;

/** A sampled counterexample with the values needed to reproduce it. */
final class PropertyFailure extends \RuntimeException
{
    /** @param list<mixed> $input */
    public function __construct(
        public readonly string $function,
        public readonly string $label,
        public readonly int $seed,
        public readonly array $input,
        public readonly mixed $actual,
        public readonly mixed $expected,
        ?Throwable $cause = null,
        public readonly ?bool $predicate = null,
    ) {
        $args = implode(', ', array_map(self::display(...), $input));
        $result = $cause === null
            ? 'returned ' . self::display($actual)
            : 'threw ' . $cause::class . ': ' . $cause->getMessage();
        $spec = $predicate === null ? 'expected ' . self::display($expected) : 'returned false, expected true';
        parent::__construct(
            "$function [$label] failed (seed=$seed, input=[$args]): implementation $result; spec $spec",
            previous: $cause,
        );
    }

    private static function display(mixed $value): string
    {
        return match (true) {
            is_string($value) => json_encode(
                $value,
                JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE,
            ),
            $value instanceof \GMP => gmp_strval($value),
            default => var_export($value, true),
        };
    }
}
