<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Lean;
use RuntimeException;
use stdClass;

/** A generated block's inputs and owned PHP files. */
final readonly class Manifest
{
    public const FILE = 'leanfran.json';
    private const FORMAT = 'leanfran-php-embed';

    /** @param non-empty-list<string> $files */
    private function __construct(
        public string $block,
        public string $hash,
        public string $version,
        public array $files,
    ) {}

    /** Reads a valid embedding manifest, if present. */
    public static function read(string $dir, bool $discover = false): ?self
    {
        $path = "$dir/" . self::FILE;
        if (!file_exists($path) && !is_link($path)) {
            return null;
        }
        if (!is_file($path) || is_link($path)) {
            throw new RuntimeException("invalid embedding manifest: $path");
        }
        try {
            $data = Files::json($path);
        } catch (RuntimeException $error) {
            if ($discover) {
                return null;
            }
            throw $error;
        }
        if ($discover && (!$data instanceof stdClass || ($data->format ?? null) !== self::FORMAT)) {
            return null;
        }
        if (
            !$data instanceof stdClass
            || ($data->format ?? null) !== self::FORMAT
            || !is_string($data->block ?? null)
            || $data->block === ''
            || !is_string($data->hash ?? null)
            || !preg_match('/^[0-9a-f]{64}$/D', $data->hash)
            || !is_string($data->generator_version ?? null)
            || !is_array($data->files ?? null)
            || !array_is_list($data->files)
            || $data->files === []
        ) {
            throw new RuntimeException("invalid embedding manifest: $path");
        }
        $files = [];
        foreach ($data->files as $file) {
            if (!is_string($file) || !preg_match('~^(?:Internal/)?[^/\\\\]+\.php$~D', $file)) {
                throw new RuntimeException("invalid generated file path in $path");
            }
            $files[] = $file;
        }
        return new self($data->block, $data->hash, $data->generator_version, $files);
    }

    /** Records a newly generated block. */
    public static function write(string $dir, Project $project, Block $block): void
    {
        $files = self::generatedFiles($dir);
        if (
            !in_array('Functions.php', $files, true)
            || !in_array('Internal/Lean' . basename($block->output) . '.php', $files, true)
        ) {
            throw new RuntimeException($block->location() . ': incomplete generator output');
        }
        sort($files, SORT_STRING);
        Files::write(
            "$dir/" . self::FILE,
            json_encode(
                [
                    'format' => self::FORMAT,
                    'block' => $block->name,
                    'hash' => $project->digest($block),
                    'generator_version' => Lean::GENERATOR_VERSION,
                    'files' => $files,
                ],
                JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES,
            )
                . "\n",
        );
    }

    /**
     * Reads an output directory and rejects unmanaged entries before replacing it.
     *
     * @return list<string>
     */
    public static function generatedFiles(string $dir): array
    {
        if (!file_exists($dir) && !is_link($dir)) {
            return [];
        }
        if (!is_dir($dir) || is_link($dir)) {
            throw new RuntimeException("output path is not a directory: $dir");
        }
        $files = [];
        foreach (Files::entries($dir) as $path) {
            $name = basename($path);
            if ($name === self::FILE && self::read($dir) !== null) {
                continue;
            }
            if ($name === 'Internal' && is_dir($path) && !is_link($path)) {
                foreach (Files::entries($path) as $child) {
                    if (!Files::generated($child)) {
                        throw new RuntimeException("non-generated entry in output directory: $child");
                    }
                    $files[] = 'Internal/' . basename($child);
                }
            } elseif (Files::generated($path)) {
                $files[] = $name;
            } else {
                throw new RuntimeException("non-generated entry in output directory: $path");
            }
        }
        return $files;
    }
}
