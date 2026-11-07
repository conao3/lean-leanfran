//! IO primitives: results (`EST.Out`), `IO.Error`, the standard streams, `ST.Ref` and the
//! monotonic clocks.
//!
//! In Lean 4.35 an `IO` action returns an `EST.Out` (`ok` = constructor 0, `error` =
//! constructor 1, one object field), while a `BaseIO`/`ST` action returns its value itself. The
//! world parameter has the IR type `void` and is not passed to externs.

use crate::array::{lean_alloc_sarray, lean_sarray_cptr, lean_sarray_set_size, sarray_bytes};
use crate::closure::lean_alloc_closure;
use crate::nat::lean_uint64_to_nat;
use crate::object::*;
use crate::string::{
    lean_mk_string, lean_mk_string_from_bytes, lean_string_bytes, lean_string_to_str,
};
use core::ffi::c_void;
use std::cell::Cell;
use std::io::{BufRead, Read, Write};

/* Results */

#[inline]
pub unsafe fn lean_io_mk_world() -> Obj {
    lean_box(0)
}

#[inline]
pub unsafe fn lean_io_result_mk_ok(a: Obj) -> Obj {
    let r = lean_alloc_ctor(0, 1, 0);
    lean_ctor_set(r, 0, a);
    r
}

#[inline]
pub unsafe fn lean_io_result_mk_error(e: Obj) -> Obj {
    let r = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(r, 0, e);
    r
}

#[inline]
pub unsafe fn lean_io_result_is_ok(r: Obj) -> bool {
    lean_ptr_tag(r) == 0
}

#[inline]
pub unsafe fn lean_io_result_is_error(r: Obj) -> bool {
    lean_ptr_tag(r) == 1
}

#[inline]
pub unsafe fn lean_io_result_get_value(r: Obj) -> Obj {
    lean_ctor_get(r, 0)
}

#[inline]
pub unsafe fn lean_io_result_get_error(r: Obj) -> Obj {
    lean_ctor_get(r, 0)
}

/// The value of an `ok` result (consumes `r`).
#[inline]
pub unsafe fn lean_io_result_take_value(r: Obj) -> Obj {
    let v = lean_ctor_get(r, 0);
    lean_inc(v);
    lean_dec(r);
    v
}

/* IO.Error */

/// Constructor index of `IO.Error.otherError`.
const IO_ERROR_OTHER: u32 = 1;
/// Constructor index of `IO.Error.unexpectedEof`.
const IO_ERROR_EOF: u32 = 17;
/// Constructor index of `IO.Error.userError`.
const IO_ERROR_USER: u32 = 18;

/// `IO.userError msg` (consumes `msg`).
pub unsafe fn lean_mk_io_user_error(msg: Obj) -> Obj {
    let r = lean_alloc_ctor(IO_ERROR_USER, 1, 0);
    lean_ctor_set(r, 0, msg);
    r
}

/// `IO.Error.otherError code details` (consumes `details`).
pub unsafe fn lean_mk_io_error_other_error(code: u32, details: Obj) -> Obj {
    let r = lean_alloc_ctor(IO_ERROR_OTHER, 1, 4);
    lean_ctor_set(r, 0, details);
    lean_ctor_set_uint32(r, 8, code);
    r
}

/// `IO.Error.unexpectedEof`.
pub unsafe fn lean_mk_io_error_eof(_unit: Obj) -> Obj {
    lean_box(IO_ERROR_EOF as usize)
}

unsafe fn io_error_of(e: &std::io::Error) -> Obj {
    let code = e.raw_os_error().unwrap_or(0) as u32;
    lean_mk_io_error_other_error(code, lean_mk_string(&e.to_string()))
}

unsafe fn io_result_of_error(e: &std::io::Error) -> Obj {
    lean_io_result_mk_error(io_error_of(e))
}

/// Text of an `IO.Error` for `uncaught exception:` (user errors and the `details` of the
/// constructors with a message; the exact `IO.Error.toString` is Lean code).
unsafe fn io_error_text(e: Obj) -> String {
    if lean_is_scalar(e) {
        return if lean_unbox(e) as u32 == IO_ERROR_EOF {
            "end of file".to_string()
        } else {
            String::new()
        };
    }
    let n = lean_ctor_num_objs(e);
    let details = lean_ctor_get(e, n - 1);
    let text = lean_string_to_str(details).to_string();
    if lean_ptr_tag(e) as u32 == IO_ERROR_USER {
        text
    } else {
        let code = lean_ctor_get_uint32(e, 8 * n);
        format!("{text} (error code: {code})")
    }
}

