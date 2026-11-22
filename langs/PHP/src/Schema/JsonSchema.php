<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Schema;

/** Builds a JSON Schema from a public Lean type descriptor. */
final class JsonSchema
{
    private const TARGETS = ['draft-2020-12', 'draft-07', 'openapi-3.0'];

    /** @var array<string, array<string, mixed>> */
    private array $definitions = [];

    /** @var array<string, true> */
    private array $active = [];

    /** @var array<string, true> */
    private array $referenced = [];

    private readonly string $definitionsKey;

    private function __construct(
        private readonly string $target,
    ) {
        $this->definitionsKey = $target === 'draft-2020-12' ? '$defs' : 'definitions';
    }

    /** @return array<string, mixed> */
    public static function of(Desc $root, string $target = 'draft-2020-12'): array
    {
        if (!in_array($target, self::TARGETS, true)) {
            throw new \InvalidArgumentException(
                'Unsupported JSON Schema target '
                . $target
                . ' (expected one of '
                . implode(', ', self::TARGETS)
                . ').',
            );
        }

        $generator = new self($target);
        $schema = $generator->generate($root);
        if ($generator->definitions !== []) {
            if ($target !== 'draft-2020-12') {
                $schema = ['allOf' => [$schema]];
            }
            $schema[$generator->definitionsKey] = $generator->definitions;
        }

        return match ($target) {
            'draft-2020-12' => ['$schema' => 'https://json-schema.org/draft/2020-12/schema', ...$schema],
            'draft-07' => ['$schema' => 'http://json-schema.org/draft-07/schema#', ...$schema],
            'openapi-3.0' => self::openApiBounds($schema),
        };
    }

    /** @return array<string, mixed> */
    private function generate(Desc $desc): array
    {
        $d = $desc->resolve();
        return match ($d->kind) {
            'nat' => ['type' => 'integer', 'minimum' => 0],
            'int' => ['type' => 'integer'],
            'uint', 'usize' => $d->kind === 'usize' || $d->bits === 64
                ? ['type' => 'string', 'pattern' => '^(0|[1-9][0-9]*)$']
                : ['type' => 'integer', 'minimum' => 0, 'maximum' => (1 << $d->bits) - 1],
            'sint', 'isize' => $d->kind === 'isize' || $d->bits === 64
                ? ['type' => 'integer', 'minimum' => PHP_INT_MIN, 'exclusiveMaximum' => 2 ** 63]
                : ['type' => 'integer', 'minimum' => -(1 << ($d->bits - 1)), 'maximum' => (1 << ($d->bits - 1)) - 1],
            'fin' => ['type' => 'integer', 'minimum' => 0, 'exclusiveMaximum' => self::number($d->bound)],
            'bool' => ['type' => 'boolean'],
            'char' => ['type' => 'string', 'minLength' => 1, 'maxLength' => 1],
            'string' => ['type' => 'string'],
            'float', 'float32' => ['type' => 'number'],
            'unit' => ['type' => 'object', 'additionalProperties' => false],
            'list', 'array' => ['type' => 'array', 'items' => $this->generate($d->first())],
            'option' => $this->option($this->generate($d->first())),
            'prod' => $this->tuple([$this->generate($d->first()), $this->generate($d->second())]),
            'except' => ['oneOf' => [
                self::tagged('ok', $this->generate($d->second())),
                self::tagged('error', $this->generate($d->first())),
            ]],
            'subtype' => self::withBounds($this->generate($d->first()), $d->bounds),
            'struct', 'enum', 'inductive' => $this->named($d),
            default => throw new \LogicException('Unknown descriptor: ' . $d->kind),
        };
    }

    /** @return array<string, mixed> */
    private function named(Desc $d): array
    {
        $name = $d->name;
        $ref = ['$ref' => '#/' . $this->definitionsKey . '/' . $name];
        if (isset($this->active[$name])) {
            $this->referenced[$name] = true;
            return $ref;
        }
        if (isset($this->definitions[$name])) {
            return $ref;
        }

        $this->active[$name] = true;
        $schema = match ($d->kind) {
            'struct' => $this->fields($d->variants[0]),
            'enum' => ['type' => 'string', 'enum' => $d->cases],
            'inductive' => ['oneOf' => array_map($this->variant(...), $d->variants)],
            default => throw new \LogicException('Expected a named descriptor.'),
        };
        unset($this->active[$name]);
        if (isset($this->referenced[$name])) {
            $this->definitions[$name] = $schema;
            return $ref;
        }
        return $schema;
    }

