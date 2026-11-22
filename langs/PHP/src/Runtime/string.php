<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_mk_string(string $s): LString
{
    return new LString($s);
}

function utf8Scalar(int $c): string
{
    if ($c < 0 || $c > 0x10ffff || $c >= 0xd800 && $c <= 0xdfff) {
        throw new \InvalidArgumentException("Invalid Unicode scalar $c.");
    }
    return match (true) {
        $c < 0x80 => chr($c),
        $c < 0x800 => chr(0xc0 | ($c >> 6)) . chr(0x80 | ($c & 63)),
        $c < 0x10000 => chr(0xe0 | ($c >> 12)) . chr(0x80 | (($c >> 6) & 63)) . chr(0x80 | ($c & 63)),
        default => chr(0xf0 | ($c >> 18))
            . chr(0x80 | (($c >> 12) & 63))
            . chr(0x80 | (($c >> 6) & 63))
            . chr(0x80 | ($c & 63)),
    };
}

function utf8Width(int $first): int
{
    return match (true) {
        $first >= 0xf0 => 4,
        $first >= 0xe0 => 3,
        $first >= 0xc0 => 2,
        default => 1,
    };
}

function utf8Decode(string $s, int $i): int
{
    $first = ord($s[$i]);
    $width = utf8Width($first);
    if ($width === 1) {
        return $first;
    }
    $value = $first & (0x7f >> $width);
    for ($j = 1; $j < $width; ++$j) {
        $value = ($value << 6) | (ord($s[$i + $j]) & 63);
    }
    return $value;
}

function exclusiveString(LString $s): LString
{
    if (lean_is_exclusive($s)) {
        return $s;
    }
    $copy = clone $s;
    $copy->rc = 1;
    lean_dec($s);
    return $copy;
}

function lean_string_append(LString $a, LString $b): LString
{
    $a = exclusiveString($a);
    $a->s .= $b->s;
    return $a;
}

function lean_string_push(LString $s, int $c): LString
{
    $s = exclusiveString($s);
    $s->s .= utf8Scalar($c);
    return $s;
}

function lean_string_length(LString $s): int
{
    $size = preg_match_all('/./us', $s->s);
    if ($size === false) {
        throw new \LogicException('Lean string contains invalid UTF-8.');
    }
    return $size;
}

function lean_string_utf8_byte_size(LString $s): int
{
    return strlen($s->s);
}

function lean_string_mk(Ctor|int $cs): LString
{
    $s = new LString('');
    for ($node = $cs; $node instanceof Ctor; $node = $node->objs[1]) {
        $s->s .= utf8Scalar(requireRuntimeInt($node->objs[0]));
    }
    lean_dec($cs);
    return $s;
}

function lean_string_data(LString $s): Ctor|int
{
    $result = 0;
    for ($i = strlen($s->s); $i > 0;) {
        $i = previousUtf8Offset($s, $i);
        $result = new Ctor(1, [utf8Decode($s->s, $i), $result]);
    }
    lean_dec($s);
    return $result;
}

function lean_string_dec_eq(LString $a, LString $b): int
{
    return (int) ($a->s === $b->s);
}

function lean_string_dec_lt(LString $a, LString $b): int
{
    return (int) (strcmp($a->s, $b->s) < 0);
}

function lean_string_compare(LString $a, LString $b): int
{
    return (strcmp($a->s, $b->s) <=> 0) + 1;
}

function lean_string_is_valid_pos(LString $s, int|\GMP $i): int
{
    return (int) (
        is_int($i)
        && $i >= 0
        && $i <= strlen($s->s)
        && ($i === strlen($s->s) || (ord($s->s[$i]) & 0xc0) !== 0x80)
    );
}

function lean_string_utf8_at_end(LString $s, int|\GMP $i): int
{
    return (int) (indexInBounds($i, strlen($s->s)) === null);
}