/// Prints `uncaught exception: <error>` for an `error` result (borrowed).
pub unsafe fn lean_io_result_show_error(r: Obj) {
    let text = io_error_text(lean_io_result_get_error(r));
    let _ = std::io::stdout().flush();
    eprintln!("uncaught exception: {text}");
}

/* Handles */

/// The file behind a `IO.FS.Handle` (only the standard streams are provided).
pub enum HandleFile {
    Stdin,
    Stdout,
    Stderr,
}

unsafe fn handle_finalize(p: *mut c_void) {
    drop(Box::from_raw(p as *mut HandleFile));
}

unsafe fn handle_foreach(_p: *mut c_void, _f: Obj) {}

static HANDLE_CLASS: ExternalClass = ExternalClass {
    m_finalize: handle_finalize,
    m_foreach: handle_foreach,
};

/// An `IO.FS.Handle` for `f`.
pub unsafe fn lean_io_wrap_handle(f: HandleFile) -> Obj {
    lean_alloc_external(&HANDLE_CLASS, Box::into_raw(Box::new(f)) as *mut c_void)
}

unsafe fn handle_file<'a>(h: Obj) -> &'a HandleFile {
    &*(lean_get_external_data(h) as *const HandleFile)
}

fn write_to(f: &HandleFile, bytes: &[u8]) -> std::io::Result<()> {
    match f {
        HandleFile::Stdout => std::io::stdout().write_all(bytes),
        HandleFile::Stderr => std::io::stderr().write_all(bytes),
        HandleFile::Stdin => Err(std::io::Error::from(std::io::ErrorKind::Unsupported)),
    }
}

/// `Handle.flush : (@& Handle) → IO Unit`.
pub unsafe fn lean_io_prim_handle_flush(h: Obj) -> Obj {
    let r = match handle_file(h) {
        HandleFile::Stdout => std::io::stdout().flush(),
        HandleFile::Stderr => std::io::stderr().flush(),
        HandleFile::Stdin => Ok(()),
    };
    match r {
        Ok(()) => lean_io_result_mk_ok(lean_box(0)),
        Err(e) => io_result_of_error(&e),
    }
}

/// `Handle.putStr : (@& Handle) → (@& String) → IO Unit`.
pub unsafe fn lean_io_prim_handle_put_str(h: Obj, s: Obj) -> Obj {
    match write_to(handle_file(h), lean_string_bytes(s)) {
        Ok(()) => lean_io_result_mk_ok(lean_box(0)),
        Err(e) => io_result_of_error(&e),
    }
}

/// `Handle.write : (@& Handle) → (@& ByteArray) → IO Unit`.
pub unsafe fn lean_io_prim_handle_write(h: Obj, buf: Obj) -> Obj {
    match write_to(handle_file(h), sarray_bytes(buf)) {
        Ok(()) => lean_io_result_mk_ok(lean_box(0)),
        Err(e) => io_result_of_error(&e),
    }
}

/// `Handle.getLine : (@& Handle) → IO String`: up to and including the next newline.
pub unsafe fn lean_io_prim_handle_get_line(h: Obj) -> Obj {
    match handle_file(h) {
        HandleFile::Stdin => {
            let mut line = Vec::new();
            match std::io::stdin().lock().read_until(b'\n', &mut line) {
                Ok(_) => lean_io_result_mk_ok(lean_mk_string_from_bytes(&line)),
                Err(e) => io_result_of_error(&e),
            }
        }
        _ => io_result_of_error(&std::io::Error::from(std::io::ErrorKind::Unsupported)),
    }
}

/// `Handle.read : (@& Handle) → USize → IO ByteArray`.
pub unsafe fn lean_io_prim_handle_read(h: Obj, nbytes: usize) -> Obj {
    match handle_file(h) {
        HandleFile::Stdin => {
            let r = lean_alloc_sarray(1, 0, nbytes);
            let buf = core::slice::from_raw_parts_mut(lean_sarray_cptr(r), nbytes);
            match std::io::stdin().lock().read(buf) {
                Ok(n) => {
                    lean_sarray_set_size(r, n);
                    lean_io_result_mk_ok(r)
                }
                Err(e) => {
                    lean_dec_ref(r);
                    io_result_of_error(&e)
                }
            }
        }
        _ => io_result_of_error(&std::io::Error::from(std::io::ErrorKind::Unsupported)),
    }
}

