<?php

declare(strict_types=1);

namespace App;

use App\Calc\Bounds;
use Conao3\Leanfran\Model as Verified;

final class Ops
{
    /** @param list<int> $xs */
    #[Verified(spec: Calc::class)]
    public static function loops(array $xs, int $n): int
    {
        $sum = 0;
        foreach ($xs as $i => $x) {
            if ($i === 0) {
                continue;
            } elseif ($x < 0) {
                break;
            } else {
                $sum += $x;
            }
        }
        foreach ($xs as $x) {
            if ($x > 4) {
                return $sum;
            }
            $sum -= $x;
        }
        for ($i = 0; $i < $n; $i++) {
            if ($i === 1) {
                continue;
            }
            $sum += $i;
        }
        $i = 0;
        while ($i < 3) {
            $i += 1;
            $sum -= $i;
        }
        return $sum;
    }

    /**
     * @param array{0: int, 1: string} $p
     * @return array{0: int, 1: string}
     */
    #[Verified(spec: Calc::class)]
    public static function product(array $p): array
    {
        [$a, $b] = $p;
        $a *= 2;
        $b .= '🌱';
        return [$a + $p[0], $b . $p[1]];
    }

    #[Verified(spec: Calc::class)]
    public static function integers(int $a, int $b): int
    {
        $x = intdiv($a, $b);
        $y = $a % $b;
        return max(abs(-$x), min($b, $y));
    }

    #[Verified(spec: Calc::class)]
    public static function floats(float $a, float $b): float
    {
        return -(($a + $b) * ($a - $b)) / $b;
    }

    #[Verified(spec: Calc::class)]
    public static function words(string $a, string $b): int
    {
        return $a !== $b ? strlen($a . $b) : 0;
    }

    #[Verified(spec: Calc::class)]
    public static function logic(bool $a, bool $b, ?int $x): bool
    {
        return (!$a || $b) && ($x === null || $a === $b);
    }

    #[Verified(spec: Calc::class)]
    public static function choices(Color $color, int $i): int
    {
        return match ($color) {
            Color::Red => match ($i) {
                1, 2 => 12,
                3 => 10,
            },
            Color::Blue => $i < 1 ? throw new \DomainException('negative') : 5,
        };
    }

    #[Verified(spec: Calc::class)]
    public static function indexing(int $i): int
    {
        $xs = [];
        $xs[] = 2;
        $xs[] = 3;
        $xs[] = 5;
        return $xs[$i] + count($xs);
    }

    #[Verified(spec: Calc::class)]
    public static function early(int $i): int
    {
        if ($i <= 0) {
            throw new \DomainException('negative');
        }
        return $i;
    }

    #[Verified(spec: Calc::class)]
    public static function objects(Box $box, Bounds $bounds): int
    {
        $other = new Box($bounds->lo);
        return $box->value + $other->value;
    }

    #[Verified(spec: Calc::class)]
    public static function standalone(int $value): int
    {
        [$a, $b] = [$value, 1];
        $box = new Plain($a);
        return $box->value + $b;
    }

    #[Verified(spec: Calc::class)]
    public static function generated(int $lo, int $hi): int
    {
        return new Bounds($lo, $hi)->lo;
    }

    #[Verified(spec: Calc::class)]
    public static function calls(int $a): int
    {
        return Calc::add(Calc::clamp($a, 0, 3), 1);
    }

    #[Verified(spec: Calc::class)]
    public static function order(int $a, int $b): bool
    {
        return $a >= $b || $a > 1 && $b <= 0;
    }

    #[Verified(spec: Calc::class)]
    public static function nullable(?int $a): ?int
    {
        return $a !== null ? 3 : null;
    }

    #[Verified(spec: Calc::class)]
    public static function branchLocal(int $x): int
    {
        if ($x < 0) {
            $y = -1;
        } elseif ($x === 0) {
            $y = 0;
        } else {
            $y = 1;
        }
        return $y;
    }

    /** @param int<0, 100> $a */
    #[Verified(spec: Calc::class)]
    public static function countInput(int $a): int
    {
        return $a;
    }
}
