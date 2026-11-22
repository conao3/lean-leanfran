<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Lean;

/** Checks generated output without invoking the Lean toolchain. */
final class Status
{
    /**
     * Finds outputs, including directories omitted by a new scan configuration.
     *
     * @return array<string, string>
     */
    public static function outputs(Project $project): array
    {
        $outputs = [];
        foreach (Files::walk($project->root, stopAtPackages: true) as $file) {
            $name = basename($file);
            $dir = dirname($file);
            if ($dir === $project->root) {
                continue;
            }
            $path = substr($dir, strlen($project->root) + 1);
            if ($name === Manifest::FILE) {
                $manifest = Manifest::read($dir, discover: true);
                if ($manifest !== null && self::owns($dir, $manifest->block)) {
                    $outputs[$path] = $manifest->block;
                }
            } elseif ($name === 'Functions.php' && !isset($outputs[$path])) {
                $header = Files::generatedHeader($file);
                if (
                    $header !== null
                    && preg_match('/from LeanPhpEmbed\.B((?:[0-9a-f]{2})+)\. Do not edit\./', $header, $match)
                ) {
                    $block = hex2bin($match[1]);
                    if ($block !== false && self::owns($dir, $block)) {
                        $outputs[$path] = $block;
                    }
                }
            }
        }
        ksort($outputs, SORT_STRING);
        return $outputs;
    }

    private static function owns(string $dir, string $block): bool
    {
        return basename($dir) === substr($block, (int) strrpos('\\' . $block, '\\'));
    }

    /**
     * Reports stale inputs, removed blocks and missing generated files.
     *
     * @return list<string>
     */
    public static function changes(Project $project): array
    {
        $old = self::outputs($project);
        $changes = [];
        foreach ($project->blocks as $block) {
            $manifest = Manifest::read("$project->root/$block->output");
            if ($manifest === null) {
                $changes[] = "$block->name: missing manifest ($block->output/" . Manifest::FILE . ')';
                if (($old[$block->output] ?? null) === $block->name) {
                    unset($old[$block->output]);
                }
                continue;
            }
            if (
                $manifest->block !== $block->name
                || $manifest->version !== Lean::GENERATOR_VERSION
                || $manifest->hash !== $project->digest($block)
            ) {
                $changes[] = "$block->name: stale";
            }
            foreach ($manifest->files as $file) {
                $path = "$block->output/$file";
                if (
                    is_link("$project->root/$block->output")
                    || is_link("$project->root/" . dirname($path))
                    || !Files::generated("$project->root/$path")
                ) {
                    $changes[] = "$block->name: missing generated file ($path)";
                }
            }
            if ($manifest->block === $block->name) {
                unset($old[$block->output]);
            }
        }
        foreach ($old as $dir => $block) {
            $changes[] = "$block: removed ($dir)";
        }
        return $changes;
    }
}
