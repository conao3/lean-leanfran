<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

final class ProcessPipes
{
    /**
     * @param array<int, resource> $streams
     * @param array<int, string> $buffers
     * @param array<int, int> $offsets
     */
    public function __construct(
        private array $streams = [],
        private array $buffers = [],
        private array $offsets = [],
    ) {}

    /** @param resource $stream */
    public function add(int $fd, mixed $stream): void
    {
        ioNative(static fn() => stream_set_blocking($stream, false));
        if ($fd !== 0) {
            $this->streams[$fd] = $stream;
            $this->buffers[$fd] = '';
            $this->offsets[$fd] = 0;
        }
    }

    public function discard(int $fd): void
    {
        unset($this->streams[$fd], $this->buffers[$fd], $this->offsets[$fd]);
    }

    public function read(int $fd, ?int $count): string
    {
        $start = $this->offsets[$fd];
        $scan = $start;
        while (true) {
            $end = strlen($this->buffers[$fd]);
            if ($count === null && $scan < $end) {
                $newline = strpos($this->buffers[$fd], "\n", $scan);
                if ($newline !== false) {
                    return $this->take($fd, $newline + 1 - $start);
                }
                $scan = $end;
            }
            if ($count !== null && ($end - $start) >= $count) {
                return $this->take($fd, $count);
            }
            if (!isset($this->streams[$fd])) {
                return $this->take($fd, $end - $start);
            }
            $this->pump();
        }
    }

    private function take(int $fd, int $count): string
    {
        $start = $this->offsets[$fd];
        $chunk = substr($this->buffers[$fd], $start, $count);
        $end = $start + $count;
        $length = strlen($this->buffers[$fd]);
        if ($end === $length || $end >= 65536 && $end >= ($length - $end)) {
            $this->buffers[$fd] = substr($this->buffers[$fd], $end);
            $end = 0;
        }
        $this->offsets[$fd] = $end;
        return $chunk;
    }

    /** @param resource|null $writer */
    public function pump(mixed $writer = null, ?int $timeoutMicros = null): bool
    {
        $read = $this->streams;
        $write = $writer === null ? [] : [$writer];
        if ($read === [] && $write === []) {
            if ($timeoutMicros !== null) {
                usleep($timeoutMicros);
            }
            return false;
        }
        $except = null;
        ioNative(static function () use (&$read, &$write, &$except, $timeoutMicros): int|false {
            return stream_select($read, $write, $except, $timeoutMicros === null ? null : 0, $timeoutMicros);
        });
        foreach ($read as $fd => $stream) {
            $this->buffers[$fd] .= ioNative(static fn() => fread($stream, 65536));
            if (feof($stream)) {
                unset($this->streams[$fd]);
            }
        }
        return $write !== [];
    }
}

final class IoProcess
{
    private bool $reaped = false;

    /** @param resource $process */
    public function __construct(
        private readonly mixed $process,
        private readonly ProcessPipes $pipes,
        public readonly int $pid,
        private readonly bool $setsid,
    ) {}

    /** @return ($blocking is true ? int : int|null) */
    public function wait(bool $blocking): ?int
    {
        if ($this->reaped && PHP_OS_FAMILY !== 'Windows') {
            throw new IoFailure(ioDecodeError(10));
        }
        while (true) {
            $status = ioNative(fn() => proc_get_status($this->process));
            if (!$status['running']) {
                $this->reaped = true;
                return $status['signaled'] ? 128 + $status['termsig'] : $status['exitcode'];
            }
            if (!$blocking) {
                return null;
            }
            $this->pipes->pump(timeoutMicros: 10000);
        }
    }

    public function kill(): void
    {
        if ($this->setsid) {
            ioNative(fn() => posix_kill(-$this->pid, 9), failure: 'ESRCH');
        } elseif ($this->reaped && PHP_OS_FAMILY !== 'Windows') {
            ioFailure('ESRCH');
        } else {
            ioNative(fn() => proc_terminate($this->process, 9), failure: 'ESRCH');
        }
    }
}

function ioProcessString(LString $value): string
{
    return explode("\0", $value->s, 2)[0];
}

