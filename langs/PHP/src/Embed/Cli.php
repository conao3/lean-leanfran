<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Verify\Check;
use Conao3\Leanfran\Verify\Lock;
use RuntimeException;
use Throwable;

/** Entry point for the Composer binary. */
final class Cli
{
    private const USAGE = <<<'USAGE'
        Usage:
          leanfran sync [--package dir] [--leanfran-php path]
          leanfran status [--package dir]
          leanfran check [--package dir] [--leanfran-php path] [--require proved]
        USAGE;

    /** @param list<string> $args */
    public static function run(array $args): int
    {
        try {
            $command = array_shift($args);
            if (in_array($command, [null, '-h', '--help'], true) || $args === ['--help']) {
                fwrite(STDOUT, self::USAGE . "\n");
                return 0;
            }
            if (!in_array($command, ['sync', 'status', 'check'], true)) {
                throw new RuntimeException("unknown leanfran command: $command");
            }
            $options = [];
            while ($args !== []) {
                $option = array_shift($args);
                if (
                    !in_array(
                        $option,
                        match ($command) {
                            'sync' => ['--package', '--leanfran-php'],
                            'check' => ['--package', '--leanfran-php', '--require'],
                            default => ['--package'],
                        },
                        true,
                    )
                    || isset($options[$option])
                ) {
                    throw new RuntimeException("invalid option for $command: $option");
                }
                $value = array_shift($args);
                if ($value === null || $value === '' || str_starts_with($value, '--')) {
                    throw new RuntimeException("expected a value for $option");
                }
                $options[$option] = $value;
            }
            $dir = $options['--package'] ?? '.';
            $compiler = $options['--leanfran-php'] ?? null;
            $require = $options['--require'] ?? null;
            if ($require !== null && $require !== 'proved') {
                throw new RuntimeException('--require expects proved');
            }
            if ($command === 'sync') {
                self::count(Sync::run($dir, $compiler));
                return 0;
            }
            if ($command === 'check') {
                return Sync::run($dir, $compiler, static function (Project $project, ?string $tool, int $count) use (
                    $require,
                ): int {
                    self::count($count);
                    $result = Check::run($project, Sync::compiler($tool), $require !== null);
                    return self::blockStatus($project) ? $result : 1;
                });
            }
            $project = Project::load($dir);
            $fresh = Lock::status($project);
            return self::blockStatus($project) && $fresh ? 0 : 1;
        } catch (Throwable $error) {
            fwrite(STDERR, $error->getMessage() . "\n");
            return 1;
        }
    }

    private static function count(int $count): void
    {
        $noun = $count === 1 ? 'block' : 'blocks';
        fwrite(STDOUT, "leanfran: $count $noun checked and generated\n");
    }

    private static function blockStatus(Project $project): bool
    {
        $changes = Status::changes($project);
        foreach ($changes as $line) {
            fwrite(STDOUT, "$line\n");
        }
        if ($changes === []) {
            fwrite(STDOUT, "leanfran: all blocks up to date\n");
        }
        return $changes === [];
    }
}
