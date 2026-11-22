<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use RuntimeException;
use Throwable;

/** Entry point for the Composer binary. */
final class Cli
{
    private const USAGE = <<<'USAGE'
        Usage:
          leanfran sync [--package dir] [--leanfran-php path]
          leanfran status [--package dir]
          leanfran check [--package dir] [--leanfran-php path]
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
                    $option !== '--package' && ($command === 'status' || $option !== '--leanfran-php')
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
            if ($command !== 'status') {
                $count = Sync::run($dir, $options['--leanfran-php'] ?? null);
                $noun = $count === 1 ? 'block' : 'blocks';
                fwrite(STDOUT, "leanfran: $count $noun checked and generated\n");
            }
            if ($command !== 'sync') {
                $changes = Status::changes(Project::load($dir));
                foreach ($changes as $line) {
                    fwrite(STDOUT, "$line\n");
                }
                if ($changes !== []) {
                    return 1;
                }
                fwrite(STDOUT, "leanfran: all blocks up to date\n");
            }
            return 0;
        } catch (Throwable $error) {
            fwrite(STDERR, $error->getMessage() . "\n");
            return 1;
        }
    }
}
