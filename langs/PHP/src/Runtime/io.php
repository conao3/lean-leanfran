<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

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
    fflush(STDOUT);
    fwrite(STDERR, $message . "\n");
    fflush(STDERR);
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
    writeStderr($message->s);
    lean_dec($message);
    return lean_apply($fn, [0]);
}

function outputWrite($stream, string $bytes): Ctor
{
    if (@fwrite($stream, $bytes) !== strlen($bytes)) {
        return lean_io_result_mk_error(lean_mk_io_user_error(new LString('Error writing to the output stream')));
    }
    return lean_io_result_mk_ok(0);
}

function outputStream($stream): Ctor
{
    $unsupported = static fn() => lean_io_result_mk_error(lean_mk_io_user_error(
        new LString('This stream only supports output'),
    ));
    return new Ctor(0, [
        new LClosure(static fn($world) => fflush($stream)
            ? lean_io_result_mk_ok(0)
            : lean_io_result_mk_error(lean_mk_io_user_error(new LString('Error flushing the output stream'))), 1),
        new LClosure($unsupported, 2),
        new LClosure(static function (LByteArray $bytes, $world) use ($stream): Ctor {
            $result = outputWrite($stream, $bytes->b);
            lean_dec($bytes);
            return $result;
        }, 2),
        new LClosure($unsupported, 1),
        new LClosure(static function (LString $text, $world) use ($stream): Ctor {
            $result = outputWrite($stream, $text->s);
            lean_dec($text);
            return $result;
        }, 2),
        new LClosure(static fn($world) => (int) stream_isatty($stream), 1),
    ]);
}

function lean_get_stdout(): Ctor
{
    return outputStream(STDOUT);
}

function lean_get_stderr(): Ctor
{
    return outputStream(STDERR);
}

function lean_io_result_show_error(Ctor $result): void
{
    $error = lean_io_result_get_error($result);
    $message = match (lean_obj_tag($error)) {
        17 => 'end of file',
        18 => $error->objs[0]->s,
        default => throw new \LogicException('Unsupported IO.Error constructor: ' . lean_obj_tag($error)),
    };
    writeStderr('uncaught exception: ' . explode("\0", $message, 2)[0]);
}

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
    return $code;
}