/** @param array<string, string> $environment */
function ioProcessExecutable(string $command, string $cwd, array $environment): ?string
{
    if ($command === '') {
        return null;
    }
    $paths = str_contains($command, '/') ? [''] : explode(PATH_SEPARATOR, $environment['PATH'] ?? '/bin:/usr/bin');
    foreach ($paths as $directory) {
        $path = $directory === '' ? $command : $directory . '/' . $command;
        if (!str_starts_with($path, '/')) {
            $path = $cwd . '/' . $path;
        }
        clearstatcache(true, $path);
        if (@is_file($path) && @is_executable($path)) {
            return $path;
        }
    }
    return null;
}

/**
 * @param non-empty-list<string> $argv
 * @param array<string, string> $environment
 * @return array{non-empty-list<string>, ?string}
 */
function ioProcessLaunch(array $argv, ?string $cwd, array $environment, bool $setsid): array
{
    if (PHP_OS_FAMILY === 'Windows') {
        return [$argv, $cwd];
    }

    $effectiveCwd = $cwd === null ? @getcwd() : @realpath($cwd);
    $failure = null;
    if ($effectiveCwd === false || !@is_dir($effectiveCwd) || !@is_executable($effectiveCwd)) {
        $failure = 'could not change directory to ' . $cwd;
    } else {
        $executable = ioProcessExecutable($argv[0], $effectiveCwd, $environment);
        if ($executable === null) {
            $failure = "could not execute external process '" . $argv[0] . "'";
        } else {
            $argv[0] = $executable;
        }
    }
    if ($failure !== null) {
        return [[PHP_BINARY, '-n', '-r', 'fwrite(STDERR, $argv[1] . "\\n"); exit(255);', '--', $failure], null];
    }
    if ($setsid) {
        if (!function_exists('posix_setsid') || !function_exists('pcntl_exec')) {
            ioFailure('ENOSYS');
        }
        $script = <<<'CODE'
            if (posix_setsid() < 0) {
                fwrite(STDERR, "could not start a new session\n");
                exit(255);
            }
            @pcntl_exec($argv[1], array_slice($argv, 2));
            fwrite(STDERR, "could not execute external process '" . $argv[1] . "'\n");
            exit(255);
            CODE;
        $argv = [PHP_BINARY, '-r', $script, '--', ...$argv];
    }
    return [$argv, $cwd];
}

function lean_io_process_spawn(Ctor $args): Ctor
{
    $result = ioAttempt(static function () use ($args): Ctor {
        $config = requireRuntimeObject($args->objs[0], Ctor::class);
        $command = requireRuntimeObject($args->objs[1], LString::class);
        $arguments = requireRuntimeObject($args->objs[2], LArray::class);
        $workdir = $args->objs[3];
        $edits = requireRuntimeObject($args->objs[4], LArray::class);
        $environment = $args->sc[40] === 1 ? getenv() : [];
        foreach ($edits->a as $pair) {
            $edit = requireRuntimeObject($pair, Ctor::class);
            $key = ioProcessString(requireRuntimeObject($edit->objs[0], LString::class));
            $value = $edit->objs[1];
            if ($value instanceof Ctor) {
                if ($key === '' || str_contains($key, '=')) {
                    ioFailure('EINVAL');
                }
                $environment[$key] = ioProcessString(requireRuntimeObject($value->objs[0], LString::class));
            } else {
                unset($environment[$key]);
            }
        }
        $argv = [ioProcessString($command)];
        foreach ($arguments->a as $argument) {
            $argv[] = ioProcessString(requireRuntimeObject($argument, LString::class));
        }
        $cwd = $workdir instanceof Ctor
            ? ioProcessString(requireRuntimeObject($workdir->objs[0], LString::class))
            : null;
        $setsid = $args->sc[41] === 1 && PHP_OS_FAMILY !== 'Windows';
        [$argv, $cwd] = ioProcessLaunch($argv, $cwd, $environment, $setsid);
        $descriptors = [];
        foreach ([STDIN, STDOUT, STDERR] as $fd => $std) {
            $descriptors[$fd] = match ($config->sc[$fd]) {
                0 => ['pipe', $fd === 0 ? 'r' : 'w'],
                1 => $std,
                2 => ['file', PHP_OS_FAMILY === 'Windows' ? 'NUL' : '/dev/null', $fd === 0 ? 'r' : 'w'],
                default => ioFailure('EINVAL'),
            };
        }
        @fflush(STDOUT);
        @fflush(STDERR);
        $piped = [];
        $process = ioNative(static function () use ($argv, $descriptors, &$piped, $cwd, $environment) {
            return proc_open($argv, $descriptors, $piped, $cwd, $environment, ['bypass_shell' => true]);
        });
        $pipes = new ProcessPipes();
        $objects = [0, 0, 0];
        try {
            foreach ($piped as $fd => $stream) {
                $pipes->add($fd, $stream);
                $objects[$fd] = ioHandle($stream, $fd !== 0, $fd === 0, true, $pipes, $fd);
            }
            $status = ioNative(static fn() => proc_get_status($process));
        } catch (IoFailure $error) {
            foreach ($piped as $stream) {
                @fclose($stream);
            }
            @proc_terminate($process, 9);
            @proc_close($process);
            throw $error;
        }
        $objects[] = new IoProcess($process, $pipes, $status['pid'], $setsid);
        return new Ctor(0, $objects);
    });
    lean_dec($args);
    return $result;
}

