<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

use Closure;
use Conao3\Leanfran\Embed\Block;
use Conao3\Leanfran\Embed\Project;
use Conao3\Leanfran\Embed\Status;
use Conao3\Leanfran\Verify\Declaration;
use Conao3\Leanfran\Verify\Discover;
use Conao3\Leanfran\Verify\Inputs;
use Conao3\Leanfran\Verify\Objects;
use Conao3\Leanfran\Verify\PropertyFailure;
use Conao3\Leanfran\Verify\Signature;
use Conao3\Leanfran\Verify\Type;
use ReflectionClass;
use ReflectionFunction;
use RuntimeException;
use Throwable;

/** Tests PHP functions against their generated Lean specifications. */
final class Verify
{
    /** Runs a reproducible property check for a modeled function. */
    public static function checkModel(callable $f, int $runs = 200, int $seed = 1): void
    {
        if ($runs < 1 || $runs > intdiv(PHP_INT_MAX, 100)) {
            throw new \InvalidArgumentException('runs must be positive and leave room for 100 attempts per run');
        }
        $call = Closure::fromCallable($f);
        $reflection = new ReflectionFunction($call);
        $class = $reflection->getClosureScopeClass();
        $name = ($class === null ? '' : $class->getName() . '\\') . $reflection->getName();
        $file = $reflection->getFileName();
        if ($file === false || $reflection->getAttributes(Model::class) === []) {
            throw new \InvalidArgumentException("$name: expected a callable with a Model attribute");
        }
        $project = self::project($file);
        $declaration = Discover::project($project)->models[strtolower($name)] ?? throw new RuntimeException(
            "$name: model source is outside the scanned Composer paths",
        );
        $objects = new Objects($project);
        [$types] = new Signature($project->root, $declaration, $objects)->read();
        self::run($call, $project, $declaration, new Inputs($objects, $seed), array_values($types), $runs, $seed);
    }

    /** Tests each modeled method declared by the class. */
    public static function checkClass(string $class): void
    {
        if (!class_exists($class)) {
            throw new \InvalidArgumentException("Unknown model class $class");
        }
        $reflection = new ReflectionClass($class);
        foreach ($reflection->getMethods() as $method) {
            if (
                $method->getDeclaringClass()->name !== $reflection->name
                || $method->getAttributes(Model::class) === []
            ) {
                continue;
            }
            if (!$method->isStatic()) {
                throw new \InvalidArgumentException("$class::{$method->name}: expected a static model method");
            }
            self::checkModel($method->getClosure());
        }
    }

    private static function project(string $file): Project
    {
        $dir = dirname($file);
        while (!is_file("$dir/composer.json")) {
            $parent = dirname($dir);
            if ($parent === $dir) {
                throw new RuntimeException("$file: no enclosing Composer project");
            }
            $dir = $parent;
        }
        return Project::load($dir);
    }

    /**
     * @param Closure(mixed...): mixed $call
     * @param list<Type> $types
     */
    private static function run(
        Closure $call,
        Project $project,
        Declaration $model,
        Inputs $generator,
        array $types,
        int $runs,
        int $seed,
    ): void {
        $block = $model->block ?? throw new RuntimeException("$model->name: missing spec block");
        $oracles = self::oracles($project, $block);
        $requires = self::oracle($oracles, $model, $model->requires);
        $refines = self::oracle($oracles, $model, $model->refines);
        $ensures = [];
        foreach ($model->ensures as $label => $spec) {
            $ensures[$label] = self::oracle($oracles, $model, $spec);
        }
        if ($refines === null && $ensures === []) {
            throw new \InvalidArgumentException("$model->name: property checks require refines or ensures");
        }
        $accepted = 0;
        $limit = $runs * 100;
        for ($attempt = 0; $attempt < $limit && $accepted < $runs; $attempt++) {
            try {
                $input = $generator->candidate($types, $attempt);
            } catch (ValidationError) {
                continue;
            }
            if ($requires !== null && !self::predicate($requires(...$input), $model->requires)) {
                continue;
            }
            $accepted++;
            try {
                $actual = $call(...$input);
            } catch (Throwable $cause) {
                $label = $refines === null ? (string) array_key_first($ensures) : 'refines';
                $expected = $refines === null ? true : $refines(...$input);
                throw new PropertyFailure($model->name, $label, $seed, $input, $cause, $expected, $cause);
            }
            if ($refines !== null) {
                $expected = $refines(...$input);
                if (!self::same($actual, $expected)) {
                    throw new PropertyFailure($model->name, 'refines', $seed, $input, $actual, $expected);
                }
            }
            foreach ($ensures as $label => $ensure) {
                $holds = $ensure(...[...$input, $actual]);
                if (!self::predicate($holds, $model->ensures[$label])) {
                    throw new PropertyFailure($model->name, $label, $seed, $input, $actual, true, predicate: false);
                }
            }
        }
        if ($accepted < $runs) {
            throw new RuntimeException(
                "$model->name: collected $accepted of $runs inputs in $limit attempts (seed=$seed)",
            );
        }
    }

    /** @return array<string, Closure> */
    private static function oracles(Project $project, Block $block): array
    {
        $changes = Status::changes($project);
        if ($changes !== []) {
            throw new RuntimeException('Run leanfran sync before testing models. ' . $changes[0]);
        }
        $trait = "$block->name\\Functions";
        if (!trait_exists($trait)) {
            throw new RuntimeException("$trait: generated trait must be available to Composer autoload");
        }
        $facade = new ReflectionClass($trait);
        if ($facade->getFileName() !== "$project->root/$block->output/Functions.php") {
            throw new RuntimeException("$trait: expected the generated trait from $block->output/Functions.php");
        }
        $prefix = "Lean `$block->module.";
        $oracles = [];
        foreach ($facade->getMethods() as $method) {
            $doc = $method->getDocComment();
            if (
                $doc !== false
                && preg_match('~^\h*(?:/\*\*|\*) ' . preg_quote($prefix, '~') . '(.+?) : ~m', $doc, $match) === 1
            ) {
                $oracles[$match[1]] = $method->getClosure();
            }
        }
        return $oracles;
    }

    /**
     * @template T of string|null
     * @param array<string, Closure> $oracles
     * @param T $spec
     * @return (T is null ? null : Closure)
     */
    private static function oracle(array $oracles, Declaration $model, ?string $spec): ?Closure
    {
        return $spec === null
            ? null
            : $oracles[$spec] ?? throw new RuntimeException(
                "$model->name: no generated PHP wrapper for Lean spec $spec",
            );
    }

    private static function predicate(mixed $value, ?string $spec): bool
    {
        return is_bool($value) ? $value : throw new RuntimeException("Lean predicate $spec must return Bool");
    }

    private static function same(mixed $actual, mixed $expected): bool
    {
        if ($actual === $expected) {
            return true;
        }
        if ($actual instanceof \GMP || $expected instanceof \GMP) {
            return (
                (is_int($actual) || $actual instanceof \GMP)
                && (is_int($expected) || $expected instanceof \GMP)
                && gmp_cmp($actual, $expected) === 0
            );
        }
        if (is_object($actual) && is_object($expected) && $actual::class === $expected::class) {
            if ($actual instanceof \UnitEnum) {
                return false;
            }
            return self::same(get_object_vars($actual), get_object_vars($expected));
        }
        if (is_array($actual) && is_array($expected) && array_keys($actual) === array_keys($expected)) {
            foreach ($actual as $key => $value) {
                if (!self::same($value, $expected[$key])) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }
}
