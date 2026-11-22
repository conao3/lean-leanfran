<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

use Conao3\Leanfran\Runtime as L;
use Conao3\Leanfran\Runtime\Ctor;
use Conao3\Leanfran\Runtime\LArray;
use Conao3\Leanfran\Runtime\LString;
use Conao3\Leanfran\Schema\Desc;
use Conao3\Leanfran\Schema\JsonFloat;

/** Converts public PHP values, JSON data, and Lean runtime values. */
final class Marshal
{
    /** @return RuntimeValue */
    public static function toLean(Desc $desc, mixed $value, string $name): mixed
    {
        try {
            return self::encode($desc, self::normalize($desc, $value, false));
        } catch (ValidationError $e) {
            throw self::prefix($e, [$name]);
        }
    }

    /** @param list<array{Desc, mixed, string}> $arguments
     * @return list<RuntimeValue>
     */
    public static function arguments(array $arguments): array
    {
        $issues = [];
        $result = [];
        foreach ($arguments as [$desc, $value, $name]) {
            try {
                $result[] = self::toLean($desc, $value, $name);
            } catch (ValidationError $e) {
                array_push($issues, ...$e->issues);
            }
        }
        self::finish($issues);
        return $result;
    }

    /** Validate and normalize a PHP value. */
    public static function validate(Desc $desc, mixed $value): mixed
    {
        $result = self::normalize($desc, $value, false);
        self::encode($desc, $result);
        return $result;
    }

    /** Create a PHP value from its array or scalar data. */
    public static function fromArray(Desc $desc, mixed $data): mixed
    {
        return self::normalize($desc, $data, true);
    }

    /** @param array<string, mixed> $values
     * @return array<string, mixed>
     */
    public static function construct(Desc $desc, string $class, array $values): array
    {
        $desc = $desc->resolve();
        $variant = self::variantForClass($desc, $class);
        $fields = self::readFields($variant, $values, 'properties');
        self::check($desc, $variant, $fields);
        return self::properties($variant, $fields);
    }

    /**
     * @template T of object
     * @param class-string<T> $class
     * @return T
     */
    public static function fromData(Desc $desc, string $class, mixed $data, bool $json = false): object
    {
        if ($json) {
            if (!is_string($data)) {
                throw new \LogicException('Expected a JSON string.');
            }
            try {
                $data = Json::decode($data);
            } catch (\JsonException $e) {
                self::fail($e->getMessage());
            }
        } elseif ($desc->kind === 'subtype' && is_array($data) && array_keys($data) === ['val']) {
            $data = $data['val'];
        } elseif (
            in_array($desc->kind, ['enum', 'inductive'], true)
            && is_array($data)
            && array_keys($data) === [0]
            && is_string($data[0])
        ) {
            $data = $data[0];
        }
        $value = self::fromArray($desc, $data);
        if (!$value instanceof $class) {
            self::fail('Expected ' . $class . '.');
        }
        return $value;
    }

    /** @return array<mixed> */
    public static function toArray(Desc $desc, mixed $value): array
    {
        $value = self::arrayValue(self::jsonValue($desc, $value));
        if ($desc->kind === 'subtype') {
            return ['val' => $value];
        }
        return is_array($value) ? $value : [$value];
    }

    private static function arrayValue(mixed $value): mixed
    {
        if ($value instanceof JsonFloat) {
            return (float) $value->decimal;
        }
        if ($value instanceof \stdClass) {
            $value = get_object_vars($value);
        }
        return is_array($value) ? array_map(self::arrayValue(...), $value) : $value;
    }

