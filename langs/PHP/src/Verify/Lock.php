<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\Files;
use Conao3\Leanfran\Embed\Models;
use Conao3\Leanfran\Embed\PhpDocType;
use Conao3\Leanfran\Embed\Project;
use RuntimeException;
use stdClass;

/** Records proof results and checks their inputs without launching the Lean tools. */
final class Lock
{
    public const FILE = 'leanfran.lock';
    public const FORMAT = 1;

    /** Returns the packaged Lean arithmetic and value model. */
    public static function library(): string
    {
        return Files::read(__DIR__ . '/../lean/LeanPhpLib/Php.lean');
    }

    /** Hashes inputs that determine the translated proposition. */
    public static function digest(Project $project, Discover $discovery, string $key): string
    {
        $model = $discovery->models[$key];
        $block = $model->block;
        $inputs = [
            self::FORMAT,
            $project->toolchain,
            hash('sha256', self::library()),
            $model->digest(),
            $block === null ? '' : $project->digest($block),
        ];
        foreach ([
            Translate::class,
            Signature::class,
            Objects::class,
            Type::class,
            Declaration::class,
            Discover::class,
            Models::class,
            PhpDocType::class,
        ] as $class) {
            $file = new \ReflectionClass($class)->getFileName();
            if ($file === false) {
                throw new RuntimeException("missing translator source for $class");
            }
            $inputs[] = hash('sha256', Files::read($file));
        }
        foreach (Translate::BUILTINS as $name => $_) {
            $local = strtolower($model->namespace) . '\\' . $name;
            if (isset($discovery->functions[$local])) {
                $inputs[] = $local;
            }
        }
        return hash('sha256', implode("\n", $inputs));
    }

    /**
     * @param array<string, Declaration> $models
     * @param array<string, array{hash: string, dependencies: list<string>, obligations: array<string, string>}> $entries
     */
    public static function write(Project $project, array $models, array $entries): void
    {
        $target = $project->root . '/' . self::FILE;
        if ($models === [] && !is_file($target)) {
            return;
        }
        $temp = $project->root . '/.leanfran/lock-' . bin2hex(random_bytes(8));
        try {
            Files::write($temp, json_encode((object) $entries, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR) . "\n");
            Files::move($temp, $target);
        } finally {
            if (is_file($temp)) {
                Files::remove($temp);
            }
        }
    }

    /** Prints saved proof statuses and returns whether they are current. */
    public static function status(Project $project): bool
    {
        $discovery = Discover::project($project);
        $models = $discovery->models;
        $path = $project->root . '/' . self::FILE;
        $lock = is_file($path) ? Files::json($path) : new stdClass();
        if (!$lock instanceof stdClass) {
            throw new RuntimeException("$path: expected an object");
        }
        $current = true;
        $fresh = [];
        foreach ($models as $key => $model) {
            $unchanged = self::fresh($project, $discovery, $lock, $key, $fresh);
            $entry = $lock->$key ?? null;
            $states =
                $entry instanceof stdClass && ($entry->obligations ?? null) instanceof stdClass
                    ? get_object_vars($entry->obligations)
                    : [];
            $labels = $model->labels();
            if ($labels === [] && isset($states['model'])) {
                $labels = ['model'];
            }
            foreach ($labels as $label) {
                $saved = $states[$label] ?? null;
                $state = $unchanged && is_string($saved) ? $saved : 'stale';
                $current = $current && $state !== 'stale';
                fwrite(STDOUT, "$model->name $label: $state\n");
            }
        }
        foreach (array_diff_key(get_object_vars($lock), $models) as $name => $_) {
            fwrite(STDOUT, "$name: stale (model removed)\n");
            $current = false;
        }
        return $current;
    }

    /**
     * @param array<string, bool> $fresh
     */
    private static function fresh(
        Project $project,
        Discover $discovery,
        stdClass $lock,
        string $key,
        array &$fresh,
    ): bool {
        if (isset($fresh[$key])) {
            return $fresh[$key];
        }
        $entry = $lock->$key ?? null;
        $fresh[$key] = false;
        if (
            !isset($discovery->models[$key])
            || !$entry instanceof stdClass
            || ($entry->hash ?? null) !== self::digest($project, $discovery, $key)
            || !is_array($entry->dependencies ?? null)
        ) {
            return false;
        }
        foreach ($entry->dependencies as $dependency) {
            if (!is_string($dependency) || !self::fresh($project, $discovery, $lock, $dependency, $fresh)) {
                return false;
            }
        }
        return $fresh[$key] = true;
    }
}
