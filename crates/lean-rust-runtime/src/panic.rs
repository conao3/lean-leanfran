//! Panics (`lean_panic_fn`, internal panics) and `dbgTrace`, with the messages of the C runtime.

use crate::closure::lean_apply_1;
use crate::object::{lean_box, lean_dec, lean_inc, Obj};
use crate::string::lean_string_bytes;
use std::cell::Cell;
use std::io::Write;

thread_local! {
    static EXIT_ON_PANIC: Cell<bool> = const { Cell::new(false) };
    static PANIC_MESSAGES: Cell<bool> = const { Cell::new(true) };
}

fn eprint_line(bytes: &[u8]) {
    let mut e = std::io::stderr().lock();
    let _ = e.write_all(bytes);
    let _ = e.write_all(b"\n");
    let _ = e.flush();
}

fn abort_on_panic() {
    if std::env::var_os("LEAN_ABORT_ON_PANIC").is_some() {
        std::process::abort();
    }
}

/// `lean_set_exit_on_panic`: exit with code 1 after a panic message.
pub unsafe fn lean_set_exit_on_panic(flag: bool) {
    EXIT_ON_PANIC.set(flag);
}

/// `lean_internal_set_exit_on_panic : Bool → BaseIO Unit`.
pub unsafe fn lean_internal_set_exit_on_panic(flag: u8) -> Obj {
    EXIT_ON_PANIC.set(flag != 0);
    lean_box(0)
}

/// `lean_set_panic_messages`: print panic messages or not.
pub unsafe fn lean_set_panic_messages(flag: bool) {
    PANIC_MESSAGES.set(flag);
}

fn panic_impl(msg: &[u8]) {
    if PANIC_MESSAGES.get() {
        eprint_line(msg);
    }
    abort_on_panic();
    if EXIT_ON_PANIC.get() {
        std::process::exit(1);
    }
}

/// `lean_panic`: prints `msg` to stderr (and exits if `setExitOnPanic` was set).
pub unsafe fn lean_panic(msg: &str, _force_stderr: bool) {
    panic_impl(msg.as_bytes());
}

/// `panicCore`: prints the message `msg` (owned) and returns `default_val` (owned).
pub unsafe fn lean_panic_fn(default_val: Obj, msg: Obj) -> Obj {
    panic_impl(lean_string_bytes(msg));
    lean_dec(msg);
    default_val
}

/// `lean_panic_fn` with a borrowed default value.
pub unsafe fn lean_panic_fn_borrowed(default_val: Obj, msg: Obj) -> Obj {
    lean_inc(default_val);
    lean_panic_fn(default_val, msg)
}

/// Prints `INTERNAL PANIC: msg` and exits with code 1.
#[cold]
pub fn lean_internal_panic(msg: &str) -> ! {
    eprint_line(format!("INTERNAL PANIC: {msg}").as_bytes());
    abort_on_panic();
    std::process::exit(1)
}

#[cold]
pub fn lean_internal_panic_out_of_memory() -> ! {
    lean_internal_panic("out of memory")
}

#[cold]
pub fn lean_internal_panic_unreachable() -> ! {
    lean_internal_panic("unreachable code has been reached")
}

#[cold]
pub fn lean_internal_panic_rc_overflow() -> ! {
    lean_internal_panic("reference counter overflowed")
}

#[cold]
pub fn lean_internal_panic_overflow() -> ! {
    lean_internal_panic("integer overflow in runtime computation")
}

/// `sorry` at run time.
pub unsafe fn lean_sorry(_dummy: u8) -> Obj {
    lean_internal_panic("executed 'sorry'")
}

/// `dbgTrace`: prints `s` (owned) to stderr and applies `fn` (owned) to `()`.
pub unsafe fn lean_dbg_trace(s: Obj, f: Obj) -> Obj {
    eprint_line(lean_string_bytes(s));
    lean_dec(s);
    lean_apply_1(f, lean_box(0))
}

/// `dbgSleep`: sleeps `ms` milliseconds and applies `fn` (owned) to `()`.
pub unsafe fn lean_dbg_sleep(ms: u32, f: Obj) -> Obj {
    std::thread::sleep(std::time::Duration::from_millis(ms as u64));
    lean_apply_1(f, lean_box(0))
}

/// `dbgTraceIfShared`: prints `shared RC s` when `a` is shared; returns `a`.
pub unsafe fn lean_dbg_trace_if_shared(s: Obj, a: Obj) -> Obj {
    if !crate::object::lean_is_scalar(a) && !crate::object::lean_is_exclusive(a) {
        let mut line = b"shared RC ".to_vec();
        line.extend_from_slice(lean_string_bytes(s));
        eprint_line(&line);
    }
    a
}

/// `dbgStackTrace`: no stack traces are available; applies `fn` (owned) to `()`.
pub unsafe fn lean_dbg_stack_trace(f: Obj) -> Obj {
    lean_apply_1(f, lean_box(0))
}