    /** Return the JSON representation with arbitrary precision numbers. */
    public static function jsonValue(Desc $desc, mixed $value): mixed
    {
        $d = $desc->resolve();
        switch ($d->kind) {
            case 'uint':
            case 'usize':
                return $d->bits === 64 ? gmp_strval(self::integer($d, $value)) : $value;
            case 'float':
            case 'float32':
                $f = L\requireRuntimeFloat($value);
                return match (true) {
                    is_nan($f) => 'NaN',
                    $f === INF => 'Infinity',
                    $f === -INF => '-Infinity',
                    default => new JsonFloat($f),
                };
            case 'unit':
                return new \stdClass();
            case 'option':
                return $value === null ? null : self::jsonValue($d->first(), $value);
            case 'array':
            case 'list':
                return array_map(fn(mixed $x): mixed => self::jsonValue($d->first(), $x), self::list($value));
            case 'prod':
                [$a, $b] = self::tuple($value, 2);
                return [self::jsonValue($d->first(), $a), self::jsonValue($d->second(), $b)];
            case 'except':
                if ($value instanceof Ok) {
                    return (object) ['ok' => self::jsonValue($d->second(), $value->value)];
                }
                if ($value instanceof Err) {
                    return (object) ['error' => self::jsonValue($d->first(), $value->error)];
                }
                self::fail('Expected Ok or Err.');
            case 'enum':
                $case = self::enumValue($d, $value);
                return $d->enumByName ? $case->name : $case->value;
            case 'model':
            case 'struct':
            case 'inductive':
            case 'subtype':
                if ($d->kind === 'subtype' && $d->cls === null) {
                    return self::jsonValue($d->first(), $value);
                }
                $v = self::variantForValue($d, $value);
                $fields = self::readFields($v, get_object_vars($value), 'properties');
                $payload = [];
                foreach ($v['fields'] as $i => $f) {
                    $x = $fields[$i];
                    if ($f['omitNone'] && $x === null) {
                        continue;
                    }
                    $j = self::jsonValue($f['desc'], $x);
                    if ($f['flat']) {
                        $payload += self::record($j);
                    } elseif ($v['positional']) {
                        $payload[] = $j;
                    } else {
                        $payload[$f['key']] = $j;
                    }
                }
                return match (true) {
                    $d->kind === 'subtype' => $payload['val'],
                    in_array($d->kind, ['struct', 'model'], true) => (object) $payload,
                    $v['fields'] === [] => $v['name'],
                    $v['positional'] => (object) [$v['name'] => count($payload) === 1 ? $payload[0] : $payload],
                    default => (object) [$v['name'] => (object) $payload],
                };
            default:
                return $value;
        }
    }

    /** Convert the result of a Lean IO function or throw its error. */
    public static function ioResult(Desc $desc, mixed $result): mixed
    {
        $result = L\requireRuntimeObject($result, Ctor::class);
        if (L\lean_io_result_is_error($result)) {
            $error = self::tagged(L\lean_io_result_get_error($result));
            throw new LeanIOError(L\ioErrorMessage($error), L\lean_obj_tag($error));
        }
        return self::fromLean($desc, L\lean_io_result_get_value($result));
    }

    /** Convert a Lean runtime value into its public PHP form. */
    public static function fromLean(Desc $desc, mixed $value): mixed
    {
        $d = $desc->resolve();
        return match ($d->kind) {
            'nat', 'int', 'fin' => self::integer($d, $value),
            'uint', 'usize' => $d->bits === 64
                ? L\lean_uint64_to_nat(L\requireRuntimeInt($value))
                : L\requireRuntimeInt($value),
            'sint', 'isize' => L\numericSignExtend(L\requireRuntimeInt($value), $d->bits),
            'float', 'float32' => L\requireRuntimeFloat($value),
            'bool' => L\requireRuntimeInt($value) !== 0,
            'char' => L\utf8Scalar(L\requireRuntimeInt($value)),
            'string' => L\requireRuntimeObject($value, LString::class)->s,
            'unit' => null,
            'array' => array_map(fn(mixed $x): mixed => self::fromLean(
                $d->first(),
                $x,
            ), array_values(L\requireRuntimeObject($value, LArray::class)->a)),
            'list' => self::fromList($d->first(), $value),
            'option' => $value === 0
                ? null
                : self::fromLean($d->first(), L\lean_ctor_get(L\requireRuntimeObject($value, Ctor::class), 0)),
            'prod' => [
                self::fromLean($d->first(), self::get($value, 0)),
                self::fromLean($d->second(), self::get($value, 1)),
            ],
            'except' => L\lean_obj_tag(self::tagged($value)) === 0
                ? new Err(self::fromLean($d->first(), self::get($value, 0)))
                : new Ok(self::fromLean($d->second(), self::get($value, 0))),
            'enum' => self::enumValue($d, $d->cases[L\requireRuntimeInt($value)], true),
            'struct', 'model', 'inductive', 'subtype' => self::fromVariant($d, $value),
            default => throw new \LogicException('Unknown descriptor: ' . $d->kind),
        };
    }

