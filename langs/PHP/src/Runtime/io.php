<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

/**
 * @template T of object
 * @param class-string<T> $type
 * @return T
 */
function requireRuntimeObject(mixed $value, string $type): object
{
    if (!$value instanceof $type) {
        throw new \TypeError('Expected ' . $type . ', received ' . get_debug_type($value));
    }
    return $value;
}

function lean_system_platform_nbits(int $unit): int
{
    return PHP_INT_SIZE * 8;
}

function lean_io_result_mk_ok(mixed $value): Ctor
{
    return new Ctor(0, [$value]);
}

function lean_io_result_mk_error(mixed $error): Ctor
{
    return new Ctor(1, [$error]);
}

function lean_io_result_is_ok(Ctor $result): bool
{
    return $result->tag === 0;
}

function lean_io_result_is_error(Ctor $result): bool
{
    return $result->tag === 1;
}

function lean_io_result_get_value(Ctor $result): mixed
{
    if (!lean_io_result_is_ok($result)) {
        throw new \LogicException('Expected a successful Lean IO result.');
    }
    return $result->objs[0];
}

function lean_io_result_get_error(Ctor $result): mixed
{
    if (!lean_io_result_is_error($result)) {
        throw new \LogicException('Expected a failed Lean IO result.');
    }
    return $result->objs[0];
}

function lean_io_result_take_value(Ctor $result): mixed
{
    $value = lean_inc_ret(lean_io_result_get_value($result));
    lean_dec($result);
    return $value;
}

function lean_mk_io_user_error(LString $message): Ctor
{
    return new Ctor(18, [$message]);
}

function lean_panic_fn(mixed $default, LString $message): mixed
{
    writeStderr($message->s);
    lean_dec($message);
    return $default;
}

function lean_panic_fn_borrowed(mixed $default, LString $message): mixed
{
    return lean_panic_fn(lean_inc_ret($default), $message);
}

function writeStderr(string $message): void
{
    @fflush(STDOUT);
    @fwrite(STDERR, $message . "\n");
    @fflush(STDERR);
}

function lean_internal_panic(string $message): never
{
    writeStderr('INTERNAL PANIC: ' . $message);
    exit(1);
}

function lean_internal_panic_unreachable(): never
{
    lean_internal_panic('unreachable code has been reached');
}

function lean_dbg_trace(LString $message, LClosure $fn): mixed
{
    ioWriteTrace($message->s);
    lean_dec($message);
    return lean_apply($fn, [0]);
}

function lean_dbg_trace_if_shared(LString $message, mixed $value): mixed
{
    if ($value instanceof LeanObject && !lean_is_exclusive($value)) {
        ioWriteTrace('shared RC ' . explode("\0", $message->s, 2)[0]);
    }
    return $value;
}

function ioWriteTrace(string $text): void
{
    $stream = lean_get_stderr();
    $write = requireRuntimeObject($stream->objs[4], LClosure::class);
    lean_inc($write);
    lean_dec($stream);
    $result = requireRuntimeObject(lean_apply($write, [new LString($text . "\n"), 0]), Ctor::class);
    if (lean_io_result_is_error($result)) {
        lean_internal_panic('Could not write debug trace');
    }
    lean_dec($result);
}

function lean_dbg_sleep(int $milliseconds, LClosure $fn): mixed
{
    usleep($milliseconds * 1000);
    return lean_apply($fn, [0]);
}

