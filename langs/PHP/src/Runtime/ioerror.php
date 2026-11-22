<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

final class IoFailure extends \RuntimeException
{
    public function __construct(
        public readonly Ctor $error,
    ) {
        parent::__construct(ioErrorMessage($error));
    }
}

const IO_ERRNO = [
    'EPERM' => [1, 13, 'operation not permitted'],
    'ENOENT' => [2, 11, 'no such file or directory'],
    'ESRCH' => [3, 16, 'no such process'],
    'EINTR' => [4, 10, 'interrupted system call'],
    'EIO' => [5, 5, 'i/o error'],
    'ENXIO' => [6, 16, 'no such device or address'],
    'E2BIG' => [7, 14, 'argument list too long'],
    'EBADF' => [9, 12, 'bad file descriptor'],
    'EAGAIN' => [11, 14, 'resource temporarily unavailable'],
    'ENOMEM' => [12, 14, 'not enough memory'],
    'EACCES' => [13, 13, 'permission denied'],
    'EFAULT' => [14, 1, 'bad address in system call argument'],
    'EBUSY' => [16, 2, 'resource busy or locked'],
    'EEXIST' => [17, 0, 'file already exists'],
    'EXDEV' => [18, 4, 'cross-device link not permitted'],
    'ENODEV' => [19, 4, 'no such device'],
    'ENOTDIR' => [20, 15, 'not a directory'],
    'EISDIR' => [21, 15, 'illegal operation on a directory'],
    'EINVAL' => [22, 12, 'invalid argument'],
    'ENFILE' => [23, 14, 'file table overflow'],
    'EMFILE' => [24, 14, 'too many open files'],
    'ENOTTY' => [25, 7, 'inappropriate ioctl for device'],
    'ETXTBSY' => [26, 2, 'text file is busy'],
    'EFBIG' => [27, 13, 'file too large'],
    'ENOSPC' => [28, 14, 'no space left on device'],
    'ESPIPE' => [29, 4, 'invalid seek'],
    'EROFS' => [30, 13, 'read-only file system'],
    'EMLINK' => [31, 14, 'too many links'],
    'EPIPE' => [32, 3, 'broken pipe'],
    'ERANGE' => [34, 4, 'result too large'],
    'ENAMETOOLONG' => [36, 12, 'name too long'],
    'ENOSYS' => [38, 4, 'function not implemented'],
    'ENOTEMPTY' => [39, 6, 'directory not empty'],
    'ELOOP' => [40, 12, 'too many symbolic links encountered'],
    'ENODATA' => [61, 16, 'no data available'],
    'EPROTO' => [71, 8, 'protocol error'],
    'EILSEQ' => [84, 12, 'illegal byte sequence'],
    'ENOTSOCK' => [88, 12, 'socket operation on non-socket'],
    'EDESTADDRREQ' => [89, 12, 'destination address required'],
    'EMSGSIZE' => [90, 14, 'message too long'],
    'EPROTOTYPE' => [91, 8, 'protocol wrong type for socket'],
    'ENOPROTOOPT' => [92, 4, 'protocol not available'],
    'EPROTONOSUPPORT' => [93, 8, 'protocol not supported'],
    'EOPNOTSUPP' => [95, 4, 'operation not supported on socket'],
    'EAFNOSUPPORT' => [97, 4, 'address family not supported'],
    'EADDRINUSE' => [98, 2, 'address already in use'],
    'EADDRNOTAVAIL' => [99, 4, 'address not available'],
    'ENETDOWN' => [100, 3, 'network is down'],
    'ENETUNREACH' => [101, 16, 'network is unreachable'],
    'ECONNABORTED' => [103, 13, 'software caused connection abort'],
    'ECONNRESET' => [104, 3, 'connection reset by peer'],
    'ENOBUFS' => [105, 14, 'no buffer space available'],
    'EISCONN' => [106, 0, 'socket is already connected'],
    'ENOTCONN' => [107, 12, 'socket is not connected'],
    'ETIMEDOUT' => [110, 9, 'connection timed out'],
    'ECONNREFUSED' => [111, 16, 'connection refused'],
    'EHOSTUNREACH' => [113, 16, 'host is unreachable'],
];

