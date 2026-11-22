<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use RuntimeException;

/** Checks the package and installs generated files when the entire batch succeeds. */
final class Sync
{
    /** Synchronizes a Composer project and returns its block count. */
    public static function run(string $dir, ?string $compiler): int
    {
        $root = realpath($dir);
        if ($root === false || !is_file("$root/composer.json")) {
            throw new RuntimeException("no composer.json in $dir");
        }
        $work = "$root/.leanfran";
        $lockPath = "$work/sync.lock";
        if (is_link($work) || is_link($lockPath)) {
            throw new RuntimeException("$work: unexpected symlink in workspace path");
        }
        Files::mkdir($work);
        if (!file_exists("$work/.gitignore") && !is_link("$work/.gitignore")) {
            Files::write("$work/.gitignore", "*\n");
        }
        $lock = @fopen($lockPath, 'c');
        if ($lock === false) {
            throw new RuntimeException("cannot open $lockPath");
        }
        try {
            if (!flock($lock, LOCK_EX)) {
                throw new RuntimeException("cannot lock $lockPath");
            }
            return self::sync(Project::load($root), $compiler);
        } finally {
            fclose($lock);
        }
    }

    private static function sync(Project $project, ?string $compiler): int
    {
        $outputs = array_fill_keys(array_keys(Status::outputs($project)), null);
        foreach ($project->blocks as $block) {
            $outputs[$block->output] = $block;
        }
        self::verify($project, $outputs);
        if ($outputs === []) {
            return 0;
        }
        $stage = $project->root . '/.leanfran/stage-' . bin2hex(random_bytes(8));
        Files::mkdir($stage);
        $cleanup = true;
        try {
            if ($project->blocks !== []) {
                new Workspace($project)->generate(self::compiler($compiler), $stage);
                foreach ($project->blocks as $block) {
                    Manifest::write("$stage/$block->module", $project, $block);
                }
            }
            clearstatcache();
            self::verify($project, $outputs);
            self::install($project, $outputs, $stage, $cleanup);
        } finally {
            if ($cleanup) {
                Files::remove($stage);
            }
        }
        return count($project->blocks);
    }

    private static function compiler(?string $given): string
    {
        $env = getenv('LEANFRAN_PHP_CLI');
        $tool = $given ?? ($env === false ? 'leanfran-php' : $env);
        if ($tool === '') {
            throw new RuntimeException('leanfran-php compiler path is empty');
        }
        if (!str_contains($tool, '/')) {
            return $tool;
        }
        $path = realpath($tool);
        if ($path === false || !is_file($path) || !is_executable($path)) {
            throw new RuntimeException("leanfran-php compiler is not executable: $tool");
        }
        return $path;
    }

    /** @param array<string, Block|null> $outputs */
    private static function verify(Project $project, array $outputs): void
    {
        foreach ($outputs as $dir => $block) {
            try {
                Manifest::generatedFiles("$project->root/$dir");
            } catch (RuntimeException $error) {
                $location = $block === null ? $dir : $block->location();
                throw new RuntimeException("$location: {$error->getMessage()}", previous: $error);
            }
        }
    }

    /** @param array<string, Block|null> $outputs */
    private static function install(Project $project, array $outputs, string $stage, bool &$cleanup): void
    {
        Files::mkdir("$stage/backup");
        $saved = [];
        $placed = [];
        try {
            foreach ($outputs as $dir => $block) {
                $target = "$project->root/$dir";
                if (is_dir($target)) {
                    $backup = "$stage/backup/" . count($saved);
                    Files::move($target, $backup);
                    $saved[$target] = $backup;
                }
                if ($block !== null) {
                    $generated = "$stage/$block->module";
                    Files::move($generated, $target);
                    $placed[$target] = $generated;
                }
            }
        } catch (RuntimeException $error) {
            try {
                foreach (array_reverse($placed, true) as $target => $generated) {
                    Files::move($target, $generated);
                }
                foreach (array_reverse($saved, true) as $target => $backup) {
                    Files::move($backup, $target);
                }
            } catch (RuntimeException $rollback) {
                $cleanup = false;
                throw new RuntimeException(
                    "{$error->getMessage()}\n{$rollback->getMessage()}\nBackups are in $stage",
                    previous: $error,
                );
            }
            throw $error;
        }
    }
}
