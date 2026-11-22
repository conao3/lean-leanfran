<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

abstract class LeanObject
{
    public int $rc = 1;
}

final class Ctor extends LeanObject
{
    public function __construct(
        public int $tag,
        public array $objs,
        public array $sc = [],
    ) {}
}

final class LArray extends LeanObject
{
    public function __construct(
        public array $a = [],
    ) {}
}

final class LByteArray extends LeanObject
{
    public function __construct(
        public string $b = '',
    ) {}
}

final class LFloatArray extends LeanObject
{
    public function __construct(
        public array $a = [],
    ) {}
}

final class LString extends LeanObject
{
    public function __construct(
        public string $s,
    ) {
        if (preg_match('//u', $s) !== 1) {
            throw new \InvalidArgumentException('Expected a valid UTF-8 string.');
        }
    }
}

final class LClosure extends LeanObject
{
    public function __construct(
        public \Closure $fn,
        public int $arity,
        public array $fixed = [],
    ) {}
}

final readonly class TailCall
{
    public function __construct(
        public \Closure $fn,
        public array $args,
    ) {}
}

final readonly class TailApply
{
    public function __construct(
        public LClosure $closure,
        public array $args,
    ) {}
}

function lean_trampoline(mixed $result): mixed
{
    while ($result instanceof TailCall || $result instanceof TailApply) {
        $result = $result instanceof TailCall
            ? ($result->fn)(...$result->args)
            : applyStep($result->closure, $result->args);
    }
    return $result;
}

final class LThunk extends LeanObject
{
    public function __construct(
        public ?LClosure $fn,
        public mixed $value = 0,
    ) {}
}

final class LRef extends LeanObject
{
    public function __construct(
        public mixed $value,
    ) {}
}

function lean_inc(mixed $x): void
{
    lean_inc_n($x, 1);
}

function lean_inc_n(mixed $x, int $n): void
{
    if ($x instanceof LeanObject && $x->rc > 0) {
        $x->rc += $n;
    }
}

function lean_inc_ret(mixed $x): mixed
{
    lean_inc($x);
    return $x;
}

function objectChildren(LeanObject $x): array
{
    return match (true) {
        $x instanceof Ctor => $x->objs,
        $x instanceof LArray => $x->a,
        $x instanceof LClosure => $x->fixed,
        $x instanceof LThunk => [$x->fn ?? $x->value],
        $x instanceof LRef => [$x->value],
        default => [],
    };
}

function lean_dec(mixed $x): void
{
    if (!$x instanceof LeanObject || $x->rc <= 0 || --$x->rc !== 0) {
        return;
    }
    $stack = [$x];
    while ($stack !== []) {
        $obj = array_pop($stack);
        $children = objectChildren($obj);
        match (true) {
            $obj instanceof Ctor => $obj->objs = [],
            $obj instanceof LArray => $obj->a = [],
            $obj instanceof LClosure => $obj->fixed = [],
            $obj instanceof LThunk => [$obj->fn, $obj->value] = [null, 0],
            $obj instanceof LRef => $obj->value = 0,
            default => null,
        };
        foreach ($children as $child) {
            if ($child instanceof LeanObject && $child->rc > 0 && --$child->rc === 0) {
                $stack[] = $child;
            }
        }
    }
}

function lean_mark_persistent(mixed $x): mixed
{
    $stack = [$x];
    while ($stack !== []) {
        $obj = array_pop($stack);
        if ($obj instanceof LeanObject && $obj->rc > 0) {
            $obj->rc = -1;
            foreach (objectChildren($obj) as $child) {
                $stack[] = $child;
            }
        }
    }
    return $x;
}

function lean_is_exclusive(mixed $x): bool
{
    return $x instanceof LeanObject && $x->rc === 1;
}

function lean_is_shared(mixed $x): int
{
    return (int) !lean_is_exclusive($x);
}

function lean_reset(mixed $x, int $n): Ctor|int
{
    if (!$x instanceof Ctor || !lean_is_exclusive($x)) {
        lean_dec($x);
        return 0;
    }
    for ($i = 0; $i < $n; ++$i) {
        lean_dec($x->objs[$i]);
        $x->objs[$i] = 0;
    }
    return $x;
}

function lean_reuse(Ctor|int $x, int $tag, bool $update, array $objs): Ctor
{
    if (is_int($x)) {
        return new Ctor($tag, $objs);
    }
    $x->objs = $objs;
    if ($update) {
        $x->tag = $tag;
    }
    return $x;
}

function lean_obj_tag(Ctor|int $x): int
{
    return is_int($x) ? $x : $x->tag;
}

function lean_ctor_get(Ctor $x, int $i): mixed
{
    return $x->objs[$i];
}

function lean_ctor_set(Ctor $x, int $i, mixed $v): void
{
    $x->objs[$i] = $v;
}

function lean_ctor_set_tag(Ctor $x, int $tag): void
{
    $x->tag = $tag;
}

function lean_ctor_get_usize(Ctor $x, int $i): int
{
    return $x->sc[8 * $i];
}

function lean_ctor_set_usize(Ctor $x, int $i, int $v): void
{
    $x->sc[8 * $i] = $v;
}

function lean_ctor_get_uint8(Ctor $x, int $offset): int
{
    return $x->sc[$offset];
}

function lean_ctor_set_uint8(Ctor $x, int $offset, int $v): void
{
    $x->sc[$offset] = $v;
}

function lean_ctor_get_uint16(Ctor $x, int $offset): int
{
    return $x->sc[$offset];
}

function lean_ctor_set_uint16(Ctor $x, int $offset, int $v): void
{
    $x->sc[$offset] = $v;
}

function lean_ctor_get_uint32(Ctor $x, int $offset): int
{
    return $x->sc[$offset];
}

function lean_ctor_set_uint32(Ctor $x, int $offset, int $v): void
{
    $x->sc[$offset] = $v;
}

function lean_ctor_get_uint64(Ctor $x, int $offset): int
{
    return $x->sc[$offset];
}

function lean_ctor_set_uint64(Ctor $x, int $offset, int $v): void
{
    $x->sc[$offset] = $v;
}

function lean_ctor_get_float(Ctor $x, int $offset): float
{
    return $x->sc[$offset];
}

function lean_ctor_set_float(Ctor $x, int $offset, float $v): void
{
    $x->sc[$offset] = $v;
}

function lean_ctor_get_float32(Ctor $x, int $offset): float
{
    return $x->sc[$offset];
}

function lean_ctor_set_float32(Ctor $x, int $offset, float $v): void
{
    $x->sc[$offset] = $v;
}