    /** @param LeanPath $path */
    private static function prefix(ValidationError $e, array $path): ValidationError
    {
        return new ValidationError(array_map(static fn(array $issue): array => [
            'message' => $issue['message'],
            'path' => [...$path, ...$issue['path']],
        ], $e->issues));
    }

    /** @param LeanPath $path */
    private static function fail(string $message, array $path = []): never
    {
        throw new ValidationError([['message' => $message, 'path' => $path]]);
    }

    /** @param list<LeanIssue> $issues */
    private static function finish(array $issues): void
    {
        if ($issues !== []) {
            throw new ValidationError($issues);
        }
    }

    private static function integer(Desc $d, mixed $value): int|\GMP
    {
        if ($d->phpInt && !is_int($value)) {
            self::fail('Expected a PHP integer.');
        }
        if (is_string($value) && preg_match('/^-?[0-9]+$/D', $value) === 1) {
            $value = gmp_init($value, 10);
        }
        if (!is_int($value) && !$value instanceof \GMP) {
            self::fail('Expected an integer.');
        }
        $value = L\numericNormalize($value);
        if (in_array($d->kind, ['nat', 'uint', 'usize', 'fin'], true) && gmp_sign($value) < 0) {
            self::fail('Expected a non-negative integer.');
        }
        if ($d->kind === 'fin' && gmp_cmp($value, $d->bound) >= 0) {
            self::fail('Expected an integer less than ' . $d->bound . '.');
        }
        if ($d->kind === 'uint' || $d->kind === 'usize') {
            if (gmp_cmp($value, gmp_init(1) << $d->bits) >= 0) {
                self::fail('Expected an unsigned ' . $d->bits . '-bit integer.');
            }
        }
        if ($d->kind === 'sint' || $d->kind === 'isize') {
            $limit = gmp_init(1) << ($d->bits - 1);
            if (gmp_cmp($value, -$limit) < 0 || gmp_cmp($value, $limit) >= 0) {
                self::fail('Expected a signed ' . $d->bits . '-bit integer.');
            }
        }
        return $value;
    }

    private static function float(Desc $d, mixed $value, bool $data): float
    {
        if ($data && $value instanceof \GMP) {
            $value = (float) gmp_strval($value);
        }
        if ($data && is_string($value)) {
            $value = match ($value) {
                'NaN' => NAN,
                'Infinity' => INF,
                '-Infinity' => -INF,
                default => $value,
            };
        }
        if (!is_float($value) && !is_int($value)) {
            self::fail('Expected a number.');
        }
        return $d->kind === 'float32' ? L\lean_float_to_float32($value) : (float) $value;
    }

    private static function string(mixed $value, bool $char): string
    {
        if (!is_string($value) || preg_match($char ? '/^.$/usD' : '//u', $value) !== 1) {
            self::fail($char ? 'Expected one Unicode scalar.' : 'Expected a valid UTF-8 string.');
        }
        return $value;
    }

    /** @return list<mixed> */
    private static function list(mixed $value): array
    {
        if (!is_array($value) || !array_is_list($value)) {
            self::fail('Expected a list.');
        }
        return $value;
    }

