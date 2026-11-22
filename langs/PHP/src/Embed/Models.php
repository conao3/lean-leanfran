<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use BackedEnum;
use Closure;
use ReflectionClass;
use ReflectionEnum;
use ReflectionNamedType;
use ReflectionProperty;
use RuntimeException;

/** Collects the PHP models of each block in Lean declaration order. */
final class Models
{
    /** @var array<string, array<string, string>> */
    private array $definitions = [];

    /** Loads the model classes through the package's Composer autoloader. */
    public function __construct(
        string $root,
        private readonly bool $refine = true,
    ) {
        $autoload = "$root/vendor/autoload.php";
        if (!is_file($autoload)) {
            throw new RuntimeException("$autoload: install the Composer dependencies to load Lean models");
        }
        require_once $autoload;
    }

    /** @return array<string, string> */
    public function block(Block $block): array
    {
        $out = [];
        foreach ($block->models as $class) {
            try {
                $out += $this->collect(self::reflect($class), []);
            } catch (RuntimeException $error) {
                throw new RuntimeException($block->location() . ': ' . $error->getMessage(), previous: $error);
            }
        }
        return $out;
    }

    /** @return array<string, string> */
    public function valueTypes(string $class): array
    {
        return $this->collect(self::reflect($class), []);
    }

    /** Returns the Lean name of a PHP model, with individual identifiers escaped. */
    public static function name(string $class): string
    {
        return 'LeanPhpModels.' . implode('.', array_map(self::ident(...), explode('\\', $class)));
    }

    private static function ident(string $name): string
    {
        return "«{$name}»";
    }

    /** @return ReflectionClass<object> */
    private static function reflect(string $class): ReflectionClass
    {
        if (!class_exists($class)) {
            throw new RuntimeException("unknown Lean model class $class");
        }
        return new ReflectionClass($class);
    }

    /**
     * @param ReflectionClass<object> $class
     * @param array<string, true> $active
     * @return array<string, string>
     */
    private function collect(ReflectionClass $class, array $active): array
    {
        $name = $class->getName();
        if ($class->isAnonymous()) {
            throw new RuntimeException("$name: expected a named Lean model class");
        }
        if (isset($active[$name])) {
            throw new RuntimeException("$name: recursive Lean models are not supported");
        }
        if (isset($this->definitions[$name])) {
            return $this->definitions[$name];
        }
        $lean = self::name($name);
        if ($class->isEnum()) {
            if (!is_subclass_of($name, BackedEnum::class)) {
                throw new RuntimeException("$name: expected a backed enum");
            }
            $enum = new ReflectionEnum($name);
            $cases = array_map(
                static fn(\ReflectionEnumUnitCase $case): string => '  | ' . self::ident($case->name),
                $enum->getCases(),
            );
            return $this->definitions[$name] = [$name => "inductive $lean where\n" . implode("\n", $cases)];
        }
        $constructor = $class->getConstructor();
        if (!$class->isFinal() || $class->isInternal() || $constructor !== null && !$constructor->isPublic()) {
            throw new RuntimeException("$name: expected a final class with a public constructor");
        }
        $properties = [];
        for ($owner = $class; $owner !== false; $owner = $owner->getParentClass()) {
            foreach ($owner->getProperties() as $property) {
                if ($property->getDeclaringClass()->name !== $owner->name) {
                    continue;
                }
                if (!$property->isPublic() || !$property->isReadOnly() || !$property->isPromoted()) {
                    throw new RuntimeException("$name.{$property->name}: expected a promoted public readonly property");
                }
                $properties[$property->name] ??= $property;
            }
        }
        $parameters = $constructor?->getParameters() ?? [];
        if ($parameters === [] && $properties === []) {
            return $this->definitions[$name] = [$name => "structure $lean where"];
        }

        $active[$name] = true;
        $deps = [];
        $fields = [];
        $names = array_fill_keys(array_keys($properties), true);
        $file = $constructor?->getFileName();
        $line = $constructor?->getStartLine();
        if (!is_string($file) || !is_int($line)) {
            throw new RuntimeException("$name: missing model constructor source");
        }
        $scope = Scanner::resolver($file, $line);
        $ownerName = $constructor->getDeclaringClass()->name;
        $resolve = static fn(string $type): string => self::reflect(
            $type === 'self' ? $ownerName : $scope($type),
        )->name;
        $params = self::doc($constructor->getDocComment() ?: '');
        preg_match_all('/(?:^|\s)@param\s+([^$@]*?)\$([\w\x80-\xff]+)(?=\s|$)/m', $params, $matches, PREG_SET_ORDER);
        $annotations = [];
        foreach ($matches as [, $type, $param]) {
            $annotations[$param] = trim($type);
        }

        foreach ($parameters as $parameter) {
            $prop = $parameter->name;
            $where = "$name.$prop";
            $property = $properties[$prop] ?? null;
            if (!$parameter->isPromoted() || $property === null) {
                throw new RuntimeException("$where: expected a promoted public readonly property");
            }
            unset($properties[$prop]);
            try {
                $type = self::propertyType($property, $annotations[$prop] ?? null, $resolve);
                if (!$this->refine) {
                    $type = $type->shape();
                }
                foreach ($type->classes() as $dependency) {
                    $deps += $this->collect(self::reflect($dependency), $active);
                }
                $id = self::ident($prop);
                $fields[] = "  $id : " . $type->lean();
                foreach ($type->proofs($id) as $suffix => $proof) {
                    $field = $prop . '_' . $suffix;
                    if (isset($names[$field])) {
                        throw new RuntimeException("generated proof field $field conflicts with another field");
                    }
                    $names[$field] = true;
                    $fields[] = '  ' . self::ident($field) . " : $proof";
                }
            } catch (RuntimeException $error) {
                throw new RuntimeException("$where: {$error->getMessage()}", previous: $error);
            }
        }
        if ($properties !== []) {
            $prop = array_key_first($properties);
            throw new RuntimeException("$name.$prop: expected a property of the model constructor");
        }
        return $this->definitions[$name] = $deps + [$name => "structure $lean where\n" . implode("\n", $fields)];
    }

    private static function doc(string $doc): string
    {
        return trim((string) preg_replace('~^/\*\*|\*/$|^[ \t]*\*[ \t]?~m', '', $doc));
    }

    /** @param Closure(string): string $resolve */
    private static function propertyType(ReflectionProperty $property, ?string $param, Closure $resolve): PhpDocType
    {
        $native = $property->getType();
        if (!$native instanceof ReflectionNamedType) {
            throw new RuntimeException('expected a named native type or its nullable form');
        }
        $base = $native->getName();
        if (!$native->isBuiltin()) {
            $base = $base === 'self' ? $property->getDeclaringClass()->name : self::reflect($base)->name;
        }

        $type = $param === null ? null : PhpDocType::parse($param, $resolve);
        if (preg_match('/(?:^|\s)@var\s+([^@]+)/m', self::doc($property->getDocComment() ?: ''), $match)) {
            $type = PhpDocType::parse(trim($match[1]), $resolve, true);
        }
        if ($type === null) {
            if ($base === 'array') {
                throw new RuntimeException('native array requires a list or pair PHPDoc type');
            }
            $type = PhpDocType::parse(
                ($native->allowsNull() ? '?' : '') . $base,
                $native->isBuiltin() ? $resolve : static fn(string $_): string => $base,
            );
        }
        if ($type->native() !== $base || $type->kind === 'option' && !$native->allowsNull()) {
            throw new RuntimeException("PHPDoc type is incompatible with native type $native");
        }
        return $type;
    }
}
