<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

final class TaskResult
{
    public function __construct(
        public mixed $value,
    ) {}

    public function __destruct()
    {
        lean_dec($this->value);
    }
}

final class PendingPromise
{
    public readonly Ctor $task;

    public function __construct()
    {
        $this->task = lean_task_pure(null);
    }

    public function __destruct()
    {
        $result = taskResult($this->task);
        $result->value ??= 0;
        lean_dec($this->task);
    }
}

function taskResult(Ctor $task): TaskResult
{
    return requireRuntimeObject($task->objs[0], TaskResult::class);
}

function lean_task_pure(mixed $value): Ctor
{
    return new Ctor(0, [new TaskResult($value)]);
}

function lean_task_spawn(LClosure $fn, int|\GMP $priority): Ctor
{
    return lean_task_pure(lean_apply($fn, [0]));
}

function lean_task_get(Ctor $task): mixed
{
    return (
        taskResult($task)->value ?? lean_internal_panic('Cannot wait on an unresolved promise in synchronous execution')
    );
}

function lean_task_get_own(Ctor $task): mixed
{
    $value = lean_inc_ret(lean_task_get($task));
    lean_dec($task);
    return $value;
}

function lean_task_map(LClosure $fn, Ctor $task, int|\GMP $priority, int $sync): Ctor
{
    return lean_task_pure(lean_apply($fn, [lean_task_get_own($task)]));
}

function lean_task_bind(Ctor $task, LClosure $fn, int|\GMP $priority, int $sync): Ctor
{
    return requireRuntimeObject(lean_apply($fn, [lean_task_get_own($task)]), Ctor::class);
}

function lean_io_as_task(LClosure $act, int|\GMP $priority): Ctor
{
    return lean_task_spawn($act, $priority);
}

function lean_io_map_task(LClosure $fn, Ctor $task, int|\GMP $priority, int $sync): Ctor
{
    return lean_task_pure(lean_apply($fn, [lean_task_get_own($task), 0]));
}

function lean_io_bind_task(Ctor $task, LClosure $fn, int|\GMP $priority, int $sync): Ctor
{
    return requireRuntimeObject(lean_apply($fn, [lean_task_get_own($task), 0]), Ctor::class);
}

function lean_io_wait(Ctor $task): mixed
{
    return lean_task_get_own($task);
}

function lean_io_wait_any(Ctor $tasks): mixed
{
    for ($cell = $tasks; $cell instanceof Ctor; $cell = $cell->objs[1]) {
        $result = taskResult(requireRuntimeObject($cell->objs[0], Ctor::class))->value;
        if ($result !== null) {
            return lean_inc_ret($result);
        }
    }
    lean_internal_panic('Cannot wait on unresolved promises in synchronous execution');
}

function lean_io_cancel(Ctor $task): int
{
    return 0;
}

function lean_io_check_canceled(): int
{
    return 0;
}

function lean_io_get_task_state(Ctor $task): int
{
    return taskResult($task)->value === null ? 1 : 2;
}

function lean_io_promise_new(): Ctor
{
    return new Ctor(0, [new PendingPromise()]);
}

function lean_io_promise_resolve(mixed $value, Ctor $promise): int
{
    $result = taskResult(requireRuntimeObject($promise->objs[0], PendingPromise::class)->task);
    if ($result->value === null) {
        $result->value = new Ctor(1, [$value]);
    } else {
        lean_dec($value);
    }
    return 0;
}

function lean_io_promise_result_opt(Ctor $promise): Ctor
{
    $task = requireRuntimeObject($promise->objs[0], PendingPromise::class)->task;
    lean_inc($task);
    return $task;
}

function lean_option_get_or_block(Ctor|int $option): mixed
{
    if (is_int($option)) {
        lean_internal_panic('Promise dropped without resolving in synchronous execution');
    }
    $value = lean_inc_ret($option->objs[0]);
    lean_dec($option);
    return $value;
}
