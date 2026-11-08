//! `Thunk` (evaluated on first `get`) and `Task` (run synchronously when created; there are
//! no worker threads).

use crate::closure::lean_apply_1;
use crate::object::*;
use crate::panic::lean_internal_panic;
use core::mem::size_of;
use core::ptr;

#[inline]
unsafe fn to_thunk(o: Obj) -> *mut ThunkObject {
    o as *mut ThunkObject
}

#[inline]
unsafe fn to_task(o: Obj) -> *mut TaskObject {
    o as *mut TaskObject
}

/// `Thunk.mk` from a closure `Unit → α` (consumed).
#[inline]
pub unsafe fn lean_mk_thunk(c: Obj) -> Obj {
    let o = lean_alloc_small_object(size_of::<ThunkObject>());
    lean_set_st_header(o, LEAN_THUNK as u32, 0);
    (*to_thunk(o)).m_value = ptr::null_mut();
    (*to_thunk(o)).m_closure = c;
    o
}

/// `Thunk.pure` (consumes `v`).
#[inline]
pub unsafe fn lean_thunk_pure(v: Obj) -> Obj {
    let o = lean_alloc_small_object(size_of::<ThunkObject>());
    lean_set_st_header(o, LEAN_THUNK as u32, 0);
    (*to_thunk(o)).m_value = v;
    (*to_thunk(o)).m_closure = ptr::null_mut();
    o
}

/// Evaluates the closure of `t` and stores the value; returns it borrowed.
pub unsafe fn lean_thunk_get_core(t: Obj) -> Obj {
    let c = (*to_thunk(t)).m_closure;
    if c.is_null() {
        lean_internal_panic("thunk forced while it is being evaluated");
    }
    (*to_thunk(t)).m_closure = ptr::null_mut();
    let r = lean_apply_1(c, lean_box(0));
    (*to_thunk(t)).m_value = r;
    r
}

/// The value of `t` (borrowed in and out).
#[inline]
pub unsafe fn lean_thunk_get(t: Obj) -> Obj {
    debug_check_live(t, "thunk read");
    let r = (*to_thunk(t)).m_value;
    if !r.is_null() {
        return r;
    }
    lean_thunk_get_core(t)
}

/// `Thunk.get` (borrows `t`, returns an owned value).
#[inline]
pub unsafe fn lean_thunk_get_own(t: Obj) -> Obj {
    let r = lean_thunk_get(t);
    lean_inc(r);
    r
}

/* Tasks */

/// `Task.pure` (consumes `a`).
pub unsafe fn lean_task_pure(a: Obj) -> Obj {
    let o = lean_alloc_small_object(size_of::<TaskObject>());
    lean_set_st_header(o, LEAN_TASK as u32, 0);
    (*to_task(o)).m_value = a;
    (*to_task(o)).m_imp = ptr::null_mut();
    o
}

/// Runs the closure `c : Unit → α` (consumed) now and returns the finished task.
pub unsafe fn lean_task_spawn_core(c: Obj, _prio: u32, _keep_alive: bool) -> Obj {
    lean_task_pure(lean_apply_1(c, lean_box(0)))
}

/// `Task.spawn` (`c` and `prio` consumed).
#[inline]
pub unsafe fn lean_task_spawn(c: Obj, prio: Obj) -> Obj {
    lean_dec(prio);
    lean_task_spawn_core(c, 0, false)
}

/// The value of a task (borrowed in and out).
#[inline]
pub unsafe fn lean_task_get(t: Obj) -> Obj {
    debug_check_live(t, "task read");
    let v = (*to_task(t)).m_value;
    if v.is_null() {
        lean_internal_panic(
            "the result of a promise that is not resolved is read (tasks run synchronously, so nothing can resolve it later)",
        );
    }
    v
}

/// `Task.get` (consumes `t`).
#[inline]
pub unsafe fn lean_task_get_own(t: Obj) -> Obj {
    let r = lean_task_get(t);
    lean_inc(r);
    lean_dec(t);
    r
}

pub unsafe fn lean_task_map_core(
    f: Obj,
    t: Obj,
    _prio: u32,
    _sync: bool,
    _keep_alive: bool,
) -> Obj {
    let v = lean_task_get(t);
    lean_inc(v);
    lean_dec(t);
    lean_task_pure(lean_apply_1(f, v))
}

/// `Task.map f t prio sync` (`f`, `t`, `prio` consumed).
#[inline]
pub unsafe fn lean_task_map(f: Obj, t: Obj, prio: Obj, sync: u8) -> Obj {
    lean_dec(prio);
    lean_task_map_core(f, t, 0, sync != 0, false)
}

pub unsafe fn lean_task_bind_core(
    x: Obj,
    f: Obj,
    _prio: u32,
    _sync: bool,
    _keep_alive: bool,
) -> Obj {
    let v = lean_task_get(x);
    lean_inc(v);
    lean_dec(x);
    lean_apply_1(f, v)
}

/// `Task.bind x f prio sync` (`x`, `f`, `prio` consumed).
#[inline]
pub unsafe fn lean_task_bind(x: Obj, f: Obj, prio: Obj, sync: u8) -> Obj {
    lean_dec(prio);
    lean_task_bind_core(x, f, 0, sync != 0, false)
}

/// `IO.checkCanceled`: tasks are never canceled.
pub unsafe fn lean_io_check_canceled_core() -> bool {
    false
}

