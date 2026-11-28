<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Lean;
use stdClass;

/** Checks generated output without invoking the Lean toolchain. */
final class Status
{
    private const OLD_MANIFEST = 'leanfran.json';

    /**
     * Lists earlier generated files that leanfran.manifest.json does not track: the old per-class
     * manifests and the generated files of output directories that no current block owns.
     *
     * @return list<string>
     */
    public static function stray(Project $project): array
    {
        $tracked = array_fill_keys(Manifest::read($project->root)?->files() ?? [], true);
        $current = [];
        foreach ($project->blocks as $block) {
            $current[$block->output] = true;
        }
        $outputs = [];
        $stray = [];
        foreach (Files::walk($project->root, stopAtPackages: true) as $file) {
            $dir = dirname($file);
            if ($dir === $project->root) {
                continue;
            }
            $path = substr($dir, strlen($project->root) + 1);
            $block = match (basename($file)) {
                self::OLD_MANIFEST => self::oldManifest($file),
                'Functions.php' => self::facade($file),
                default => null,
            };
            if ($block === null || !self::owns($dir, $block)) {
                continue;
            }
            $outputs[$path] = true;
            if (basename($file) === self::OLD_MANIFEST) {
                $stray[] = "$path/" . self::OLD_MANIFEST;
            }
        }
        foreach (array_keys($outputs) as $path) {
            if (isset($current[$path])) {
                continue;
            }
            foreach (self::generated("$project->root/$path") as $file) {
                if (!isset($tracked["$path/$file"])) {
                    $stray[] = "$path/$file";
                }
            }
        }
        $stray = array_values(array_unique($stray));
        sort($stray, SORT_STRING);
        return $stray;
    }

    /**
     * Reports stale inputs, removed blocks and missing generated files recorded in leanfran.manifest.json.
     *
     * @return list<string>
     */
    public static function changes(Project $project): array
    {
        $manifest = Manifest::read($project->root);
        $fresh =
            $manifest !== null
            && $manifest->compiler === Lean::GENERATOR_VERSION . '/' . Lean::LEAN_VERSION
            && Manifest::canonical($manifest->require) === Manifest::canonical($project->requirements)
            && $manifest->inputs === ''
            && $manifest->support === '';
        $changes = [];
        $names = [];
        foreach ($project->blocks as $block) {
            $names[$block->name] = true;
            $entry = $manifest?->blocks[$block->name] ?? null;
            if ($entry === null || !$fresh || $entry['hash'] !== $project->digest($block)) {
                $changes[] = "$block->name: stale";
            }
            foreach ($entry['files'] ?? [] as $file) {
                if (!is_file("$project->root/$file")) {
                    $changes[] = "$block->name: missing $file";
                }
            }
        }
        foreach ($manifest->files ?? [] as $file) {
            if (!is_file("$project->root/$file")) {
                $changes[] = "php: missing $file";
            }
        }
        foreach (array_keys($manifest->blocks ?? []) as $name) {
            if (!isset($names[$name])) {
                $changes[] = "$name: removed";
            }
        }
        sort($changes, SORT_STRING);
        return $changes;
    }

    private static function owns(string $dir, string $block): bool
    {
        return basename($dir) === substr($block, (int) strrpos('\\' . $block, '\\'));
    }

    private static function oldManifest(string $file): ?string
    {
        if (is_link($file) || !is_file($file)) {
            return null;
        }
        $data = json_decode((string) @file_get_contents($file));
        return
            $data instanceof stdClass
            && ($data->format ?? null) === 'leanfran-php-embed'
            && is_string($data->block ?? null)
            && $data->block !== ''
                ? $data->block
                : null;
    }

    private static function facade(string $file): ?string
    {
        $header = Files::generatedHeader($file);
        if (
            $header === null
            || !preg_match('/from LeanPhpEmbed\.B((?:[0-9a-f]{2})+)\. Do not edit\./', $header, $match)
        ) {
            return null;
        }
        $block = hex2bin($match[1]);
        return $block === false ? null : $block;
    }

    /** @return list<string> */
    private static function generated(string $dir): array
    {
        $files = [];
        foreach (Files::entries($dir) as $path) {
            $name = basename($path);
            if ($name === 'Internal' && is_dir($path) && !is_link($path)) {
                foreach (Files::entries($path) as $child) {
                    if (Files::generated($child)) {
                        $files[] = 'Internal/' . basename($child);
                    }
                }
            } elseif (Files::generated($path)) {
                $files[] = $name;
            }
        }
        return $files;
    }
}
