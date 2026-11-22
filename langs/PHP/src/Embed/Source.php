<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

/** Lean text and the location of its literal in PHP. */
final readonly class Source
{
    public string $text;

    /** @param non-empty-list<string> $lines Raw lines of the source literal. */
    public function __construct(
        private array $lines,
        public int $line,
        public int $column,
        public string $indent,
        private bool $quoted,
    ) {
        $this->text = $quoted
            ? self::singleQuoted(implode("\n", $lines))
            : implode("\n", array_map(fn(string $raw): string => substr($raw, $this->indentLength($raw)), $lines));
    }

    /** Decodes the two escape sequences recognized by single-quoted PHP strings. */
    public static function singleQuoted(string $text): string
    {
        return strtr($text, ["\\\\" => "\\", "\\'" => "'"]);
    }

    /** Counts Unicode code points in a source column. */
    public static function length(string $text): int
    {
        $count = preg_match_all('/./us', $text);
        return $count === false ? strlen($text) : $count;
    }

    /**
     * Maps a one-based Lean line and a zero-based Lean column.
     *
     * @return array{int, int}
     */
    public function position(int $line, int $column): array
    {
        $last = count($this->lines);
        $raw = $this->lines[min($last, $line) - 1];
        $base = $line === 1 ? $this->column : 1;
        if ($line > $last) {
            return [$this->line + $last - 1, ($last === 1 && $this->quoted ? $this->column : 1) + self::length($raw)];
        }
        if ($this->quoted) {
            if (preg_match_all("~\\\\[\\\\']|.~us", $raw, $matches) !== false) {
                $column = self::length(implode('', array_slice($matches[0], 0, $column)));
            }
        } else {
            $base = $this->indentLength($raw) + 1;
        }
        return [$this->line + $line - 1, $base + $column];
    }

    private function indentLength(string $line): int
    {
        return min(strlen($this->indent), strspn($line, " \t"));
    }
}
