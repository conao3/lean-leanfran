<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Runtime;

final class LTask extends LeanObject
{
    /** @param RuntimeValue|null $value */
    public function __construct(
        public mixed $value,
    ) {}
}

final class PendingPromise
{
    public readonly LTask $task;

    public function __construct()
    {
        $this->task = new LTask(null);
    }

    public function __destruct()
    {
        $this->task->value ??= 0;
        lean_dec($this->task);
    }
}

/** @param RuntimeValue $value */
function lean_task_pure(mixed $value): LTask
{
    return new LTask($value);
}

function lean_task_spawn(LClosure $fn, int|\GMP $priority): LTask
{
    return lean_task_pure(requireRuntimeValue(lean_apply($fn, [0])));
}

/** @return RuntimeValue */
function lean_task_get(LTask $task): mixed
{
    return $task->value ?? lean_internal_panic('Cannot wait on an unresolved promise in synchronous execution');
}

/** @return RuntimeValue */
function lean_task_get_own(LTask $task): mixed
{
    $value = lean_inc_ret(lean_task_get($task));
    lean_dec($task);
    return $value;
}

function lean_task_map(LClosure $fn, LTask $task, int|\GMP $priority, int $sync): LTask
{
    return lean_task_pure(requireRuntimeValue(lean_apply($fn, [lean_task_get_own($task)])));
}

function lean_task_bind(LTask $task, LClosure $fn, int|\GMP $priority, int $sync): LTask
{
    return requireRuntimeObject(lean_apply($fn, [lean_task_get_own($task)]), LTask::class);
}

function lean_io_as_task(LClosure $act, int|\GMP $priority): LTask
{
    return lean_task_spawn($act, $priority);
}

function lean_io_map_task(LClosure $fn, LTask $task, int|\GMP $priority, int $sync): LTask
{
    return lean_task_pure(requireRuntimeValue(lean_apply($fn, [lean_task_get_own($task), 0])));
}

function lean_io_bind_task(LTask $task, LClosure $fn, int|\GMP $priority, int $sync): LTask
{
    return requireRuntimeObject(lean_apply($fn, [lean_task_get_own($task), 0]), LTask::class);
}

function lean_io_wait(LTask $task): mixed
{
    return lean_task_get_own($task);
}

function lean_io_wait_any(Ctor $tasks): mixed
{
    for ($cell = $tasks; $cell instanceof Ctor; $cell = $cell->objs[1]) {
        $result = requireRuntimeObject($cell->objs[0], LTask::class)->value;
        if ($result !== null) {
            return lean_inc_ret($result);
        }
    }
    lean_internal_panic('Cannot wait on unresolved promises in synchronous execution');
}

function lean_io_cancel(LTask $task): int
{
    return 0;
}

function lean_io_check_canceled(): int
{
    return 0;
}

function lean_io_get_task_state(LTask $task): int
{
    return $task->value === null ? 1 : 2;
}

function lean_io_promise_new(): Ctor
{
    return new Ctor(0, [new PendingPromise()]);
}

/** @param RuntimeValue $value */
function lean_io_promise_resolve(mixed $value, Ctor $promise): int
{
    $task = requireRuntimeObject($promise->objs[0], PendingPromise::class)->task;
    if ($task->value === null) {
        $task->value = new Ctor(1, [$value]);
    } else {
        lean_dec($value);
    }
    return 0;
}

function lean_io_promise_result_opt(Ctor $promise): LTask
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