const IO_ERRNO_APPROX = [
    'ENOEXEC' => [8, 'EINVAL'],
    'ECHILD' => [10, 'ESRCH'],
    'EDOM' => [33, 'EINVAL'],
    'EDEADLK' => [35, 'EBUSY'],
    'ENOLCK' => [37, 'EAGAIN'],
    'ENOMSG' => [42, 'ENODATA'],
    'EIDRM' => [43, 'EPIPE'],
    'ENOSTR' => [60, 'EINVAL'],
    'ETIME' => [62, 'ETIMEDOUT'],
    'ENOSR' => [63, 'ENOBUFS'],
    'ENOLINK' => [67, 'ECONNRESET'],
    'EBADMSG' => [74, 'EPROTO'],
    'ENETRESET' => [102, 'ECONNRESET'],
    'EINPROGRESS' => [115, 'EISCONN'],
];

const IO_DARWIN_ERRNO = [
    'EDEADLK' => 11,
    'EAGAIN' => 35,
    'EINPROGRESS' => 36,
    'ENOTSOCK' => 38,
    'EDESTADDRREQ' => 39,
    'EMSGSIZE' => 40,
    'EPROTOTYPE' => 41,
    'ENOPROTOOPT' => 42,
    'EPROTONOSUPPORT' => 43,
    'EOPNOTSUPP' => 102,
    'EAFNOSUPPORT' => 47,
    'EADDRINUSE' => 48,
    'EADDRNOTAVAIL' => 49,
    'ENETDOWN' => 50,
    'ENETUNREACH' => 51,
    'ENETRESET' => 52,
    'ECONNABORTED' => 53,
    'ECONNRESET' => 54,
    'ENOBUFS' => 55,
    'EISCONN' => 56,
    'ENOTCONN' => 57,
    'ETIMEDOUT' => 60,
    'ECONNREFUSED' => 61,
    'ELOOP' => 62,
    'ENAMETOOLONG' => 63,
    'EHOSTUNREACH' => 65,
    'ENOTEMPTY' => 66,
    'ENOLCK' => 77,
    'ENOSYS' => 78,
    'EIDRM' => 82,
    'ENOMSG' => 83,
    'EILSEQ' => 92,
    'EBADMSG' => 94,
    'ENODATA' => 96,
    'ENOSR' => 98,
    'ENOSTR' => 99,
    'EPROTO' => 100,
    'ETIME' => 101,
];

function ioErrno(string $name, int $linuxCode): int
{
    return PHP_OS_FAMILY === 'Darwin' ? IO_DARWIN_ERRNO[$name] ?? $linuxCode : $linuxCode;
}

function ioHasFilename(int $tag): bool
{
    return $tag === 0 || $tag >= 10 && $tag <= 16;
}

function ioMakeError(int $tag, int $code, string $details, ?LString $filename): Ctor
{
    $text = ioString($details);
    if (!ioHasFilename($tag)) {
        return new Ctor($tag, [$text], [8 => $code & 0xffffffff]);
    }
    $name = match ($tag) {
        10, 11 => $filename ?? new LString(''),
        default => $filename === null ? 0 : new Ctor(1, [lean_inc_ret($filename)]),
    };
    if ($filename !== null && ($tag === 10 || $tag === 11)) {
        lean_inc($filename);
    }
    return new Ctor($tag, [$name, $text], [16 => $code & 0xffffffff]);
}

function ioDecodeError(int $code, ?LString $filename = null, bool $approximate = true): Ctor
{
    foreach (IO_ERRNO as $name => [$linuxCode, $tag, $message]) {
        if (ioErrno($name, $linuxCode) === $code) {
            return ioMakeError($tag, $code, $message, $filename);
        }
    }
    if ($approximate) {
        foreach (IO_ERRNO_APPROX as $name => [$linuxCode, $approx]) {
            if (ioErrno($name, $linuxCode) === $code) {
                return ioMakeError(IO_ERRNO[$approx][1], $code, IO_ERRNO[$approx][2], $filename);
            }
        }
    }
    return ioMakeError(1, $code, 'Unknown system error ' . -$code, null);
}

function lean_decode_io_error(int $code, ?LString $filename): Ctor
{
    return ioDecodeError($code, $filename);
}

function ioFailure(string $errno, ?LString $filename = null, ?string $details = null): never
{
    [$linuxCode, $tag, $message] = IO_ERRNO[$errno];
    throw new IoFailure(ioMakeError($tag, ioErrno($errno, $linuxCode), $details ?? $message, $filename));
}

