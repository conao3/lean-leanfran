<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_apply(LClosure $f, array $args): mixed
{
    return lean_trampoline(applyStep($f, $args));
}

function applyStep(LClosure $f, array $args): LClosure|TailCall
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
        $arity = $f->arity;
        lean_dec($f);
        if (count($args) < $need) {
            return new LClosure($fn, $arity, [...$fixed, ...$args]);
        }
        if (count($args) === $need) {
            return new TailCall($fn, [...$fixed, ...$args]);
        }
        $f = lean_trampoline($fn(...$fixed, ...array_slice($args, 0, $need)));
        if (!$f instanceof LClosure) {
            throw new \TypeError('Oversaturated Lean application did not return a closure.');
        }
        $args = array_slice($args, $need);
    }
}