    /** @return list<mixed> */
    private static function tuple(mixed $value, int $length): array
    {
        $items = self::list($value);
        if (count($items) !== $length) {
            self::fail('Expected a list of ' . $length . ' elements.');
        }
        return $items;
    }

    /** @return array<int|string, mixed> */
    private static function record(mixed $value): array
    {
        if ($value instanceof \stdClass) {
            return get_object_vars($value);
        }
        if (!is_array($value) || $value !== [] && array_is_list($value)) {
            self::fail('Expected an object.');
        }
        return $value;
    }

    private static function enumValue(Desc $d, mixed $value, bool $data = false): \BackedEnum
    {
        $cls = $d->cls ?? throw new \LogicException('Missing enum class.');
        if ($value instanceof \BackedEnum && $value instanceof $cls) {
            return $value;
        }
        if ($data && is_string($value) && is_subclass_of($cls, \BackedEnum::class)) {
            if ($d->enumByName) {
                if (in_array($value, $d->cases, true)) {
                    $case = constant($cls . '::' . $value);
                    if ($case instanceof \BackedEnum && $case instanceof $cls) {
                        return $case;
                    }
                }
            } else {
                $case = $cls::tryFrom($value);
                if ($case !== null) {
                    return $case;
                }
            }
        }
        self::fail('Expected ' . $d->name . '.');
    }

    private static function normalize(Desc $desc, mixed $value, bool $data): mixed
    {
        $d = $desc->resolve();
        return match ($d->kind) {
            'nat', 'int', 'fin', 'uint', 'sint', 'usize', 'isize' => self::integer($d, $value),
            'float', 'float32' => self::float($d, $value, $data),
            'bool' => is_bool($value) ? $value : self::fail('Expected a boolean.'),
            'string', 'char' => self::string($value, $d->kind === 'char'),
            'unit' => $value === null
                || $data && ($value === [] || $value instanceof \stdClass && get_object_vars($value) === [])
                    ? null
                    : self::fail('Expected Unit.'),
            'option' => $value === null ? null : self::normalize($d->first(), $value, $data),
            'array', 'list' => self::normalizeList($d, self::list($value), $data),
            'prod' => self::normalizeList($d, self::tuple($value, 2), $data),
            'except' => self::normalizeExcept($d, $value, $data),
            'enum' => self::enumValue($d, $value, $data),
            'subtype', 'struct', 'model', 'inductive' => self::normalizeVariant($d, $value, $data),
            default => throw new \LogicException('Unknown descriptor: ' . $d->kind),
        };
    }

    /** @param list<mixed> $items
     * @return list<mixed>
     */
    private static function normalizeList(Desc $d, array $items, bool $data): array
    {
        $issues = [];
        $out = [];
        foreach ($items as $i => $value) {
            try {
                $out[] = self::normalize($d->kind === 'prod' && $i === 1 ? $d->second() : $d->first(), $value, $data);
            } catch (ValidationError $e) {
                array_push($issues, ...self::prefix($e, [$i])->issues);
            }
        }
        self::finish($issues);
        return $out;
    }

    /** @return Except<mixed, mixed> */
    private static function normalizeExcept(Desc $d, mixed $value, bool $data): Except
    {
        $shape = match (true) {
            $value instanceof Ok => ['ok' => $value->value],
            $value instanceof Err => ['error' => $value->error],
            $data => self::record($value),
            default => self::fail('Expected Ok or Err.'),
        };
        if (count($shape) !== 1) {
            self::fail('Expected exactly one of ok and error.');
        }
        $tag = array_key_first($shape);
        try {
            return match ($tag) {
                'ok' => new Ok(self::normalize($d->second(), $shape[$tag], $data)),
                'error' => new Err(self::normalize($d->first(), $shape[$tag], $data)),
                default => self::fail('Expected ok or error.'),
            };
        } catch (ValidationError $e) {
            throw self::prefix($e, [$tag]);
        }
    }