/// `Handle.isTty : (@& Handle) → BaseIO Bool`.
pub unsafe fn lean_io_prim_handle_is_tty(h: Obj) -> u8 {
    use std::io::IsTerminal;
    (match handle_file(h) {
        HandleFile::Stdin => std::io::stdin().is_terminal(),
        HandleFile::Stdout => std::io::stdout().is_terminal(),
        HandleFile::Stderr => std::io::stderr().is_terminal(),
    }) as u8
}

/* Streams (`IO.FS.Stream.ofHandle`) */

unsafe fn stream_flush(h: Obj, _w: Obj) -> Obj {
    let r = lean_io_prim_handle_flush(h);
    lean_dec(h);
    r
}

unsafe fn stream_read(h: Obj, n: Obj, _w: Obj) -> Obj {
    let r = lean_io_prim_handle_read(h, lean_unbox_usize(n));
    lean_dec(n);
    lean_dec(h);
    r
}

unsafe fn stream_write(h: Obj, b: Obj, _w: Obj) -> Obj {
    let r = lean_io_prim_handle_write(h, b);
    lean_dec(b);
    lean_dec(h);
    r
}

unsafe fn stream_get_line(h: Obj, _w: Obj) -> Obj {
    let r = lean_io_prim_handle_get_line(h);
    lean_dec(h);
    r
}

unsafe fn stream_put_str(h: Obj, s: Obj, _w: Obj) -> Obj {
    let r = lean_io_prim_handle_put_str(h, s);
    lean_dec(s);
    lean_dec(h);
    r
}

unsafe fn stream_is_tty(h: Obj, _w: Obj) -> Obj {
    let r = lean_io_prim_handle_is_tty(h);
    lean_dec(h);
    lean_box(r as usize)
}

unsafe fn handle_closure(f: *const (), arity: u32, h: Obj) -> Obj {
    let c = lean_alloc_closure(f, arity, 1);
    lean_inc(h);
    crate::closure::lean_closure_set(c, 0, h);
    c
}

/// `IO.FS.Stream.ofHandle` (consumes `h`).
pub unsafe fn lean_stream_of_handle(h: Obj) -> Obj {
    let s = lean_alloc_ctor(0, 6, 0);
    lean_ctor_set(s, 0, handle_closure(stream_flush as *const (), 2, h));
    lean_ctor_set(s, 1, handle_closure(stream_read as *const (), 3, h));
    lean_ctor_set(s, 2, handle_closure(stream_write as *const (), 3, h));
    lean_ctor_set(s, 3, handle_closure(stream_get_line as *const (), 2, h));
    lean_ctor_set(s, 4, handle_closure(stream_put_str as *const (), 3, h));
    lean_ctor_set(s, 5, handle_closure(stream_is_tty as *const (), 2, h));
    lean_dec(h);
    s
}

thread_local! {
    static STDIN: Cell<Obj> = const { Cell::new(core::ptr::null_mut()) };
    static STDOUT: Cell<Obj> = const { Cell::new(core::ptr::null_mut()) };
    static STDERR: Cell<Obj> = const { Cell::new(core::ptr::null_mut()) };
}

unsafe fn current_stream(
    slot: &'static std::thread::LocalKey<Cell<Obj>>,
    f: fn() -> HandleFile,
) -> Obj {
    let mut s = slot.get();
    if s.is_null() {
        s = lean_stream_of_handle(lean_io_wrap_handle(f()));
        lean_mark_persistent(s);
        slot.set(s);
    }
    lean_inc(s);
    s
}

unsafe fn swap_stream(
    slot: &'static std::thread::LocalKey<Cell<Obj>>,
    f: fn() -> HandleFile,
    h: Obj,
) -> Obj {
    let old = current_stream(slot, f);
    lean_dec(slot.get());
    slot.set(h);
    old
}

/// `IO.getStdin : BaseIO IO.FS.Stream`.
pub unsafe fn lean_get_stdin() -> Obj {
    current_stream(&STDIN, || HandleFile::Stdin)
}