function utf8OffsetInBounds(LString $s, int|\GMP $i): ?int
{
    $index = indexInBounds($i, strlen($s->s));
    return $index !== null && lean_string_is_valid_pos($s, $index) ? $index : null;
}

function lean_string_utf8_get(LString $s, int|\GMP $i): int
{
    $index = utf8OffsetInBounds($s, $i);
    return $index === null ? 65 : utf8Decode($s->s, $index);
}

function lean_string_utf8_get_fast(LString $s, int $i): int
{
    return lean_string_utf8_get($s, $i);
}

function lean_string_utf8_get_opt(LString $s, int|\GMP $i): Ctor|int
{
    $index = utf8OffsetInBounds($s, $i);
    return $index === null ? 0 : new Ctor(1, [utf8Decode($s->s, $index)]);
}

function lean_string_utf8_get_bang(LString $s, int|\GMP $i): int
{
    $index = utf8OffsetInBounds($s, $i);
    if ($index === null) {
        return lean_panic_fn(65, new LString('Error: invalid `String.Pos` at `String.get!`'));
    }
    return utf8Decode($s->s, $index);
}

function lean_string_uget_byte_fast(LString $s, int $i): int
{
    $size = strlen($s->s);
    checkIndex($i, $size + 1);
    return $i === $size ? 0 : ord($s->s[$i]);
}

function lean_string_get_byte_fast(LString $s, int $i): int
{
    return lean_string_uget_byte_fast($s, $i);
}

function lean_string_utf8_next(LString $s, int|\GMP $i): int|\GMP
{
    $index = indexInBounds($i, strlen($s->s));
    if ($index === null) {
        return lean_nat_add($i, 1);
    }
    return $index + utf8Width(ord($s->s[$index]));
}

function lean_string_utf8_next_fast(LString $s, int $i): int
{
    return $i + utf8Width(lean_string_get_byte_fast($s, $i));
}

function lean_string_utf8_prev(LString $s, int|\GMP $i): int|\GMP
{
    if (!is_int($i) || $i > strlen($s->s)) {
        return lean_nat_sub($i, 1);
    }
    return previousUtf8Offset($s, $i);
}

function previousUtf8Offset(LString $s, int $i): int
{
    while ($i > 0 && !lean_string_is_valid_pos($s, --$i)) {
    }
    return $i;
}

function lean_string_utf8_extract(LString $s, int|\GMP $begin, int|\GMP $end): LString
{
    $start = utf8OffsetInBounds($s, $begin);
    if ($start === null) {
        return new LString('');
    }
    $end = is_int($end) ? min($end, strlen($s->s)) : strlen($s->s);
    if ($end <= $start) {
        return new LString('');
    }
    if (!lean_string_is_valid_pos($s, $end)) {
        $end = strlen($s->s);
    }
    return new LString(substr($s->s, $start, $end - $start));
}

function lean_string_utf8_extract_fast(LString $s, int $begin, int $end): LString
{
    return new LString($end <= $begin ? '' : substr($s->s, $begin, $end - $begin));
}

function lean_string_utf8_set(LString $s, int|\GMP $i, int $c): LString
{
    $index = utf8OffsetInBounds($s, $i);
    if ($index === null) {
        return $s;
    }
    $s = exclusiveString($s);
    $value = utf8Scalar($c);
    $width = utf8Width(ord($s->s[$index]));
    if ($width === 1 && strlen($value) === 1) {
        $s->s[$index] = $value;
    } else {
        $s->s = substr_replace($s->s, $value, $index, $width);
    }
    return $s;
}

function lean_string_to_utf8(LString $s): LByteArray
{
    return new LByteArray($s->s);
}

function lean_string_validate_utf8(LByteArray $bytes): int
{
    return (int) (preg_match('//u', $bytes->b) === 1);
}

function lean_string_from_utf8_unchecked(LByteArray $bytes): LString
{
    $s = new LString($bytes->b);
    lean_dec($bytes);
    return $s;
}

function lean_string_of_usize(int $v): LString
{
    return new LString(sprintf('%u', $v));
}