    private static function normalizeVariant(Desc $d, mixed $value, bool $data): mixed
    {
        if ($d->kind === 'subtype' && $d->cls === null) {
            $v = $d->variants[0];
            $value = self::normalize($d->first(), $value, $data);
            self::check($d, $v, [$value]);
            return $value;
        }
        foreach ($d->variants as $v) {
            $cls = $v['cls'];
            if ($cls !== null && $value instanceof $cls) {
                return $value;
            }
        }
        if (!$data) {
            self::fail('Expected ' . $d->name . '.');
        }
        if ($d->kind === 'subtype') {
            $v = $d->variants[0];
            $values = [self::normalize($d->first(), $value, true)];
        } elseif (in_array($d->kind, ['struct', 'model'], true)) {
            $v = $d->variants[0];
            $values = self::readFields($v, self::record($value), 'data');
        } else {
            [$v, $payload] = self::pick($d, $value);
            if ($v['fields'] === []) {
                $values = [];
            } elseif ($v['positional']) {
                $raw = count($v['fields']) === 1 ? [$payload] : self::tuple($payload, count($v['fields']));
                $values = self::readFields($v, $raw, 'positional');
            } else {
                $values = self::readFields($v, self::record($payload), 'data');
            }
        }
        if ($d->kind === 'model') {
            self::check($d, $v, $values);
        }
        return self::newValue($v, $values, $d->kind === 'model');
    }

    /** @return array{LeanVariant, mixed} */
    private static function pick(Desc $d, mixed $value): array
    {
        if (is_string($value)) {
            foreach ($d->variants as $v) {
                if ($v['name'] === $value && $v['fields'] === []) {
                    return [$v, null];
                }
            }
        } else {
            $obj = self::record($value);
            if (count($obj) === 1) {
                $tag = array_key_first($obj);
                foreach ($d->variants as $v) {
                    if ($v['name'] === $tag && $v['fields'] !== []) {
                        return [$v, $obj[$tag]];
                    }
                }
            }
        }
        self::fail('Expected a constructor of ' . $d->name . '.');
    }

    /** @return LeanVariant
     * @phpstan-assert object $value
     */
    private static function variantForValue(Desc $d, mixed $value): array
    {
        if (is_object($value)) {
            foreach ($d->variants as $v) {
                if ($v['cls'] === $value::class) {
                    return $v;
                }
            }
        }
        self::fail('Expected ' . $d->name . '.');
    }

    /** @return LeanVariant */
    private static function variantForClass(Desc $d, string $class): array
    {
        foreach ($d->variants as $v) {
            if ($v['cls'] === $class) {
                return $v;
            }
        }
        throw new \LogicException('Class is missing from its descriptor: ' . $class);
    }

    /** @param LeanVariant $v
     * @param array<int|string, mixed> $input
     * @return list<mixed>
     */
    private static function readFields(array $v, array $input, string $mode): array
    {
        $issues = [];
        $fields = [];
        foreach ($v['fields'] as $i => $f) {
            $key = match ($mode) {
                'properties' => $f['prop'],
                'positional' => $i,
                default => $f['key'],
            };
            if ($f['flat']) {
                try {
                    $desc = $f['desc']->resolve();
                    $parent = $desc->variants[0];
                    $fields[] = self::newValue(
                        $parent,
                        self::readFields($parent, $input, $mode),
                        $desc->kind === 'model',
                    );
                } catch (ValidationError $e) {
                    array_push($issues, ...$e->issues);
                }
                continue;
            }
            try {
                if (array_key_exists($key, $input)) {
                    $fields[] = self::normalize($f['desc'], $input[$key], $mode !== 'properties');
                } elseif ($f['desc']->resolve()->kind === 'option' && $mode === 'data') {
                    $fields[] = null;
                } else {
                    self::fail('Missing field.');
                }
            } catch (ValidationError $e) {
                array_push($issues, ...self::prefix($e, [$key])->issues);
            }
        }
        self::finish($issues);
        return $fields;
    }