/// `IO.getStdout : BaseIO IO.FS.Stream`.
pub unsafe fn lean_get_stdout() -> Obj {
    current_stream(&STDOUT, || HandleFile::Stdout)
}

/// `IO.getStderr : BaseIO IO.FS.Stream`.
pub unsafe fn lean_get_stderr() -> Obj {
    current_stream(&STDERR, || HandleFile::Stderr)
}

/// `IO.setStdin : IO.FS.Stream → BaseIO IO.FS.Stream` (returns the previous stream).
pub unsafe fn lean_get_set_stdin(h: Obj) -> Obj {
    swap_stream(&STDIN, || HandleFile::Stdin, h)
}

/// `IO.setStdout : IO.FS.Stream → BaseIO IO.FS.Stream`.
pub unsafe fn lean_get_set_stdout(h: Obj) -> Obj {
    swap_stream(&STDOUT, || HandleFile::Stdout, h)
}

/// `IO.setStderr : IO.FS.Stream → BaseIO IO.FS.Stream`.
pub unsafe fn lean_get_set_stderr(h: Obj) -> Obj {
    swap_stream(&STDERR, || HandleFile::Stderr, h)
}

/* ST.Ref */

/// `ST.Prim.mkRef` (consumes `a`).
pub unsafe fn lean_st_mk_ref(a: Obj) -> Obj {
    lean_alloc_ref(a)
}

#[inline]
unsafe fn to_ref(r: Obj) -> *mut RefObject {
    r as *mut RefObject
}

/// `ST.Prim.Ref.get` (borrows the ref).
pub unsafe fn lean_st_ref_get(r: Obj) -> Obj {
    let v = (*to_ref(r)).m_value;
    if v.is_null() {
        crate::panic::lean_internal_panic("null reference read");
    }
    lean_inc(v);
    v
}

/// `ST.Prim.Ref.take`: the value, leaving the ref empty.
pub unsafe fn lean_st_ref_take(r: Obj) -> Obj {
    let v = (*to_ref(r)).m_value;
    if v.is_null() {
        crate::panic::lean_internal_panic("null reference read");
    }
    (*to_ref(r)).m_value = core::ptr::null_mut();
    v
}

/// `ST.Prim.Ref.set` (consumes `a`).
pub unsafe fn lean_st_ref_put(r: Obj, a: Obj) -> Obj {
    let old = (*to_ref(r)).m_value;
    if !old.is_null() {
        lean_dec(old);
    }
    (*to_ref(r)).m_value = a;
    lean_box(0)
}

/// `ST.Prim.Ref.swap` (consumes `a`, returns the old value).
pub unsafe fn lean_st_ref_swap(r: Obj, a: Obj) -> Obj {
    let old = (*to_ref(r)).m_value;
    if old.is_null() {
        crate::panic::lean_internal_panic("null reference read");
    }
    (*to_ref(r)).m_value = a;
    old
}

/// `ST.Prim.Ref.ptrEq`.
pub unsafe fn lean_st_ref_ptr_eq(r1: Obj, r2: Obj) -> u8 {
    (r1 == r2) as u8
}

/* Clocks and process */

fn mono_base() -> std::time::Instant {
    static BASE: std::sync::OnceLock<std::time::Instant> = std::sync::OnceLock::new();
    *BASE.get_or_init(std::time::Instant::now)
}

/// `IO.monoMsNow : BaseIO Nat`.
pub unsafe fn lean_io_mono_ms_now() -> Obj {
    lean_uint64_to_nat(mono_base().elapsed().as_millis() as u64 + 1)
}

/// `IO.monoNanosNow : BaseIO Nat`.
pub unsafe fn lean_io_mono_nanos_now() -> Obj {
    lean_uint64_to_nat(mono_base().elapsed().as_nanos() as u64 + 1)
}

/// `IO.Process.exit : UInt8 → IO α`.
pub unsafe fn lean_io_exit(code: u8) -> Obj {
    let _ = std::io::stdout().flush();
    std::process::exit(code as i32)
}

/// `Runtime.markPersistent : α → BaseIO α`.
pub unsafe fn lean_runtime_mark_persistent(a: Obj) -> Obj {
    lean_mark_persistent(a);
    a
}

/// `Runtime.markMultiThreaded : α → BaseIO α` (objects stay single-threaded).
pub unsafe fn lean_runtime_mark_multi_threaded(a: Obj) -> Obj {
    a
}
