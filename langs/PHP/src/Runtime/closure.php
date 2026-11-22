<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_apply(LClosure $f, array $args): mixed
{
    while (true) {
        $fixed = $f->fixed;
        $need = $f->arity - count($fixed);
        if ($need <= 0) {
            throw new \LogicException('Invalid Lean closure arity.');
        }
        foreach ($fixed as $arg) {
            lean_inc($arg);
        }
        $fn = $f->fn;
        lean_dec($f);
        if (count($args) < $need) {
            return new LClosure($fn, $f->arity, [...$fixed, ...$args]);
        }
        if (count($args) === $need) {
            return $fn(...$fixed, ...$args);
        }
        $f = $fn(...$fixed, ...array_slice($args, 0, $need));
        if (!$f instanceof LClosure) {
            throw new \TypeError('Oversaturated Lean application did not return a closure.');
        }
        $args = array_slice($args, $need);
    }
}