    /** @param LeanVariant $v
     * @param list<mixed> $values
     * @return array<string, mixed>
     */
    private static function properties(array $v, array $values): array
    {
        $out = [];
        foreach ($v['fields'] as $i => $f) {
            $value = $values[$i];
            if ($f['flat'] && is_object($value)) {
                foreach (get_object_vars($value) as $key => $field) {
                    if (is_string($key)) {
                        $out[$key] = $field;
                    }
                }
            } else {
                $out[$f['prop']] = $value;
            }
        }
        return $out;
    }

    /** @param LeanVariant $v
     * @param list<mixed> $values
     */
    private static function newValue(array $v, array $values, bool $named = false): object
    {
        $cls = $v['cls'] ?? throw new \LogicException('Missing variant class.');
        $properties = self::properties($v, $values);
        return new $cls(...$named ? $properties : array_values($properties));
    }

    /** @param LeanVariant $v
     * @param list<mixed> $fields
     * @param list<RuntimeValue>|null $encoded
     */
    private static function check(Desc $d, array $v, array $fields, ?array $encoded = null): void
    {
        $issues = [];
        foreach ($v['invariants'] as $invariant) {
            $args = [];
            foreach ($invariant['args'] as $i) {
                $x = $encoded === null ? self::encode($v['fields'][$i]['desc'], $fields[$i]) : $encoded[$i];
                $args[] = $x;
            }
            if (!$invariant['decide'](...$args)) {
                $path = $d->kind === 'inductive'
                    ? [$d->name, $v['name'], $invariant['field']]
                    : [$d->name, $invariant['field']];
                if ($d->kind === 'model') {
                    $last = array_key_last($invariant['args']) ?? throw new \LogicException(
                        'Missing model proof argument.',
                    );
                    $path = [$v['fields'][$invariant['args'][$last]]['key']];
                }
                $issues[] = ['message' => $invariant['prop'], 'path' => $path];
            }
        }
        self::finish($issues);
    }

    /** @return RuntimeValue */
    private static function encode(Desc $desc, mixed $value): mixed
    {
        $d = $desc->resolve();
        return match ($d->kind) {
            'nat', 'int', 'fin' => self::integer($d, $value),
            'uint', 'sint', 'usize', 'isize' => L\numericLowBits(self::integer($d, $value), $d->bits),
            'bool' => (int) ($value === true),
            'char' => L\utf8Decode(self::string($value, true), 0),
            'string' => new LString(self::string($value, false)),
            'float', 'float32' => L\requireRuntimeFloat($value),
            'unit' => 0,
            'array' => new LArray(self::encodeList($d, self::list($value))),
            'list' => self::toList(self::encodeList($d, self::list($value))),
            'prod' => new Ctor(0, self::encodeList($d, self::tuple($value, 2))),
            'option' => $value === null ? 0 : new Ctor(1, [self::encode($d->first(), $value)]),
            'except' => match (true) {
                $value instanceof Ok => new Ctor(1, [self::encode($d->second(), $value->value)]),
                $value instanceof Err => new Ctor(0, [self::encode($d->first(), $value->error)]),
                default => self::fail('Expected Ok or Err.'),
            },
            'enum' => self::enumTag($d, $value),
            'struct', 'model', 'inductive', 'subtype' => self::encodeVariant($d, $value),
            default => throw new \LogicException('Unknown descriptor: ' . $d->kind),
        };
    }

    /** @param list<mixed> $items
     * @return list<RuntimeValue>
     */
    private static function encodeList(Desc $d, array $items): array
    {
        $issues = [];
        $out = [];
        foreach ($items as $i => $value) {
            try {
                $out[] = self::encode($d->kind === 'prod' && $i === 1 ? $d->second() : $d->first(), $value);
            } catch (ValidationError $e) {
                array_push($issues, ...self::prefix($e, [$i])->issues);
            }
        }
        self::finish($issues);
        return $out;
    }