/// `IO.cancel`: no-op, tasks are already finished.
pub unsafe fn lean_io_cancel_core(_t: Obj) {}

/// `IO.getTaskState`: finished (2), or running (1) for the result of an unresolved promise, as the C runtime reports it.
pub unsafe fn lean_io_get_task_state_core(t: Obj) -> u8 {
    if (*to_task(t)).m_value.is_null() {
        1
    } else {
        2
    }
}

/* Tasks of `BaseIO` actions */

/// `BaseIO.asTask act prio` (`act`, `prio` consumed): runs `act` now.
pub unsafe fn lean_io_as_task(act: Obj, prio: Obj) -> Obj {
    lean_dec(prio);
    lean_task_pure(lean_apply_1(act, lean_box(0)))
}

/// `BaseIO.mapTask f t prio sync` (`f`, `t`, `prio` consumed).
pub unsafe fn lean_io_map_task(f: Obj, t: Obj, prio: Obj, _sync: u8) -> Obj {
    lean_dec(prio);
    let v = lean_task_get(t);
    lean_inc(v);
    lean_dec(t);
    lean_task_pure(crate::closure::lean_apply_2(f, v, lean_box(0)))
}

/// `BaseIO.bindTask t f prio sync` (`t`, `f`, `prio` consumed).
pub unsafe fn lean_io_bind_task(t: Obj, f: Obj, prio: Obj, _sync: u8) -> Obj {
    lean_dec(prio);
    let v = lean_task_get(t);
    lean_inc(v);
    lean_dec(t);
    crate::closure::lean_apply_2(f, v, lean_box(0))
}

/// `IO.checkCanceled : BaseIO Bool`.
pub unsafe fn lean_io_check_canceled() -> u8 {
    lean_io_check_canceled_core() as u8
}

/// `IO.cancel : @& Task α → BaseIO Unit`.
pub unsafe fn lean_io_cancel(t: Obj) -> Obj {
    lean_io_cancel_core(t);
    lean_box(0)
}

/// `IO.getTaskState : @& Task α → BaseIO TaskState`.
pub unsafe fn lean_io_get_task_state(t: Obj) -> u8 {
    lean_io_get_task_state_core(t)
}

/// `IO.wait : Task α → BaseIO α` (consumes `t`).
pub unsafe fn lean_io_wait(t: Obj) -> Obj {
    lean_task_get_own(t)
}

/// `IO.waitAny : @& List (Task α) → BaseIO α`: the value of the first task.
pub unsafe fn lean_io_wait_any(tasks: Obj) -> Obj {
    let v = lean_task_get(lean_ctor_get(tasks, 0));
    lean_inc(v);
    v
}

/* Promises */

unsafe fn promise_finalize(p: *mut core::ffi::c_void) {
    let t = *Box::from_raw(p as *mut Obj);
    if (*to_task(t)).m_value.is_null() {
        (*to_task(t)).m_value = lean_box(0);
    }
    lean_dec(t);
}

unsafe fn promise_foreach(_p: *mut core::ffi::c_void, _f: Obj) {}

static PROMISE_CLASS: ExternalClass = ExternalClass {
    m_finalize: promise_finalize,
    m_foreach: promise_foreach,
};

unsafe fn promise_task(p: Obj) -> Obj {
    *(lean_get_external_data(p) as *const Obj)
}

/// `IO.Promise.new : BaseIO (Promise α)`: a promise whose task `Task (Option α)` holds no value
/// until `resolve` (`some v`) or until the promise is dropped (`none`).
pub unsafe fn lean_io_promise_new() -> Obj {
    let t = lean_alloc_small_object(size_of::<TaskObject>());
    lean_set_st_header(t, LEAN_TASK as u32, 0);
    (*to_task(t)).m_value = ptr::null_mut();
    (*to_task(t)).m_imp = ptr::null_mut();
    lean_alloc_external(
        &PROMISE_CLASS,
        Box::into_raw(Box::new(t)) as *mut core::ffi::c_void,
    )
}

/// `IO.Promise.resolve : α → (@& Promise α) → BaseIO Unit` (consumes `value`); a second
/// `resolve` keeps the first value.
pub unsafe fn lean_io_promise_resolve(value: Obj, p: Obj) -> Obj {
    let t = promise_task(p);
    if (*to_task(t)).m_value.is_null() {
        let s = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(s, 0, value);
        (*to_task(t)).m_value = s;
    } else {
        lean_dec(value);
    }
    lean_box(0)
}

/// `IO.Promise.result? : (@& Promise α) → Task (Option α)`.
pub unsafe fn lean_io_promise_result_opt(p: Obj) -> Obj {
    let t = promise_task(p);
    lean_inc(t);
    t
}

/// `Option.getOrBlock! : Option α → α` (consumes `o`): the value, or a panic for a promise
/// dropped without a value.
pub unsafe fn lean_option_get_or_block(o: Obj) -> Obj {
    if lean_is_scalar(o) {
        crate::panic::lean_panic(
            "PANIC: Promise.result!: promise has been dropped without ever being resolved",
            true,
        );
        lean_internal_panic(
            "Promise.result!: promise has been dropped without ever being resolved",
        );
    }
    let v = lean_ctor_get(o, 0);
    lean_inc(v);
    lean_dec(o);
    v
}
