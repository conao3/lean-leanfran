<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Lean;
use Conao3\Leanfran\Verify\Check;
use JsonException;
use Throwable;

/** Entry point that `leanfran --lang php sync|check|status` runs in the project to read its sources. */
final class Cli
{
    private const USAGE = <<<'USAGE'
        usage: php vendor/conao3/leanfran/bin/leanfran scan --root <root> --dir <dir>
               php vendor/conao3/leanfran/bin/leanfran translate --root <root>

        Run leanfran --lang php sync, leanfran --lang php check or leanfran --lang php status
        in the Composer project; they start these commands.
        USAGE;

    private const INSTALL = "install the compiler of this release with nix profile install 'github:conao3/lean-leanfran/v%s#leanfran'";

    /** @param list<string> $args */
    public static function run(array $args): int
    {
        $command = array_shift($args);
        if (in_array($command, [null, '-h', '--help'], true)) {
            fwrite(STDOUT, self::USAGE . "\n");
            return 0;
        }
        $root = self::root($command, $args);
        if ($root === null) {
            fwrite(STDERR, self::USAGE . "\n");
            return 252;
        }
        $error = self::versions();
        if ($error !== null) {
            fwrite(STDERR, "leanfran-php: $error\n");
            return 255;
        }
        try {
            if ($command === 'scan') {
                $result = Scan::run($root);
            } else {
                json_decode((string) stream_get_contents(STDIN), flags: JSON_THROW_ON_ERROR);
                $result = Check::run($root);
            }
            fwrite(
                STDOUT,
                json_encode($result, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n",
            );
            return 0;
        } catch (EnvironmentError $error) {
            fwrite(STDERR, $error->getMessage() . "\n");
            return 255;
        } catch (JsonException $error) {
            fwrite(STDERR, "leanfran-php $command: {$error->getMessage()}\n");
            return 255;
        } catch (Throwable $error) {
            fwrite(STDERR, $error->getMessage() . "\n");
            return 254;
        }
    }

    /** @param list<string> $args */
    private static function root(string $command, array $args): ?string
    {
        $flags = match ($command) {
            'scan' => ['--root', '--dir'],
            'translate' => ['--root'],
            default => null,
        };
        if ($flags === null || count($args) !== (2 * count($flags))) {
            return null;
        }
        $options = [];
        while ($args !== []) {
            $flag = array_shift($args);
            $value = array_shift($args);
            if (!in_array($flag, $flags, true) || isset($options[$flag]) || $value === null || $value === '') {
                return null;
            }
            $options[$flag] = $value;
        }
        return $options['--root'] ?? null;
    }

    private static function versions(): ?string
    {
        $install = sprintf(self::INSTALL, Lean::VERSION);
        foreach ([
            [
                'LEANFRAN_VERSION',
                'release version',
                Lean::VERSION,
                'use a compiler from the release of conao3/leanfran or update conao3/leanfran to the release of the compiler',
            ],
            [
                'LEANFRAN_GENERATOR_VERSION',
                'generator version',
                Lean::GENERATOR_VERSION,
                'rebuild the compiler from the source revision of conao3/leanfran',
            ],
            [
                'LEANFRAN_LEAN_VERSION',
                'Lean version',
                Lean::LEAN_VERSION,
                'use a compiler built with the Lean version of the release of conao3/leanfran',
            ],
        ] as [$variable, $name, $expected, $fix]) {
            $actual = getenv($variable);
            if ($actual === false || $actual === '') {
                return 'run leanfran --lang php sync, check or status in the Composer project';
            }
            if ($actual !== $expected) {
                return "compiler $name \"$actual\", expected $expected; $fix, or $install";
            }
        }
        return null;
    }
}
