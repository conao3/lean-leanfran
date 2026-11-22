<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Lean;
use RuntimeException;
use stdClass;

/** The Composer configuration and dependency graph of Lean blocks. */
final class Project
{
    public const TOOLCHAIN = 'leanprover/lean4:v4.35.0';

    /**
     * @param array<string, Block> $blocks
     * @param list<stdClass> $requirements
     * @param array<string, string> $hashes
     */
    private function __construct(
        public readonly string $root,
        public readonly array $blocks,
        public readonly array $requirements,
        public readonly string $toolchain,
        private array $hashes = [],
    ) {}

    /** Loads the Composer project and scans its configured PHP directories. */
    public static function load(string $dir): self
    {
        $root = realpath($dir);
        if ($root === false || !is_file("$root/composer.json")) {
            throw new RuntimeException("no composer.json in $dir");
        }
        $composer = Files::json("$root/composer.json");
        if (!$composer instanceof stdClass) {
            throw new RuntimeException("$root/composer.json: expected an object");
        }
        $extra = self::object($composer->extra ?? new stdClass(), 'extra');
        $config = self::object($extra->leanfran ?? new stdClass(), 'extra.leanfran');
        $autoload = self::object($composer->autoload ?? new stdClass(), 'autoload');
        $psr = self::object($autoload->{'psr-4'} ?? new stdClass(), 'autoload.psr-4');
        $paths = [];
        if (property_exists($config, 'paths')) {
            array_push($paths, ...self::paths($config->paths, 'extra.leanfran.paths'));
        } else {
            foreach (get_object_vars($psr) as $value) {
                array_push($paths, ...is_string($value) ? [$value] : self::paths($value, 'autoload.psr-4'));
            }
        }
        $require = $config->require ?? [];
        if (!is_array($require) || !array_is_list($require)) {
            throw new RuntimeException('composer.json: extra.leanfran.require must be a list of Lake requirements');
        }
        $requirements = [];
        foreach ($require as $item) {
            $requirements[] = self::object($item, 'extra.leanfran.require entry');
        }
        $file = "$root/lean-toolchain";
        $toolchain = file_exists($file) ? trim(Files::read($file)) : self::TOOLCHAIN;
        if (!preg_match('~^leanprover/lean4:v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$~D', $toolchain)) {
            throw new RuntimeException("$file: expected a Lean release toolchain, got $toolchain");
        }
        $files = [];
        foreach ($paths as $path) {
            $candidate = str_starts_with($path, '/') ? $path : "$root/$path";
            $resolved = realpath($candidate);
            if (!file_exists($candidate) && !is_link($candidate)) {
                continue;
            }
            if ($resolved === false || !is_dir($resolved) || !str_starts_with("$resolved/", "$root/")) {
                throw new RuntimeException("composer.json: scan path must be a directory in the package: $path");
            }
            foreach (Files::walk($resolved) as $from) {
                if (str_ends_with($from, '.php')) {
                    $files[$from] = true;
                }
            }
        }
        ksort($files, SORT_STRING);
        $blocks = [];
        $outputs = [];
        foreach (array_keys($files) as $from) {
            if (Files::generated($from)) {
                continue;
            }
            $file = substr($from, strlen($root) + 1);
            foreach (Scanner::scan($file, Files::read($from)) as $block) {
                $key = strtolower($block->name);
                if (isset($blocks[$key])) {
                    throw new RuntimeException($block->location() . ": duplicate Lean block $block->name");
                }
                $output = strtolower($block->output);
                if (isset($outputs[$output])) {
                    throw new RuntimeException(
                        $block->location() . ": output directory is shared by $block->name and {$outputs[$output]}",
                    );
                }
                $blocks[$key] = $block;
                $outputs[$output] = $block->name;
            }
        }
        $project = new self($root, $blocks, $requirements, $toolchain);
        foreach ($blocks as $block) {
            $project->hash($block, []);
        }
        return $project;
    }

    /** Returns the hash of a block and its transitive inputs. */
    public function digest(Block $block): string
    {
        return $this->hashes[strtolower($block->name)];
    }

    /**
     * Resolves and deduplicates the direct block dependencies.
     *
     * @return array<string, Block>
     */
    public function dependencies(Block $block): array
    {
        $dependencies = [];
        foreach ($block->uses as $name) {
            $key = strtolower($name);
            $dependencies[$key] = $this->blocks[$key] ?? throw new RuntimeException(
                $block->location() . ": Lean block $block->name uses unknown block $name",
            );
        }
        return $dependencies;
    }

    /**
     * Returns all dependencies for resolving external public types.
     *
     * @return array<string, Block>
     */
    public function typeDependencies(Block $block): array
    {
        $deps = [];
        $this->collectTypes($block, $deps);
        return $deps;
    }

    /** @param array<string, Block> $deps */
    private function collectTypes(Block $block, array &$deps): void
    {
        foreach ($this->dependencies($block) as $key => $dep) {
            if (!isset($deps[$key])) {
                $deps[$key] = $dep;
                $this->collectTypes($dep, $deps);
            }
        }
    }

    /** @param array<string, true> $visiting */
    private function hash(Block $block, array $visiting): string
    {
        $key = strtolower($block->name);
        if (isset($this->hashes[$key])) {
            return $this->hashes[$key];
        }
        if (isset($visiting[$key])) {
            throw new RuntimeException($block->location() . ": cyclic Lean block dependency on $block->name");
        }
        $visiting[$key] = true;
        $uses = [];
        foreach ($this->dependencies($block) as $dependency) {
            $uses[$dependency->name] = $this->hash($dependency, $visiting);
        }
        return $this->hashes[$key] = hash('sha256', json_encode([
            'source' => $block->source->text,
            'imports' => $block->imports,
            'uses' => $uses,
            'models' => [],
            'settings' => [
                'module' => $block->module,
                'php_namespace' => $block->name,
                'facade' => 'Functions',
                'facade_kind' => 'trait',
            ],
            'require' => self::canonical($this->requirements),
            'generator_version' => Lean::GENERATOR_VERSION,
            'lean-toolchain' => $this->toolchain,
        ], JSON_THROW_ON_ERROR));
    }

    private static function canonical(mixed $value): mixed
    {
        if ($value instanceof stdClass) {
            $fields = get_object_vars($value);
            ksort($fields, SORT_STRING);
            return (object) array_map(self::canonical(...), $fields);
        }
        return is_array($value) ? array_map(self::canonical(...), $value) : $value;
    }

    /** @return list<string> */
    public static function paths(mixed $value, string $field): array
    {
        if (!is_array($value) || !array_is_list($value)) {
            throw new RuntimeException("composer.json: $field must be a list of paths");
        }
        $paths = [];
        foreach ($value as $path) {
            if (!is_string($path) || str_contains($path, "\0")) {
                throw new RuntimeException("composer.json: $field must contain paths");
            }
            $paths[] = $path;
        }
        return $paths;
    }

    private static function object(mixed $value, string $field): stdClass
    {
        if (!$value instanceof stdClass) {
            throw new RuntimeException("composer.json: $field must be an object");
        }
        return $value;
    }
}
