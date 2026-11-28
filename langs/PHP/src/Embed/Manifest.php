<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use RuntimeException;
use stdClass;

/** The `php` section of the project's leanfran.manifest.json, which `leanfran --lang php sync` writes. */
final readonly class Manifest
{
    public const FILE = 'leanfran.manifest.json';

    /**
     * @param list<mixed> $require
     * @param array<string, array{hash: string, files: list<string>}> $blocks
     * @param list<string> $files
     */
    private function __construct(
        public string $compiler,
        public array $require,
        public string $inputs,
        public string $support,
        public array $blocks,
        public array $files,
    ) {}

    /** Reads the `php` section, if the manifest has one. */
    public static function read(string $root): ?self
    {
        $path = "$root/" . self::FILE;
        if (!is_file($path)) {
            return null;
        }
        $data = Files::json($path);
        $languages = $data instanceof stdClass ? $data->languages ?? null : null;
        $section = $languages instanceof stdClass ? $languages->php ?? null : null;
        if ($section === null) {
            return null;
        }
        if (
            !$section instanceof stdClass
            || !is_string($section->compiler ?? null)
            || !is_array($section->require ?? null)
            || !is_string($section->inputs ?? null)
            || !is_string($section->support ?? null)
            || !is_array($section->blocks ?? null)
            || !is_array($section->files ?? null)
        ) {
            throw new RuntimeException("$path: invalid php section");
        }
        $blocks = [];
        foreach ($section->blocks as $entry) {
            if (!$entry instanceof stdClass || !is_string($entry->name ?? null) || !is_string($entry->hash ?? null)) {
                throw new RuntimeException("$path: invalid block in the php section");
            }
            $blocks[$entry->name] = ['hash' => $entry->hash, 'files' => self::paths($path, $entry->files ?? null)];
        }
        return new self(
            $section->compiler,
            array_values($section->require),
            $section->inputs,
            $section->support,
            $blocks,
            self::paths($path, $section->files),
        );
    }

    /**
     * Lists every generated file of the section.
     *
     * @return list<string>
     */
    public function files(): array
    {
        $files = $this->files;
        foreach ($this->blocks as $entry) {
            array_push($files, ...$entry['files']);
        }
        return $files;
    }

    /** Encodes a JSON value with object keys in order, as `sync` compares requirements. */
    public static function canonical(mixed $value): string
    {
        return json_encode(self::sorted($value), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    }

    private static function sorted(mixed $value): mixed
    {
        if ($value instanceof stdClass) {
            $fields = get_object_vars($value);
            ksort($fields, SORT_STRING);
            return (object) array_map(self::sorted(...), $fields);
        }
        return is_array($value) ? array_map(self::sorted(...), $value) : $value;
    }

    /** @return list<string> */
    private static function paths(string $path, mixed $files): array
    {
        if (!is_array($files)) {
            throw new RuntimeException("$path: invalid file list in the php section");
        }
        $paths = [];
        foreach ($files as $file) {
            if (!is_string($file)) {
                throw new RuntimeException("$path: invalid file list in the php section");
            }
            $paths[] = $file;
        }
        return $paths;
    }
}
