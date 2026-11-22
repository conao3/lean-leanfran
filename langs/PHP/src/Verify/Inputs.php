<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Marshal;
use Conao3\Leanfran\Schema\Desc;
use Random\Engine\Mt19937;
use Random\Randomizer;

use function Conao3\Leanfran\Runtime\utf8Scalar;

/** Generates reproducible inputs for the supported PHP value shapes. */
final readonly class Inputs
{
    private const INTS = [0, 1, -1, PHP_INT_MAX, PHP_INT_MIN, PHP_INT_MAX - 1, PHP_INT_MIN + 1];
    private const FLOATS = [0.0, 1.0, -1.0, PHP_FLOAT_MAX, -PHP_FLOAT_MAX, PHP_FLOAT_MIN, -0.0];
    private const STRINGS = ['', 'a', 'é', '♥', "\0", '🙂', 'éa'];

    private Randomizer $random;

    /** Seeds the random engine without changing PHP's global random state. */
    public function __construct(
        private Objects $objects,
        int $seed,
    ) {
        $this->random = new Randomizer(new Mt19937($seed));
    }

    /**
     * Visits joint boundaries and single-argument boundaries before sampling randomly.
     *
     * @param list<Type> $types
     * @return list<mixed>
     */
    public function candidate(array $types, int $attempt): array
    {
        $count = count(self::INTS);
        $axis = intdiv(max(0, $attempt - $count), $count - 1);
        $input = [];
        foreach ($types as $i => $type) {
            $edge = match (true) {
                $attempt < $count => $attempt,
                $axis >= count($types) => null,
                $axis === $i => 1 + (($attempt - $count) % ($count - 1)),
                default => 0,
            };
            $input[] = $this->value($type, $edge, 0);
        }
        return $input;
    }

    private function value(Type $type, ?int $edge, int $depth): mixed
    {
        return match ($type->kind) {
            'int' => $this->integer($edge),
            'nat' => max(0, $this->integer($edge)),
            'bool' => (($edge ?? $this->random->getInt(0, 1)) % 2) === 1,
            'float' => $this->float($edge),
            'string' => $edge === null ? $this->string() : self::STRINGS[$edge],
            'option' => $depth >= 5 || ($edge ?? $this->random->getInt(0, 3)) === 0
                ? null
                : $this->value($type->at(0), $edge, $depth + 1),
            'pair' => [
                $this->value($type->at(0), $edge, $depth + 1),
                $this->value($type->at(1), $edge, $depth + 1),
            ],
            'list' => $this->list($type->at(0), $edge, $depth),
            'enum' => $this->enum($type, $edge),
            'object' => $this->object($type, $edge, $depth),
            default => throw new \LogicException("No input generator for $type->kind"),
        };
    }

    private function integer(?int $edge): int
    {
        if ($edge !== null) {
            return self::INTS[$edge];
        }
        return match ($this->random->getInt(0, 5)) {
            0 => $this->random->getInt(PHP_INT_MIN, PHP_INT_MAX),
            1 => self::INTS[$this->random->getInt(0, count(self::INTS) - 1)],
            2 => $this->random->getInt(-8, 8),
            default => $this->random->getInt(-1000, 1000),
        };
    }

    private function string(): string
    {
        $text = '';
        $length = $this->random->getInt(0, 8);
        for ($i = 0; $i < $length; $i++) {
            $cp = $this->random->getInt(0, 1) === 0
                ? $this->random->getInt(0, 127)
                : $this->random->getInt(0, 0x10FFFF - 0x800);
            $text .= utf8Scalar($cp < 0xD800 ? $cp : $cp + 0x800);
        }
        return $text;
    }

    private function float(?int $edge): float
    {
        if ($edge !== null) {
            return self::FLOATS[$edge];
        }
        return $this->random->getInt(0, 1) === 0
            ? $this->random->getFloat(-1000.0, 1000.0)
            : $this->random->getFloat(-1.0, 1.0) * (2.0 ** $this->random->getInt(-1074, 1023));
    }

    /** @return list<mixed> */
    private function list(Type $item, ?int $edge, int $depth): array
    {
        $length = match (true) {
            $depth >= 5, $edge === 0 => 0,
            $edge === null => $this->random->getInt(0, 8),
            default => 1,
        };
        $list = [];
        for ($i = 0; $i < $length; $i++) {
            $list[] = $this->value($item, $edge, $depth + 1);
        }
        return $list;
    }

    private function enum(Type $type, ?int $edge): \BackedEnum
    {
        $class = $this->objects->phpClass($type);
        if (!is_subclass_of($class, \BackedEnum::class)) {
            throw new \LogicException("Expected a backed enum for $type->name");
        }
        $cases = $class::cases();
        $size = count($cases);
        if ($size === 0) {
            throw new \LogicException("Cannot generate an input for the empty enum $type->name");
        }
        return $cases[($edge ?? $this->random->getInt(0, $size - 1)) % $size];
    }

    private function object(Type $type, ?int $edge, int $depth): object
    {
        $class = $this->objects->phpClass($type);
        $desc = $this->objects->publicDescriptor($type);
        if ($desc !== null) {
            return Marshal::fromData($desc, $class, $this->publicFields($type, $desc, $edge, $depth));
        }
        $values = [];
        foreach ($this->objects->fields($type) as $key => $field) {
            $values[$key] = $this->value($field, $edge, $depth + 1);
        }
        return new $class(...$values);
    }

    /** @return array<string, mixed> */
    private function publicFields(Type $type, Desc $desc, ?int $edge, int $depth): array
    {
        $fields = $this->objects->fields($type);
        $values = [];
        foreach ($desc->variants[0]['fields'] ?? [] as $field) {
            $key = $field['key'];
            $shape = $fields[$key];
            if ($field['flat']) {
                $values += $this->publicFields($shape, $field['desc']->resolve(), $edge, $depth + 1);
            } else {
                $values[$key] = $this->value($shape, $edge, $depth + 1);
            }
        }
        return $values;
    }
}
