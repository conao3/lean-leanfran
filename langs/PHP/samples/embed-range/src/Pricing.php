<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;

#[Lean(<<<'LEAN'
    structure Range where
      lo : Nat
      hi : Nat
      ok : lo ≤ hi

    def width (r : Range) : Nat := r.hi - r.lo

    theorem width_le (r : Range) : width r ≤ r.hi := by
      unfold width
      omega
    LEAN)]
final class Pricing
{
    use Pricing\Functions;
}
