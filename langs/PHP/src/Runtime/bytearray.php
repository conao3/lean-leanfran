<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_byte_array_copy_slice(
    LByteArray $src,
    int|\GMP $srcOff,
    LByteArray $dest,
    int|\GMP $destOff,
    int|\GMP $length,
    int $exact,
): LByteArray {
    $srcSize = strlen($src->b);
    if (!is_int($srcOff) || $srcOff > $srcSize) {
        return $dest;
    }
    $available = $srcSize - $srcOff;
    $count = is_int($length) ? min($length, $available) : $available;
    $destSize = strlen($dest->b);
    $offset = is_int($destOff) ? min($destOff, $destSize) : $destSize;
    $chunk = substr($src->b, $srcOff, $count);
    $dest = exclusiveBytes($dest);
    if ($offset === $destSize) {
        $dest->b .= $chunk;
    } else {
        $dest->b = substr_replace($dest->b, $chunk, $offset, $count);
    }
    return $dest;
}

function lean_byte_array_hash(LByteArray $bytes): int
{
    return hashRuntimeBytes($bytes->b);
}
