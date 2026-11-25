package rt

import "sync"

type taskState struct {
	mu       sync.Mutex
	finished bool
}

func newTask(value V, finished bool) V {
	return V{p: newObjX(kindTask, []V{value}, &taskState{finished: finished})}
}

func taskResult(task V) (V, bool) {
	state := task.p.ext().x.(*taskState)
	state.mu.Lock()
	defer state.mu.Unlock()
	return task.p.fs[0], state.finished
}

func resolveTask(task, value V) {
	state := task.p.ext().x.(*taskState)
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.finished {
		Lean_dec(value)
		return
	}
	if task.p.rc == 0 {
		Lean_mark_persistent(value)
	}
	task.p.fs[0] = value
	state.finished = true
}

func Lean_task_pure(value V) V { return newTask(value, true) }

func Lean_task_spawn(fn, priority V) V {
	Lean_dec(priority)
	return Lean_task_pure(Lean_apply(fn, []V{{}}))
}

func Lean_task_get(task V) V {
	result, finished := taskResult(task)
	if !finished {
		Lean_internal_panic("Cannot wait on an unresolved promise in synchronous execution")
	}
	return result
}

func Lean_task_get_own(task V) V {
	result := own(Lean_task_get(task))
	Lean_dec(task)
	return result
}

func Lean_task_map(fn, task, priority V, _ uint8) V {
	Lean_dec(priority)
	return Lean_task_pure(Lean_apply(fn, []V{Lean_task_get_own(task)}))
}

func Lean_task_bind(task, fn, priority V, _ uint8) V {
	Lean_dec(priority)
	return Lean_apply(fn, []V{Lean_task_get_own(task)})
}

func Lean_io_as_task(fn, priority V) V { return Lean_task_spawn(fn, priority) }

func Lean_io_map_task(fn, task, priority V, _ uint8) V {
	Lean_dec(priority)
	return Lean_task_pure(Lean_apply(fn, []V{Lean_task_get_own(task), {}}))
}

func Lean_io_bind_task(task, fn, priority V, _ uint8) V {
	Lean_dec(priority)
	return Lean_apply(fn, []V{Lean_task_get_own(task), {}})
}

func Lean_io_wait(task V) V { return Lean_task_get_own(task) }

func Lean_io_wait_any(tasks V) V {
	for tasks.p != nil {
		if result, finished := taskResult(Lean_ctor_get(tasks, 0)); finished {
			return own(result)
		}
		tasks = Lean_ctor_get(tasks, 1)
	}
	Lean_internal_panic("Cannot wait on unresolved promises in synchronous execution")
	return V{}
}

func Lean_io_cancel(_ V) V          { return V{} }
func Lean_io_check_canceled() uint8 { return 0 }

func Lean_io_get_task_state(task V) uint8 {
	if _, finished := taskResult(task); finished {
		return 2
	}
	return 1
}

func Lean_io_promise_new() V {
	return V{p: newObjX(kindPromise, []V{newTask(V{}, false)}, nil)}
}

func Lean_io_promise_resolve(value, promise V) V {
	resolveTask(promise.p.fs[0], ctor(1, value))
	return V{}
}

func Lean_io_promise_result_opt(promise V) V { return own(promise.p.fs[0]) }

func Lean_option_get_or_block(option V) V {
	if option.p == nil {
		Lean_internal_panic("Promise dropped without resolving in synchronous execution")
	}
	value := own(Lean_ctor_get(option, 0))
	Lean_dec(option)
	return value
}

func Lean_runtime_mark_multi_threaded(v V) V { return Lean_mark_persistent(v) }
func Lean_runtime_mark_persistent(v V) V     { return Lean_mark_persistent(v) }
