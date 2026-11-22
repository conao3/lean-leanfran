<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

final class IoHandleResource
{
    /** @param resource $stream */
    public function __construct(
        public readonly mixed $stream,
        public readonly bool $readable,
        public readonly bool $writable,
        public readonly bool $owned,
        public readonly ?ProcessPipes $pipes = null,
        public readonly int $fd = 0,
    ) {}

    public function __destruct()
    {
        if ($this->pipes !== null) {
            $this->pipes->discard($this->fd);
        }
        if ($this->owned && is_resource($this->stream)) {
            @fclose($this->stream);
        }
    }
}

/** @param resource $stream */
function ioHandle(
    mixed $stream,
    bool $readable,
    bool $writable,
    bool $owned = true,
    ?ProcessPipes $pipes = null,
    int $fd = 0,
): Ctor {
    return new Ctor(0, [new IoHandleResource($stream, $readable, $writable, $owned, $pipes, $fd)]);
}

function ioPath(LString $name): string
{
    if (str_contains($name->s, "\0")) {
        ioFailure('EINVAL', $name, 'string contains NUL bytes');
    }
    return preg_match('/\A[a-zA-Z0-9+.-]+:\/\//', $name->s) === 1 ? './' . $name->s : $name->s;
}

function ioReadHandle(Ctor $handle): IoHandleResource
{
    $h = requireRuntimeObject($handle->objs[0], IoHandleResource::class);
    if (!$h->readable) {
        ioFailure('EBADF');
    }
    return $h;
}

function lean_io_prim_handle_mk(LString $filename, int $mode): Ctor
{
    return ioAttempt(static function () use ($filename, $mode): Ctor {
        $path = ioPath($filename);
        $flags = match ($mode) {
            0 => 'rb',
            1 => 'wb',
            2 => 'xb',
            3 => 'r+b',
            4 => 'ab',
            default => ioFailure('EINVAL', $filename),
        };
        if ($path === '') {
            ioFailure('ENOENT', $filename);
        }
        $stream = ioNative(static fn() => fopen($path, PHP_OS_FAMILY === 'Windows' ? $flags : $flags . 'e'), $filename);
        return ioHandle($stream, $mode === 0 || $mode === 3, $mode !== 0);
    });
}

function lean_io_prim_handle_flush(Ctor $handle): Ctor
{
    return ioAttempt(static function () use ($handle): int {
        ioNative(static fn() => fflush(requireRuntimeObject($handle->objs[0], IoHandleResource::class)->stream));
        return 0;
    });
}

function ioHandleWrite(Ctor $handle, string $data): Ctor
{
    return ioAttempt(static function () use ($handle, $data): int {
        $h = requireRuntimeObject($handle->objs[0], IoHandleResource::class);
        if (!$h->writable) {
            ioFailure('EBADF');
        }
        $size = strlen($data);
        for ($offset = 0; $offset < $size; $offset += $written) {
            $bytes = substr($data, $offset, 65536);
            if ($h->pipes !== null) {
                while (!$h->pipes->pump($h->stream)) {
                }
            }
            $written = ioNative(static fn() => fwrite($h->stream, $bytes));
            if ($written === 0) {
                ioFailure('EIO');
            }
        }
        return 0;
    });
}

function lean_io_prim_handle_put_str(Ctor $handle, LString $text): Ctor
{
    return ioHandleWrite($handle, $text->s);
}

function lean_io_prim_handle_write(Ctor $handle, LByteArray $bytes): Ctor
{
    return ioHandleWrite($handle, $bytes->b);
}

function lean_io_prim_handle_read(Ctor $handle, int $count): Ctor
{
    return ioAttempt(static function () use ($handle, $count): LByteArray {
        if ($count === 0) {
            return new LByteArray();
        }
        $h = ioReadHandle($handle);
        if ($count < 0) {
            ioFailure('ENOMEM');
        }
        if ($h->pipes !== null) {
            return new LByteArray($h->pipes->read($h->fd, $count));
        }
        $bytes = '';
        do {
            $chunk = ioNative(static fn() => fread($h->stream, max(1, min($count - strlen($bytes), 65536))));
            $bytes .= $chunk;
        } while ($h->owned && $chunk !== '' && strlen($bytes) < $count && !feof($h->stream));
        return new LByteArray($bytes);
    });
}

