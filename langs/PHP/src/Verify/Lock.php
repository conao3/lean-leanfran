<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\Files;
use Conao3\Leanfran\Embed\Models;
use Conao3\Leanfran\Embed\PhpDocType;
use Conao3\Leanfran\Embed\Project;
use RuntimeException;

/** Hashes the inputs that `leanfran --lang php status` compares with leanfran.lock. */
final class Lock
{
    /** Hashes a model's declaration and the block that holds its specs. */
    public static function digest(Project $project, Discover $discovery, string $key): string
    {
        $model = $discovery->models[$key];
        $block = $model->block;
        return hash('sha256', implode("\n", [$model->digest(), $block === null ? '' : $project->digest($block)]));
    }

    /** Hashes the translator sources and the project functions that shadow the modeled built-ins. */
    public static function inputs(Discover $discovery): string
    {
        $inputs = [];
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
        $shadowed = [];
        foreach ($discovery->models as $model) {
            foreach (Translate::BUILTINS as $name => $_) {
                $local = strtolower($model->namespace) . '\\' . $name;
                if (isset($discovery->functions[$local])) {
                    $shadowed[$local] = true;
                }
            }
        }
        ksort($shadowed, SORT_STRING);
        return hash('sha256', implode("\n", [...$inputs, ...array_keys($shadowed)]));
    }
}