function ioWarning(string $warning, ?LString $filename): never
{
    if (preg_match('/\berrno[ =]+(\d+)/i', $warning, $match) === 1) {
        throw new IoFailure(ioDecodeError((int) $match[1], $filename));
    }
    $message = strtolower($warning);
    foreach ([
        'is a directory' => 'EISDIR',
        'too many levels of symbolic links' => 'ELOOP',
        'file name too long' => 'ENAMETOOLONG',
        'cannot allocate memory' => 'ENOMEM',
        'device or resource busy' => 'EBUSY',
        'already exists' => 'EEXIST',
        'file exists' => 'EEXIST',
        'invalid cross-device link' => 'EXDEV',
        'input/output error' => 'EIO',
        'unable to seek' => 'ESPIPE',
    ] as $phrase => $name) {
        if (str_ends_with($message, $phrase)) {
            ioFailure($name, $filename);
        }
    }
    foreach (IO_ERRNO as $name => [, , $details]) {
        if (str_ends_with($message, $details)) {
            ioFailure($name, $filename);
        }
    }
    throw new IoFailure(ioMakeError(1, 0, $warning, null));
}

/**
 * @template T
 * @param \Closure(): (T|false) $fn
 * @return ($failure is null ? T|false : T)
 */
function ioNative(\Closure $fn, ?LString $filename = null, ?string $failure = 'EIO'): mixed
{
    $warning = null;
    set_error_handler(static function (int $level, string $message) use (&$warning): bool {
        $warning = $message;
        return true;
    }, E_WARNING | E_NOTICE);
    try {
        $result = $fn();
    } finally {
        restore_error_handler();
    }
    if ($warning !== null) {
        ioWarning($warning, $filename);
    }
    if ($result === false && $failure !== null) {
        ioFailure($failure, $filename);
    }
    return $result;
}

function ioAttempt(\Closure $fn): Ctor
{
    try {
        return lean_io_result_mk_ok($fn());
    } catch (IoFailure $failure) {
        return lean_io_result_mk_error($failure->error);
    }
}

function ioString(string $bytes): LString
{
    if (preg_match('//u', $bytes) !== 1) {
        $bytes = json_decode(
            json_encode($bytes, JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR),
            true,
            flags: JSON_THROW_ON_ERROR,
        );
    }
    if (!is_string($bytes)) {
        throw new \LogicException('Expected valid UTF-8 from JSON decoding.');
    }
    return new LString($bytes);
}

function ioErrorMessage(Ctor|int $error): string
{
    if (is_int($error)) {
        return match ($error) {
            17 => 'end of file',
            default => throw new \LogicException('Invalid scalar IO.Error constructor ' . $error),
        };
    }
    $tag = $error->tag;
    if ($tag === 18) {
        return requireRuntimeObject($error->objs[0], LString::class)->s;
    }

    $withFile = ioHasFilename($tag);
    $details = requireRuntimeObject($error->objs[$withFile ? 1 : 0], LString::class)->s;
    $code = $error->sc[$withFile ? 16 : 8];
    if (!is_int($code)) {
        throw new \TypeError('Expected a UInt32 error code.');
    }
    $filename = null;
    if ($withFile) {
        $field = $error->objs[0];
        $filename = match (true) {
            $tag === 10 || $tag === 11 => requireRuntimeObject($field, LString::class)->s,
            $field instanceof Ctor => requireRuntimeObject($field->objs[0], LString::class)->s,
            default => null,
        };
    }
    $gist = match ($tag) {
        0 => 'already exists',
        1, 13 => $details,
        2 => 'resource busy',
        3 => 'resource vanished',
        4 => 'unsupported operation',
        5 => 'hardware fault',
        6 => 'directory not empty',
        7 => 'illegal operation',
        8 => 'protocol error',
        9 => 'time expired',
        10 => 'interrupted system call',
        11 => 'no such file or directory',
        12 => 'invalid argument',
        14 => 'resource exhausted',
        15 => 'inappropriate type',
        16 => 'no such thing',
        default => throw new \LogicException('Invalid IO.Error constructor ' . $tag),
    };
    $detail = in_array($tag, [1, 5, 6, 11, 13], true) ? '' : ', ' . lcfirst($details);
    $file = $filename === null ? '' : "\n  file: " . $filename;
    return lcfirst($gist) . ' (error code: ' . $code . $detail . ')' . $file;
}
