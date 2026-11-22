<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use RuntimeException;

/** Result of a subprocess used by sync. */
final readonly class Process
{
    private function __construct(
        public int $status,
        public string $stdout,
        public string $stderr,
    ) {}

    /** @param non-empty-list<string> $command */
    public static function run(array $command, string $cwd): self
    {
        $stdout = tmpfile();
        $stderr = tmpfile();
        try {
            if ($stdout === false || $stderr === false) {
                throw new RuntimeException('cannot open subprocess output files');
            }
            $process = @proc_open($command, [0 => ['pipe', 'r'], 1 => $stdout, 2 => $stderr], $pipes, $cwd);
            if ($process === false) {
                throw new RuntimeException("cannot run $command[0]");
            }
            fclose($pipes[0]);
            $status = proc_close($process);
            rewind($stdout);
            rewind($stderr);
            $out = stream_get_contents($stdout);
            $err = stream_get_contents($stderr);
            if ($out === false || $err === false) {
                throw new RuntimeException("cannot read output of $command[0]");
            }
            return new self($status, $out, $err);
        } finally {
            if ($stdout !== false) {
                fclose($stdout);
            }
            if ($stderr !== false) {
                fclose($stderr);
            }
        }
    }

    /** Reports a failed command with its output. */
    public function check(string $label): void
    {
        if ($this->status !== 0) {
            throw new RuntimeException(
                "$label failed (exit $this->status)\n" . trim($this->stdout . "\n" . $this->stderr),
            );
        }
    }
}
