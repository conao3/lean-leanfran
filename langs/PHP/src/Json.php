<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

use Conao3\Leanfran\Schema\JsonFloat;

/** Reads and writes JSON with arbitrary precision integers. */
final class Json
{
    /** Decode JSON, preserving integers outside PHP's native range. */
    public static function decode(string $json): mixed
    {
        $decoded = json_decode($json, flags: JSON_BIGINT_AS_STRING | JSON_THROW_ON_ERROR);
        if (preg_match('/-?[0-9]{19}/', $json) !== 1) {
            return $decoded;
        }

        $tokens = preg_match_all(
            '/"(?:[^"\\\\]++|\\\\.)*+"|[{}\[\],:]|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null/',
            $json,
            $matches,
        );
        if ($tokens === false) {
            throw new \JsonException('Could not scan JSON tokens.');
        }
        $values = new \ArrayIterator($matches[0]);
        return self::read($values);
    }

    /** @param \ArrayIterator<int, string> $tokens */
    private static function read(\ArrayIterator $tokens): mixed
    {
        $token = $tokens->current();
        $tokens->next();
        if ($token === '[') {
            $list = [];
            while ($tokens->current() !== ']') {
                $list[] = self::read($tokens);
                if ($tokens->current() === ',') {
                    $tokens->next();
                }
            }
            $tokens->next();
            return $list;
        }
        if ($token === '{') {
            $object = new \stdClass();
            while ($tokens->current() !== '}') {
                $key = json_decode($tokens->current(), flags: JSON_THROW_ON_ERROR);
                if (!is_string($key)) {
                    throw new \JsonException('Expected a JSON object key.');
                }
                $tokens->next();
                $tokens->next();
                $object->{$key} = self::read($tokens);
                if ($tokens->current() === ',') {
                    $tokens->next();
                }
            }
            $tokens->next();
            return $object;
        }
        $value = json_decode($token, flags: JSON_BIGINT_AS_STRING | JSON_THROW_ON_ERROR);
        return is_string($value) && $token[0] !== '"' ? gmp_init($value, 10) : $value;
    }

    /** Encode a JSON value, emitting GMP as a number. */
    public static function encode(mixed $value): string
    {
        if ($value instanceof \GMP) {
            return gmp_strval($value);
        }
        if ($value instanceof JsonFloat) {
            return $value->decimal;
        }
        if (is_array($value) && array_is_list($value)) {
            return '[' . implode(',', array_map(self::encode(...), $value)) . ']';
        }
        if (is_array($value) || $value instanceof \stdClass) {
            $fields = [];
            foreach ((array) $value as $key => $field) {
                $fields[] = self::encode((string) $key) . ':' . self::encode($field);
            }
            return '{' . implode(',', $fields) . '}';
        }
        return json_encode($value, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    /** Return a JSON value for PHP's native encoder. */
    public static function native(mixed $value): mixed
    {
        if ($value instanceof \GMP) {
            return gmp_strval($value);
        }
        if ($value instanceof JsonFloat) {
            return (float) $value->decimal;
        }
        if ($value instanceof \stdClass) {
            return (object) array_map(self::native(...), get_object_vars($value));
        }
        return is_array($value) ? array_map(self::native(...), $value) : $value;
    }
}
