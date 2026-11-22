<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Closure;
use RuntimeException;

/** A type in the PHPDoc subset supported by embedded models. */
final readonly class PhpDocType
{
    /** @param list<self> $args */
    public function __construct(
        public string $kind,
        public array $args = [],
        public ?int $lower = null,
        public ?int $upper = null,
    ) {}

    /** @param Closure(string): string $resolve */
    public static function parse(string $text, Closure $resolve, bool $description = false): self
    {
        $offset = 0;
        $type = self::type($text, $offset, $resolve);
        $rest = substr($text, $offset);
        if (trim($rest) !== '' && (!$description || !preg_match('/^\s+[\p{L}0-9]/u', $rest))) {
            throw new RuntimeException('unsupported PHPDoc type ' . trim($text));
        }
        return $type;
    }

    /** Returns the compatible native type, without nullability. */
    public function native(): string
    {
        return match ($this->kind) {
            'list', 'non-empty-list', 'pair' => 'array',
            'non-empty-string' => 'string',
            'option' => $this->args[0]->native(),
            default => ltrim($this->kind, '\\'),
        };
    }

    /** Returns the Lean type of a model field. */
    public function lean(): string
    {
        return match ($this->kind) {
            'int' => $this->nat() ? 'Nat' : 'Int',
            'float' => 'Float',
            'string', 'non-empty-string' => 'String',
            'bool' => 'Bool',
            'list', 'non-empty-list' => '(List ' . $this->args[0]->lean() . ')',
            'option' => '(Option ' . $this->args[0]->lean() . ')',
            'pair' => '(' . $this->args[0]->lean() . ' × ' . $this->args[1]->lean() . ')',
            default => '_root_.' . Models::name(ltrim($this->kind, '\\')),
        };
    }

    /** @return list<string> */
    public function classes(): array
    {
        if (str_starts_with($this->kind, '\\')) {
            return [substr($this->kind, 1)];
        }
        return array_merge([], ...array_map(static fn(self $type): array => $type->classes(), $this->args));
    }

    /** @return array<string, string> */
    public function proofs(string $value, int $depth = 0): array
    {
        $var = "v$depth";
        return match ($this->kind) {
            'int' => $this->integerProofs($value),
            'non-empty-string' => ['min_length' => "1 ≤ (String.length $value)"],
            'list', 'non-empty-list' => [
                ...($this->kind === 'non-empty-list' ? ['min_items' => "1 ≤ (List.length $value)"] : []),
                ...$this->allProofs($this->args[0], $value, $var, 'items_', $depth),
            ],
            'option' => $this->allProofs($this->args[0], $value, $var, '', $depth),
            'pair' => [
                ...self::prefix($this->args[0]->proofs("($value).1", $depth), 'first_'),
                ...self::prefix($this->args[1]->proofs("($value).2", $depth), 'second_'),
            ],
            default => [],
        };
    }

    private function nat(): bool
    {
        return $this->lower !== null && $this->lower >= 0;
    }

    /** @return array<string, string> */
    private function integerProofs(string $value): array
    {
        $proofs = [];
        if ($this->lower !== null && $this->lower !== 0) {
            $proofs['ge'] = "($this->lower) ≤ $value";
        }
        if ($this->upper !== null) {
            $proofs['le'] = "$value ≤ ($this->upper)";
        }
        return $proofs;
    }

    /** @return array<string, string> */
    private function allProofs(self $inner, string $value, string $var, string $prefix, int $depth): array
    {
        return self::prefix(
            array_map(
                static fn(string $proof): string => "(($value).all (fun $var => decide ($proof))) = true",
                $inner->proofs($var, $depth + 1),
            ),
            $prefix,
        );
    }

    /** @param array<string, string> $proofs
     * @return array<string, string>
     */
    private static function prefix(array $proofs, string $prefix): array
    {
        $out = [];
        foreach ($proofs as $name => $proof) {
            $out[$prefix . $name] = $proof;
        }
        return $out;
    }

    /** @param Closure(string): string $resolve */
    private static function type(string $text, int &$offset, Closure $resolve): self
    {
        $nullable = self::take($text, $offset, '?');
        $name = self::token($text, $offset, <<<'REGEX'
            ~\G\s*(\\?[a-zA-Z_\x80-\xff][a-zA-Z_0-9\x80-\xff]*(?:\\[a-zA-Z_\x80-\xff][a-zA-Z_0-9\x80-\xff]*|-[a-z]+)*)~
            REGEX);
        $type = match ($name) {
            'int' => self::range($text, $offset),
            'positive-int' => new self('int', lower: 1),
            'non-negative-int' => new self('int', lower: 0),
            'negative-int' => new self('int', upper: -1),
            'string', 'non-empty-string', 'float', 'bool' => new self($name),
            'list', 'non-empty-list' => self::sequence($name, $text, $offset, $resolve),
            'array' => self::pair($text, $offset, $resolve),
            'mixed',
            'null',
            'void',
            'never',
            'object',
            'resource',
            'callable',
            'iterable',
            'true',
            'false',
                => self::unsupported($text),
            default => str_contains($name, '-') ? self::unsupported($text) : new self('\\' . $resolve($name)),
        };
        if (self::take($text, $offset, '|')) {
            self::expect($text, $offset, 'null');
            if ($nullable || preg_match('/\G[\w\\\\-]/', $text, $unused, 0, $offset)) {
                self::unsupported($text);
            }
            $nullable = true;
        }
        return $nullable ? new self('option', [$type]) : $type;
    }

    private static function range(string $text, int &$offset): self
    {
        if (!self::take($text, $offset, '<')) {
            return new self('int');
        }
        $lower = self::limit($text, $offset, 'min');
        self::expect($text, $offset, ',');
        $upper = self::limit($text, $offset, 'max');
        self::expect($text, $offset, '>');
        if ($lower !== null && $upper !== null && $lower > $upper) {
            self::unsupported($text);
        }
        return new self('int', lower: $lower, upper: $upper);
    }

    private static function limit(string $text, int &$offset, string $unbounded): ?int
    {
        if (self::take($text, $offset, $unbounded)) {
            return null;
        }
        $literal = self::token($text, $offset, '/\G\s*(-?(?:0|[1-9][0-9]*))/');
        $value = (int) $literal;
        if ((string) $value !== $literal && $literal !== '-0') {
            self::unsupported($text);
        }
        return $value;
    }

    /** @param Closure(string): string $resolve */
    private static function sequence(string $name, string $text, int &$offset, Closure $resolve): self
    {
        self::expect($text, $offset, '<');
        $inner = self::type($text, $offset, $resolve);
        self::expect($text, $offset, '>');
        return new self($name, [$inner]);
    }

    /** @param Closure(string): string $resolve */
    private static function pair(string $text, int &$offset, Closure $resolve): self
    {
        foreach (['{', '0', ':'] as $part) {
            self::expect($text, $offset, $part);
        }
        $first = self::type($text, $offset, $resolve);
        foreach ([',', '1', ':'] as $part) {
            self::expect($text, $offset, $part);
        }
        $second = self::type($text, $offset, $resolve);
        self::take($text, $offset, ',');
        self::expect($text, $offset, '}');
        return new self('pair', [$first, $second]);
    }

    private static function take(string $text, int &$offset, string $token): bool
    {
        $start = $offset + strspn($text, " \t\r\n", $offset);
        if (substr($text, $start, strlen($token)) !== $token) {
            return false;
        }
        $offset = $start + strlen($token);
        return true;
    }

    private static function expect(string $text, int &$offset, string $token): void
    {
        if (!self::take($text, $offset, $token)) {
            self::unsupported($text);
        }
    }

    private static function token(string $text, int &$offset, string $pattern): string
    {
        if (!preg_match($pattern, $text, $match, 0, $offset)) {
            self::unsupported($text);
        }
        $offset += strlen($match[0]);
        return $match[1];
    }

    private static function unsupported(string $text): never
    {
        throw new RuntimeException('unsupported PHPDoc type ' . trim($text));
    }
}