function lean_stream_of_handle(Ctor $handle): Ctor
{
    lean_inc_n($handle, 5);
    return new Ctor(0, [
        new LClosure(
            static function (Ctor $h, mixed $world): Ctor {
                $result = lean_io_prim_handle_flush($h);
                lean_dec($h);
                return $result;
            },
            2,
            [$handle],
        ),
        new LClosure(
            static function (Ctor $h, int $count, mixed $world): Ctor {
                $result = lean_io_prim_handle_read($h, $count);
                lean_dec($h);
                return $result;
            },
            3,
            [$handle],
        ),
        new LClosure(
            static function (Ctor $h, LByteArray $bytes, mixed $world): Ctor {
                $result = lean_io_prim_handle_write($h, $bytes);
                lean_dec($bytes);
                lean_dec($h);
                return $result;
            },
            3,
            [$handle],
        ),
        new LClosure(
            static function (Ctor $h, mixed $world): Ctor {
                $result = lean_io_prim_handle_get_line($h);
                lean_dec($h);
                return $result;
            },
            2,
            [$handle],
        ),
        new LClosure(
            static function (Ctor $h, LString $text, mixed $world): Ctor {
                $result = lean_io_prim_handle_put_str($h, $text);
                lean_dec($text);
                lean_dec($h);
                return $result;
            },
            3,
            [$handle],
        ),
        new LClosure(
            static function (Ctor $h, mixed $world): int {
                $result = lean_io_prim_handle_is_tty($h);
                lean_dec($h);
                return $result;
            },
            2,
            [$handle],
        ),
    ]);
}

final class IoStandardStreams
{
    /** @param array<int, Ctor> $streams */
    public function __construct(
        private array $streams = [],
    ) {}

    /** @param int<0, 2> $fd */
    public function current(int $fd, ?Ctor $replacement): Ctor
    {
        if (!isset($this->streams[$fd])) {
            $resource = match ($fd) {
                0 => STDIN,
                1 => STDOUT,
                2 => STDERR,
            };
            $this->streams[$fd] = lean_stream_of_handle(ioHandle($resource, $fd === 0, $fd !== 0, false));
        }
        $old = $this->streams[$fd];
        if ($replacement === null) {
            lean_inc($old);
        } else {
            $this->streams[$fd] = $replacement;
        }
        return $old;
    }
}

/** @param int<0, 2> $fd */
function stdStream(int $fd, ?Ctor $replacement = null): Ctor
{
    static $streams = null;
    if (!$streams instanceof IoStandardStreams) {
        $streams = new IoStandardStreams();
    }
    return $streams->current($fd, $replacement);
}

function lean_get_stdin(): Ctor
{
    return stdStream(0);
}

function lean_get_stdout(): Ctor
{
    return stdStream(1);
}

function lean_get_stderr(): Ctor
{
    return stdStream(2);
}

function lean_get_set_stdin(Ctor $stream): Ctor
{
    return stdStream(0, $stream);
}

function lean_get_set_stdout(Ctor $stream): Ctor
{
    return stdStream(1, $stream);
}

function lean_get_set_stderr(Ctor $stream): Ctor
{
    return stdStream(2, $stream);
}

function lean_io_result_show_error(Ctor $result): void
{
    $error = lean_io_result_get_error($result);
    $message = ioErrorMessage(is_int($error) ? $error : requireRuntimeObject($error, Ctor::class));
    writeStderr('uncaught exception: ' . explode("\0", $message, 2)[0]);
}

/**
 * @param \Closure(Ctor|int ...): Ctor $main
 * @param list<string> $args
 * @param list<\Closure(): Ctor> $initializers
 */
function lean_run_main(\Closure $main, array $args, bool $hasArgs, bool $returnsExitCode, array $initializers): int
{
    foreach ($initializers as $init) {
        $result = $init();
        if (lean_io_result_is_error($result)) {
            lean_io_result_show_error($result);
            lean_dec($result);
            return 1;
        }
        lean_dec($result);
    }
    if ($hasArgs) {
        $list = 0;
        foreach (array_reverse($args) as $arg) {
            $list = new Ctor(1, [new LString($arg), $list]);
        }
        $result = $main($list);
    } else {
        $result = $main();
    }
    if (lean_io_result_is_error($result)) {
        lean_io_result_show_error($result);
        lean_dec($result);
        return 1;
    }
    $code = $returnsExitCode ? lean_io_result_get_value($result) : 0;
    lean_dec($result);
    if (!is_int($code)) {
        throw new \TypeError('Expected a UInt32 exit code.');
    }
    return $code;
}
