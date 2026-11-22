<?php

declare(strict_types=1);

use Conao3\Leanfran\Runtime as L;
use PHPUnit\Framework\TestCase;

final class IoRuntimeTest extends TestCase
{
    public function testFormatsAllIoErrorConstructors(): void
    {
        $file = new L\LString('probe.txt');
        $number = 42;
        $expected = [
            "already exists (error code: 42, details)\n  file: probe.txt",
            'details (error code: 42)',
            'resource busy (error code: 42, details)',
            'resource vanished (error code: 42, details)',
            'unsupported operation (error code: 42, details)',
            'hardware fault (error code: 42)',
            'directory not empty (error code: 42)',
            'illegal operation (error code: 42, details)',
            'protocol error (error code: 42, details)',
            'time expired (error code: 42, details)',
            "interrupted system call (error code: 42, details)\n  file: probe.txt",
            "no such file or directory (error code: 42)\n  file: probe.txt",
            "invalid argument (error code: 42, details)\n  file: probe.txt",
            "details (error code: 42)\n  file: probe.txt",
            "resource exhausted (error code: 42, details)\n  file: probe.txt",
            "inappropriate type (error code: 42, details)\n  file: probe.txt",
            "no such thing (error code: 42, details)\n  file: probe.txt",
            'end of file',
            'Details',
        ];
        foreach ($expected as $tag => $message) {
            $error = match ($tag) {
                17 => 17,
                18 => L\lean_mk_io_user_error(new L\LString('Details')),
                default => L\ioMakeError($tag, $number, 'Details', $file),
            };
            self::assertSame($message, L\ioErrorMessage($error));
            L\lean_dec($error);
        }
        self::assertSame(1, $file->rc);
        self::assertSame(
            'inappropriate type (error code: 21, illegal operation on a directory)',
            L\ioErrorMessage(L\ioDecodeError(21)),
        );
        self::assertSame('no such thing (error code: 10, no such process)', L\ioErrorMessage(L\ioDecodeError(10)));
        self::assertSame(
            'unknown system error -10 (error code: 10)',
            L\ioErrorMessage(L\ioDecodeError(10, null, false)),
        );
    }

    public function testByteAndFloatArrayOwnership(): void
    {
        $source = new L\LByteArray("\0abcdef");
        $original = new L\LByteArray('1234');
        $exclusive = L\lean_byte_array_copy_slice($source, 1, $original, 2, 3, 0);
        self::assertSame($original, $exclusive);
        self::assertSame('12abc', $exclusive->b);

        L\lean_inc($original);
        $copy = L\lean_byte_array_copy_slice($source, 0, $original, 9, 2, 1);
        self::assertNotSame($original, $copy);
        self::assertSame('12abc', $original->b);
        self::assertSame("12abc\0a", $copy->b);
        self::assertSame(1, $original->rc);

        $floats = new L\LFloatArray([1.25, 2.5]);
        self::assertSame($floats, L\lean_float_array_push($floats, 3.75));
        L\lean_inc($floats);
        $newFloats = L\lean_float_array_set($floats, 0, 4.25);
        self::assertNotSame($floats, $newFloats);
        self::assertSame([1.25, 2.5, 3.75], $floats->a);
        self::assertSame([4.25, 2.5, 3.75], $newFloats->a);
    }

    public function testDroppingPromiseCompletesOutstandingResultWithNone(): void
    {
        $promise = L\lean_io_promise_new();
        $result = L\lean_io_promise_result_opt($promise);
        self::assertSame(1, L\lean_io_get_task_state($result));
        L\lean_dec($promise);
        self::assertSame(2, L\lean_io_get_task_state($result));
        self::assertSame(0, L\lean_io_wait($result));
        self::assertSame(0, $result->rc);
    }

    public function testResolvedTaskTransfersOwnershipToWaiter(): void
    {
        $value = new L\LString('value');
        $task = L\lean_task_pure($value);
        self::assertSame($value, L\lean_io_wait($task));
        self::assertSame(1, $value->rc);
        self::assertSame(0, L\lean_ptr_addr($value));
    }
}