function lean_io_prim_handle_get_line(Ctor $handle): Ctor
{
    return ioAttempt(static function () use ($handle): LString {
        $h = ioReadHandle($handle);
        if ($h->pipes !== null) {
            return ioString($h->pipes->read($h->fd, null));
        }
        $info = ioNative(static fn() => fstat($h->stream), failure: null);
        if ($info !== false && ($info['mode'] & 0170000) === 0040000) {
            ioFailure('EISDIR');
        }
        $line = ioNative(static fn() => fgets($h->stream), failure: null);
        return ioString($line === false ? '' : $line);
    });
}

function lean_io_prim_handle_is_tty(Ctor $handle): int
{
    return (int) @stream_isatty(requireRuntimeObject($handle->objs[0], IoHandleResource::class)->stream);
}

function lean_io_prim_handle_rewind(Ctor $handle): Ctor
{
    return ioAttempt(static function () use ($handle): int {
        ioNative(static fn() => rewind(requireRuntimeObject(
            $handle->objs[0],
            IoHandleResource::class,
        )->stream), failure: 'ESPIPE');
        return 0;
    });
}

function lean_io_prim_handle_truncate(Ctor $handle): Ctor
{
    return ioAttempt(static function () use ($handle): int {
        $stream = requireRuntimeObject($handle->objs[0], IoHandleResource::class)->stream;
        $offset = ioNative(static fn() => ftell($stream), failure: 'EINVAL');
        if ($offset < 0) {
            ioFailure('EINVAL');
        }
        ioNative(static fn() => ftruncate($stream, $offset), failure: 'EINVAL');
        return 0;
    });
}

/** @param int<0, 7> $operation */
function ioLock(Ctor $handle, int $operation): Ctor
{
    return ioAttempt(static function () use ($handle, $operation): int {
        $stream = requireRuntimeObject($handle->objs[0], IoHandleResource::class)->stream;
        $blocked = 0;
        $locked = ioNative(static function () use ($stream, $operation, &$blocked): bool {
            return flock($stream, $operation, $blocked);
        }, failure: null);
        if (!$locked && !$blocked) {
            ioFailure('EINVAL');
        }
        return ($operation & LOCK_NB) === 0 ? 0 : (int) $locked;
    });
}

function lean_io_prim_handle_lock(Ctor $handle, int $exclusive): Ctor
{
    return ioLock($handle, $exclusive ? LOCK_EX : LOCK_SH);
}

function lean_io_prim_handle_try_lock(Ctor $handle, int $exclusive): Ctor
{
    return ioLock($handle, ($exclusive ? LOCK_EX : LOCK_SH) | LOCK_NB);
}

function lean_io_prim_handle_unlock(Ctor $handle): Ctor
{
    return ioLock($handle, LOCK_UN);
}

function lean_io_read_dir(LString $directory): Ctor
{
    return ioAttempt(static function () use ($directory): LArray {
        $path = ioPath($directory);
        $stream = ioNative(static fn() => opendir($path), $directory, 'ENOENT');
        $entries = [];
        try {
            while (($name = ioNative(static fn() => readdir($stream), $directory, null)) !== false) {
                if ($name !== '.' && $name !== '..') {
                    lean_inc($directory);
                    $entries[] = new Ctor(0, [$directory, ioString($name)]);
                }
            }
        } finally {
            closedir($stream);
        }
        return new LArray($entries);
    });
}