    /**
     * @param LeanVariant $variant
     * @return array<string, mixed>
     */
    private function fields(array $variant): array
    {
        [$properties, $required] = $this->recordFields($variant);
        return [
            'type' => 'object',
            'properties' => self::properties($properties),
            'required' => $required,
            'additionalProperties' => false,
        ];
    }

    /**
     * @param LeanVariant $variant
     * @return array{array<int|string, array<string, mixed>>, list<string>}
     */
    private function recordFields(array $variant): array
    {
        $properties = [];
        $required = [];
        foreach ($variant['fields'] as $field) {
            $desc = $field['desc']->resolve();
            if ($field['flat']) {
                if ($desc->kind !== 'struct') {
                    throw new \LogicException('Expected a flattened structure descriptor.');
                }
                [$parent, $keys] = $this->recordFields($desc->variants[0]);
                $properties = array_replace($properties, $parent);
                array_push($required, ...$keys);
            } else {
                $properties[$field['key']] = self::withBounds($this->generate($desc), $field['bounds']);
                if ($desc->kind !== 'option') {
                    $required[] = $field['key'];
                }
            }
        }
        return [$properties, $required];
    }

    /**
     * @param LeanVariant $variant
     * @return array<string, mixed>
     */
    private function variant(array $variant): array
    {
        $name = $variant['name'];
        $fields = $variant['fields'];
        if ($fields === []) {
            return $this->target === 'openapi-3.0' ? ['type' => 'string', 'enum' => [$name]] : ['const' => $name];
        }
        if (!$variant['positional']) {
            return self::tagged($name, $this->fields($variant));
        }
        $items = array_map(fn(array $f): array => self::withBounds($this->generate($f['desc']), $f['bounds']), $fields);
        return self::tagged($name, count($items) === 1 ? $items[0] : $this->tuple($items));
    }

    /**
     * @param array<string, mixed> $value
     * @return array<string, mixed>
     */
    private static function tagged(string $key, array $value): array
    {
        return [
            'type' => 'object',
            'properties' => self::properties([$key => $value]),
            'required' => [$key],
            'additionalProperties' => false,
        ];
    }

    /**
     * @param array<int|string, array<string, mixed>> $fields
     * @return array<int|string, array<string, mixed>>|\stdClass
     */
    private static function properties(array $fields): array|\stdClass
    {
        return array_is_list($fields) ? (object) $fields : $fields;
    }

    /**
     * @param array<string, mixed> $item
     * @return array<string, mixed>
     */
    private function option(array $item): array
    {
        if ($this->target !== 'openapi-3.0') {
            return ['anyOf' => [$item, ['type' => 'null']]];
        }
        return [...(isset($item['type']) ? $item : ['allOf' => [$item]]), 'nullable' => true];
    }

    /**
     * @param list<array<string, mixed>> $items
     * @return array<string, mixed>
     */
    private function tuple(array $items): array
    {
        return [
            'type' => 'array',
            $this->target === 'draft-2020-12' ? 'prefixItems' : 'items' => $items,
            'minItems' => count($items),
            'maxItems' => count($items),
        ];
    }

    private static function number(string $decimal): int|float
    {
        $float = (float) $decimal;
        return abs($float) < (2 ** 53) ? (int) $float : $float;
    }

    /**
     * @param array<string, mixed> $schema
     * @param array<string, string> $bounds
     * @return array<string, mixed>
     */
    private static function withBounds(array $schema, array $bounds): array
    {
        if ($bounds === []) {
            return $schema;
        }
        $numbers = array_map(self::number(...), $bounds);
        if (isset($schema['$ref']) || isset($schema['anyOf']) || isset($schema['oneOf']) || isset($schema['allOf'])) {
            return ['allOf' => [$schema, $numbers]];
        }
        return [...$schema, ...$numbers];
    }

    /**
     * @template K of array-key
     * @param array<K, mixed> $schema
     * @return array<K|string, mixed>
     */
    private static function openApiBounds(array $schema): array
    {
        $out = [];
        foreach ($schema as $key => $value) {
            if (($key === 'exclusiveMinimum' || $key === 'exclusiveMaximum') && (is_int($value) || is_float($value))) {
                $out[$key === 'exclusiveMinimum' ? 'minimum' : 'maximum'] = $value;
                $out[$key] = true;
            } else {
                $out[$key] = match (true) {
                    is_array($value) => self::openApiBounds($value),
                    $value instanceof \stdClass => (object) self::openApiBounds(get_object_vars($value)),
                    default => $value,
                };
            }
        }
        return $out;
    }
}
