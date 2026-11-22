<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\Models;
use Conao3\Leanfran\Embed\Project;
use Conao3\Leanfran\Schema\Desc;
use RuntimeException;

/** Resolves the value types imported by an embedded block and its public types. */
final class Objects
{
    /** @var array<string, Type> */
    private array $types = [];

    /** @var array<string, array<string, Type>> */
    private array $fields = [];

    /** @var array<string, list<string>> */
    private array $cases = [];

    /** @var array<string, list<LeanInvariant>> */
    private array $checks = [];

    /** @var array<string, true> */
    private array $constructible = [];

    /** @var array<string, string> */
    private array $extra = [];

    private ?Models $loader = null;

    /** Uses synced public descriptors and the project's imported structures. */
    public function __construct(
        private readonly Project $project,
    ) {}

    /** Resolves a PHP model or generated class. */
    public function type(string $class): Type
    {
        $key = strtolower($class);
        if (isset($this->types[$key])) {
            return $this->types[$key];
        }
        $class = ltrim($class, '\\');
        foreach ($this->project->models as $models) {
            foreach ($models as $name => $source) {
                if (strcasecmp($class, $name) === 0) {
                    return $this->imported($key, Models::name($name), $source, $name);
                }
            }
        }
        foreach ($this->project->blocks as $block) {
            if (!str_starts_with($key, strtolower($block->name) . '\\')) {
                continue;
            }
            $tail = substr($class, strlen($block->name) + 1);
            if (
                !str_contains($tail, '\\')
                && is_file($this->project->root . "/$block->output/$tail.php")
                && class_exists($class)
                && is_callable([$class, 'desc'])
            ) {
                $desc = $class::desc();
                if ($desc instanceof Desc) {
                    return $this->generated($key, $block->module . '.' . $tail, $desc);
                }
            }
        }
        if (!class_exists($class)) {
            throw new RuntimeException("unsupported PHP value type $class");
        }
        $reflection = new \ReflectionClass($class);
        if ($reflection->isInternal()) {
            throw new RuntimeException("unsupported PHP value type $class");
        }
        $name = $reflection->getName();
        $loader = $this->loader ??= new Models($this->project->root, refine: false);
        $definitions = $loader->valueTypes($name);
        foreach ($this->project->models as $embedded) {
            $definitions = array_diff_key($definitions, $embedded);
        }
        $this->extra += $definitions;
        return $this->imported($key, Models::name($name), $definitions[$name], $name);
    }

    /** @return array<string, string> */
    public function standalone(): array
    {
        return $this->extra;
    }

    /** @return array<string, Type> */
    public function fields(Type $type): array
    {
        return $this->fields[$type->name] ?? [];
    }

    /** @return list<string> */
    public function cases(Type $type): array
    {
        return $this->cases[$type->name] ?? [];
    }

    /** Returns whether structural construction preserves the PHP constructor's behavior. */
    public function constructible(Type $type): bool
    {
        return isset($this->constructible[$type->name]);
    }

    /** @return list<LeanInvariant> */
    public function invariants(Type $type): array
    {
        return $this->checks[$type->name] ?? [];
    }

    private function imported(string $key, string $lean, string $source, string $class): Type
    {
        if (str_starts_with($source, 'inductive ')) {
            preg_match_all('/^  \| «([^»]+)»/m', $source, $cases);
            $this->cases[$lean] = $cases[1];
            return $this->types[$key] = new Type('enum', name: $lean);
        }
        $fields = [];
        foreach (array_slice(explode("\n", $source), 1) as $field) {
            if (preg_match('/^  «([^»]+)» : (.+)$/D', $field, $parts) !== 1) {
                throw new RuntimeException("PHPDoc refinements of $class cannot be assumed in a verified function");
            }
            $fields[$parts[1]] = $this->leanType($parts[2]);
        }
        $this->fields[$lean] = $fields;
        if (!class_exists($class)) {
            throw new RuntimeException("unknown embedded PHP class $class");
        }
        $constructor = new \ReflectionClass($class)->getConstructor();
        if ($constructor === null || self::emptyConstructor($constructor)) {
            $this->constructible[$lean] = true;
        }
        return $this->types[$key] = new Type('object', name: $lean);
    }

    private static function emptyConstructor(\ReflectionMethod $constructor): bool
    {
        $file = $constructor->getFileName();
        $start = $constructor->getStartLine();
        $end = $constructor->getEndLine();
        if ($file === false || $start === false || $end === false) {
            return false;
        }
        $lines = file($file);
        if ($lines === false) {
            return false;
        }
        $method = implode('', array_slice($lines, $start - 1, $end - $start + 1));
        return preg_match('/\)\s*\{\s*\}\s*$/D', trim($method)) === 1;
    }

    private function leanType(string $text): Type
    {
        $primitive = match ($text) {
            'Int' => 'int',
            'Float' => 'float',
            'String' => 'string',
            'Bool' => 'bool',
            default => null,
        };
        if ($primitive !== null) {
            return new Type($primitive);
        }
        if (preg_match('/^\((List|Option) (.+)\)$/D', $text, $match) === 1) {
            return new Type($match[1] === 'List' ? 'list' : 'option', [$this->leanType($match[2])]);
        }
        if (str_starts_with($text, '(') && str_ends_with($text, ')')) {
            $depth = 0;
            foreach (explode(' ', substr($text, 1, -1)) as $i => $word) {
                if ($word === '×' && $depth === 0) {
                    $parts = explode(' ', substr($text, 1, -1));
                    return new Type('pair', [
                        $this->leanType(implode(' ', array_slice($parts, 0, $i))),
                        $this->leanType(implode(' ', array_slice($parts, $i + 1))),
                    ]);
                }
                $depth += substr_count($word, '(') - substr_count($word, ')');
            }
        }
        if (preg_match('/^_root_\.LeanPhpModels\.((?:«[^»]+»\.?)+)$/D', $text, $match) === 1) {
            return $this->type(str_replace(['«', '»', '.'], ['', '', '\\'], $match[1]));
        }
        throw new RuntimeException("unsupported or refined model field type $text");
    }

    private function generated(string $key, string $lean, Desc $desc): Type
    {
        if ($desc->kind === 'enum') {
            $this->cases[$lean] = $desc->cases;
            return $this->types[$key] = new Type('enum', name: $lean);
        }
        if ($desc->kind !== 'struct') {
            throw new RuntimeException("unsupported generated shape $desc->kind for $key");
        }
        $type = $this->types[$key] = new Type('object', name: $lean);
        $fields = [];
        try {
            foreach ($desc->variants[0]['fields'] ?? [] as $field) {
                $fields[$field['key']] = $this->descriptor($field['desc']);
            }
        } catch (RuntimeException $error) {
            unset($this->types[$key]);
            throw $error;
        }
        $this->fields[$lean] = $fields;
        if (!array_any($desc->variants[0]['fields'] ?? [], static fn(array $field): bool => $field['flat'])) {
            $this->constructible[$lean] = true;
            $this->checks[$lean] = $desc->variants[0]['invariants'] ?? [];
        }
        return $type;
    }

    private function descriptor(Desc $desc): Type
    {
        $desc = $desc->resolve();
        return match ($desc->kind) {
            'int', 'nat', 'bool', 'float', 'string' => new Type($desc->kind),
            'list', 'option' => new Type($desc->kind, [$this->descriptor($desc->first())]),
            'pair' => new Type('pair', [$this->descriptor($desc->first()), $this->descriptor($desc->second())]),
            default => $desc->cls === null
                ? throw new RuntimeException("unsupported generated field type $desc->kind")
                : $this->type($desc->cls),
        };
    }
}