    private static function enumTag(Desc $d, mixed $value): int
    {
        $case = self::enumValue($d, $value);
        $tag = array_search($d->enumByName ? $case->name : $case->value, $d->cases, true);
        return $tag === false ? throw new \LogicException('Unknown enum case.') : $tag;
    }

    /** @return RuntimeValue */
    private static function encodeVariant(Desc $d, mixed $value): mixed
    {
        if ($d->kind === 'subtype' && $d->cls === null) {
            return self::encode($d->first(), $value);
        }
        $v = self::variantForValue($d, $value);
        $fields = self::readFields($v, get_object_vars($value), 'properties');
        $encoded = [];
        $issues = [];
        foreach ($v['fields'] as $i => $f) {
            try {
                $encoded[] = self::encode($f['desc'], $fields[$i]);
            } catch (ValidationError $e) {
                array_push($issues, ...($f['flat'] ? $e : self::prefix($e, [$f['key']]))->issues);
            }
        }
        self::finish($issues);
        self::check($d, $v, $fields, $encoded);
        if ($d->trivial !== null) {
            return $encoded[$d->trivial];
        }
        if ($v['size'] === 0 && $v['usize'] === 0 && $v['ssize'] === 0) {
            return $v['tag'];
        }
        $ctor = new Ctor($v['tag'], array_fill(0, $v['size'], 0));
        foreach ($v['fields'] as $i => $f) {
            $x = $encoded[$i];
            $at = $f['at'];
            if ($f['slot'] === 'obj') {
                $ctor->objs[$at] = $x;
            } elseif ($f['slot'] === 'usize') {
                L\lean_ctor_set_usize($ctor, $at, L\requireRuntimeInt($x));
            } elseif ($f['slot'] !== 'none') {
                $ctor->sc[(8 * ($v['size'] + $v['usize'])) + $at] = match ($f['slot']) {
                    'f32', 'f64' => L\requireRuntimeFloat($x),
                    default => L\requireRuntimeInt($x),
                };
            }
        }
        return $ctor;
    }

    private static function fromVariant(Desc $d, mixed $value): mixed
    {
        if ($d->kind === 'subtype' && $d->cls === null) {
            return self::fromLean($d->first(), $value);
        }
        $tag = $d->kind === 'inductive' && $d->trivial === null ? L\lean_obj_tag(self::tagged($value)) : 0;
        $v = $d->variants[$tag];
        $fields = [];
        foreach ($v['fields'] as $i => $f) {
            $at = $f['at'];
            $x = match (true) {
                $i === $d->trivial => $value,
                $f['slot'] === 'none' => 0,
                $f['slot'] === 'obj' => self::get($value, $at),
                $f['slot'] === 'usize' => L\lean_ctor_get_usize(L\requireRuntimeObject($value, Ctor::class), $at),
                default => L\requireRuntimeObject($value, Ctor::class)->sc[(8 * ($v['size'] + $v['usize'])) + $at],
            };
            $fields[] = self::fromLean($f['desc'], $x);
        }
        return self::newValue($v, $fields, $d->kind === 'model');
    }

    private static function tagged(mixed $value): int|Ctor
    {
        return is_int($value) ? $value : L\requireRuntimeObject($value, Ctor::class);
    }

    private static function get(mixed $value, int $i): mixed
    {
        return L\lean_ctor_get(L\requireRuntimeObject($value, Ctor::class), $i);
    }

    /** @param list<RuntimeValue> $items */
    private static function toList(array $items): Ctor|int
    {
        $result = 0;
        foreach (array_reverse($items) as $item) {
            $result = new Ctor(1, [$item, $result]);
        }
        return $result;
    }

    /** @return list<mixed> */
    private static function fromList(Desc $d, mixed $value): array
    {
        $items = [];
        while ($value !== 0) {
            $items[] = self::fromLean($d, self::get($value, 0));
            $value = self::get($value, 1);
        }
        return $items;
    }
}