function ioMetadata(LString $filename, bool $symlink): Ctor
{
    return ioAttempt(static function () use ($filename, $symlink): Ctor {
        $path = ioPath($filename);
        if ($path === '') {
            ioFailure('ENOENT', $filename);
        }
        clearstatcache(true);
        $stat = $symlink ? @lstat($path) : @stat($path);
        if ($stat === false) {
            $parent = dirname($path);
            while (!@is_dir($parent) && !@file_exists($parent) && dirname($parent) !== $parent) {
                $parent = dirname($parent);
            }
            if (!@is_dir($parent)) {
                ioFailure('ENOTDIR', $filename);
            }
            if (PHP_OS_FAMILY !== 'Windows' && !@is_executable($parent)) {
                ioFailure('EACCES', $filename);
            }
            ioFailure('ENOENT', $filename);
        }
        $kind = match ($stat['mode'] & 0170000) {
            0040000 => 0,
            0100000 => 1,
            0120000 => 2,
            default => 3,
        };
        return new Ctor(
            0,
            [
                new Ctor(0, [$stat['atime']], [8 => 0]),
                new Ctor(0, [$stat['mtime']], [8 => 0]),
            ],
            [16 => $stat['size'], 24 => $stat['nlink'], 32 => $kind],
        );
    });
}

function lean_io_metadata(LString $filename): Ctor
{
    return ioMetadata($filename, false);
}

function lean_io_symlink_metadata(LString $filename): Ctor
{
    return ioMetadata($filename, true);
}

function ioPathAction(LString $filename, \Closure $fn): Ctor
{
    return ioAttempt(static function () use ($filename, $fn): int {
        $path = ioPath($filename);
        if ($path === '') {
            ioFailure('ENOENT', $filename);
        }
        ioNative(static fn() => $fn($path), $filename);
        return 0;
    });
}

function lean_io_create_dir(LString $directory): Ctor
{
    return ioPathAction($directory, mkdir(...));
}

function lean_io_remove_dir(LString $directory): Ctor
{
    return ioPathAction($directory, rmdir(...));
}

function lean_io_remove_file(LString $filename): Ctor
{
    return ioPathAction($filename, unlink(...));
}

function lean_io_rename(LString $source, LString $dest): Ctor
{
    return ioAttempt(static function () use ($source, $dest): int {
        $from = ioPath($source);
        $to = ioPath($dest);
        $label = new LString($source->s . ' and/or ' . $dest->s);
        if ($from === '' || $to === '') {
            ioFailure('ENOENT', $label);
        }
        ioNative(static fn() => rename($from, $to), $label);
        return 0;
    });
}

function lean_io_hard_link(LString $source, LString $dest): Ctor
{
    return ioAttempt(static function () use ($source, $dest): int {
        $from = ioPath($source);
        $to = ioPath($dest);
        ioNative(static fn() => link($from, $to), $source);
        return 0;
    });
}

function lean_io_realpath(LString $filename): Ctor
{
    return ioAttempt(static function () use ($filename): LString {
        $path = ioPath($filename);
        clearstatcache(true);
        if ($path === '' || ($resolved = @realpath($path)) === false) {
            ioFailure('ENOENT', $filename);
        }
        return ioString($resolved);
    });
}

function lean_chmod(LString $filename, int $mode): Ctor
{
    return ioPathAction($filename, static fn(string $path) => chmod($path, $mode));
}

function ioTempPath(): LString
{
    foreach (['TMPDIR', 'TMP', 'TEMP', 'TEMPDIR'] as $name) {
        $path = getenv($name);
        if ($path !== false && $path !== '') {
            break;
        }
    }
    $directory = $path === false || $path === '' ? sys_get_temp_dir() : $path;
    return ioString(rtrim($directory, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . 'tmp.' . bin2hex(random_bytes(8)));
}

function lean_io_create_tempfile(): Ctor
{
    return ioAttempt(static function (): Ctor {
        $path = ioTempPath();
        $mode = umask(0077);
        try {
            $stream = ioNative(static fn() => fopen(ioPath($path), PHP_OS_FAMILY === 'Windows' ? 'x+b' : 'x+be'));
        } finally {
            umask($mode);
        }
        return new Ctor(0, [ioHandle($stream, true, true), $path]);
    });
}

function lean_io_create_tempdir(): Ctor
{
    return ioAttempt(static function (): LString {
        $path = ioTempPath();
        ioNative(static fn() => mkdir(ioPath($path), 0700));
        return $path;
    });
}
