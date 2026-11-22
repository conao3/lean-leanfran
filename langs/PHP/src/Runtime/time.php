<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

function lean_io_mono_nanos_now(): int
{
    return hrtime(true);
}

function lean_io_mono_ms_now(): int
{
    return intdiv(lean_io_mono_nanos_now(), 1000000);
}

function lean_get_current_time(): Ctor
{
    $now = gettimeofday();
    return lean_io_result_mk_ok(new Ctor(0, [$now['sec'], $now['usec'] * 1000]));
}

function lean_io_get_random_bytes(int $count): Ctor
{
    return ioAttempt(static function () use ($count): LByteArray {
        if ($count < 0) {
            ioFailure('ENOMEM');
        }
        if ($count === 0) {
            return new LByteArray();
        }
        try {
            return new LByteArray(random_bytes($count));
        } catch (\Random\RandomException) {
            ioFailure('EIO');
        }
    });
}

function lean_system_platform_windows(int $unit): int
{
    return (int) (PHP_OS_FAMILY === 'Windows');
}

function lean_system_platform_osx(int $unit): int
{
    return (int) (PHP_OS_FAMILY === 'Darwin');
}

function lean_system_platform_linux(int $unit): int
{
    return (int) (PHP_OS_FAMILY === 'Linux');
}

function lean_system_platform_emscripten(int $unit): int
{
    return (int) (PHP_OS === 'Emscripten');
}

function lean_internal_get_hardware_concurrency(int $unit): int
{
    if (PHP_OS_FAMILY === 'Windows') {
        return (int) getenv('NUMBER_OF_PROCESSORS');
    }
    if (PHP_OS_FAMILY === 'Linux') {
        $cpus = @file_get_contents('/sys/devices/system/cpu/online');
        if ($cpus === false) {
            return 0;
        }
        $count = 0;
        foreach (explode(',', trim($cpus)) as $range) {
            $bounds = explode('-', $range, 2);
            $count += count($bounds) === 1 ? 1 : (int) $bounds[1] - (int) $bounds[0] + 1;
        }
        return $count;
    }
    if (PHP_OS_FAMILY === 'Darwin') {
        $status = 0;
        $count = @exec('/usr/sbin/sysctl -n hw.logicalcpu', $output, $status);
        return $status === 0 ? (int) $count : 0;
    }
    return 0;
}

function lean_runtime_mark_multi_threaded(mixed $value): mixed
{
    return $value;
}

function lean_runtime_mark_persistent(mixed $value): mixed
{
    return lean_mark_persistent($value);
}
