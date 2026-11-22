<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use PhpToken;
use RuntimeException;

/** A cursor over PHP tokens with trivia removed. */
final class Tokens
{
    /** @param list<PhpToken> $tokens */
    public function __construct(
        private readonly array $tokens,
        private readonly PhpToken $end,
        private int $index = 0,
    ) {}

    /** Returns the current token or the end marker. */
    public function peek(int $offset = 0): PhpToken
    {
        return $this->tokens[$this->index + $offset] ?? $this->end;
    }

    /** Advances the cursor. */
    public function take(): PhpToken
    {
        $token = $this->peek();
        if ($token === $this->end) {
            throw new RuntimeException('Unexpected end of PHP tokens.');
        }
        $this->index++;
        return $token;
    }

    /** Consumes a token if it matches. */
    public function skip(int|string $kind): bool
    {
        if (!$this->peek()->is($kind)) {
            return false;
        }
        $this->take();
        return true;
    }

    /**
     * Splits a delimited list at its top-level commas.
     *
     * @return list<self>
     */
    public function items(string $end): array
    {
        $items = [];
        $tokens = [];
        $stack = [];
        while (true) {
            $token = $this->peek();
            if ($stack === [] && $token->is([ord($end), ord(',')])) {
                if ($tokens !== []) {
                    $items[] = new self($tokens, new PhpToken(0, '', $token->line, $token->pos));
                    $tokens = [];
                }
                if ($this->take()->is(ord($end))) {
                    return $items;
                }
                continue;
            }
            $tokens[] = $this->take();
            $close = match ($token->id) {
                T_ATTRIBUTE, ord('[') => ord(']'),
                T_CURLY_OPEN, T_DOLLAR_OPEN_CURLY_BRACES, ord('{') => ord('}'),
                ord('(') => ord(')'),
                default => null,
            };
            if ($close !== null) {
                $stack[] = $close;
            } elseif ($token->is(end($stack) ?: 0)) {
                array_pop($stack);
            }
        }
    }
}