function lean_io_process_child_wait(Ctor $config, Ctor $child): Ctor
{
    return ioAttempt(static fn() => requireRuntimeObject($child->objs[3], IoProcess::class)->wait(true));
}

function lean_io_process_child_try_wait(Ctor $config, Ctor $child): Ctor
{
    return ioAttempt(static function () use ($child): Ctor|int {
        $status = requireRuntimeObject($child->objs[3], IoProcess::class)->wait(false);
        return $status === null ? 0 : new Ctor(1, [$status]);
    });
}

function lean_io_process_child_kill(Ctor $config, Ctor $child): Ctor
{
    return ioAttempt(static function () use ($child): int {
        requireRuntimeObject($child->objs[3], IoProcess::class)->kill();
        return 0;
    });
}

function lean_io_process_child_pid(Ctor $config, Ctor $child): int
{
    $pid = requireRuntimeObject($child->objs[3], IoProcess::class)->pid;
    lean_dec($child);
    lean_dec($config);
    return $pid;
}

function lean_io_process_child_take_stdin(Ctor $config, Ctor $child): Ctor
{
    [$in, $out, $err, $process] = $child->objs;
    lean_inc($in);
    lean_inc($out);
    lean_inc($err);
    lean_dec($child);
    return lean_io_result_mk_ok(new Ctor(0, [$in, new Ctor(0, [0, $out, $err, $process])]));
}

function lean_io_process_get_current_dir(): Ctor
{
    return ioAttempt(static fn() => ioString(ioNative(getcwd(...), failure: 'ENOENT')));
}

function lean_io_current_dir(): Ctor
{
    $cwd = @getcwd();
    return $cwd === false
        ? lean_io_result_mk_error(lean_mk_io_user_error(new LString('failed to retrieve current working directory')))
        : lean_io_result_mk_ok(ioString($cwd));
}

function lean_io_process_set_current_dir(LString $path): Ctor
{
    return ioPathAction($path, chdir(...));
}

function lean_io_app_path(): Ctor
{
    $path = @realpath(PHP_BINARY);
    return $path === false
        ? lean_io_result_mk_error(lean_mk_io_user_error(new LString('failed to locate application')))
        : lean_io_result_mk_ok(ioString($path));
}

function lean_io_getenv(LString $name): Ctor|int
{
    $value = str_contains($name->s, "\0") ? false : getenv($name->s);
    return $value === false ? 0 : new Ctor(1, [ioString($value)]);
}

function lean_io_process_get_pid(): int
{
    $pid = getmypid();
    return $pid === false ? lean_internal_panic('Could not retrieve the process ID') : $pid;
}

function lean_io_get_tid(): int
{
    return lean_io_process_get_pid();
}

function lean_io_exit(int $code): never
{
    @fflush(STDOUT);
    @fflush(STDERR);
    exit($code);
}

function lean_io_force_exit(int $code): never
{
    exit($code);
}
