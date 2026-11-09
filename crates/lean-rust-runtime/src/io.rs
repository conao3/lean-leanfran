//! IO primitives: results (`EST.Out`), handles (the standard streams and files), streams,
//! `ST.Ref` and the monotonic clocks.
//!
//! In Lean 4.35 an `IO` action returns an `EST.Out` (`ok` = constructor 0, `error` =
//! constructor 1, one object field), while a `BaseIO`/`ST` action returns its value itself. The
//! world parameter has the IR type `void` and is not passed to externs.

use crate::array::{lean_alloc_sarray, lean_sarray_cptr, lean_sarray_set_size, sarray_bytes};
use crate::closure::lean_alloc_closure;
use crate::io_error::{io_error_to_string, of_std, EBADF, EINVAL, ESPIPE};
use crate::nat::lean_uint64_to_nat;
use crate::object::*;
use crate::string::{lean_mk_string_from_bytes, lean_string_bytes};
use core::ffi::c_void;
use std::cell::{Cell, RefCell};
use std::io::{BufRead, Read, Seek, SeekFrom, Write};

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

/// The `error` result of a Rust I/O error without a file name.
pub(crate) unsafe fn io_result_of_error(e: &std::io::Error) -> Obj {
    lean_io_result_mk_error(of_std(e, None))
}

/// The `error` result of an operation that needs an OS, on a target without one.
#[cfg(not(unix))]
pub(crate) unsafe fn io_result_unsupported(what: &str) -> Obj {
    lean_io_result_mk_error(crate::io_error::unsupported_error(what))
}

/// `ok ()`, or the `error` result of `r`.
pub(crate) unsafe fn io_unit(r: std::io::Result<()>) -> Obj {
    match r {
        Ok(()) => lean_io_result_mk_ok(lean_box(0)),
        Err(e) => io_result_of_error(&e),
    }
}

/// Prints `uncaught exception: <IO.Error.toString e>` for an `error` result (borrowed).
pub unsafe fn lean_io_result_show_error(r: Obj) {
    let text = io_error_to_string(lean_io_result_get_error(r));
    let _ = std::io::stdout().flush();
    eprintln!("uncaught exception: {text}");
}

/* Handles */

/// The file behind a `IO.FS.Handle`.
pub enum HandleFile {
    Stdin,
    Stdout,
    Stderr,
    /// A file, a pipe or `/dev/null`, with a read buffer.
    File(RefCell<FileState>),
}

/// An open file and the bytes read from it ahead of the reader.
pub struct FileState {
    file: std::fs::File,
    buf: Vec<u8>,
    pos: usize,
}

const READ_CHUNK: usize = 8192;

impl FileState {
    pub fn new(file: std::fs::File) -> Self {
        FileState {
            file,
            buf: Vec::new(),
            pos: 0,
        }
    }

    pub fn file(&self) -> &std::fs::File {
        &self.file
    }

    /// Refills the buffer when it is used up; false at the end of the file.
    fn fill(&mut self) -> std::io::Result<bool> {
        if self.pos < self.buf.len() {
            return Ok(true);
        }
        self.buf.resize(READ_CHUNK, 0);
        self.pos = 0;
        loop {
            match self.file.read(&mut self.buf) {
                Ok(n) => {
                    self.buf.truncate(n);
                    return Ok(n > 0);
                }
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {}
                Err(e) => {
                    self.buf.clear();
                    return Err(e);
                }
            }
        }
    }

    /// Up to `n` bytes, fewer only at the end of the file (like `fread`).
    fn read(&mut self, n: usize, out: &mut [u8]) -> std::io::Result<usize> {
        let mut got = 0;
        while got < n {
            if !self.fill()? {
                break;
            }
            let k = (self.buf.len() - self.pos).min(n - got);
            out[got..got + k].copy_from_slice(&self.buf[self.pos..self.pos + k]);
            self.pos += k;
            got += k;
        }
        Ok(got)
    }

    /// Up to and including the next newline.
    fn get_line(&mut self) -> std::io::Result<Vec<u8>> {
        let mut line = Vec::new();
        while self.fill()? {
            let rest = &self.buf[self.pos..];
            match rest.iter().position(|&b| b == b'\n') {
                Some(i) => {
                    line.extend_from_slice(&rest[..=i]);
                    self.pos += i + 1;
                    break;
                }
                None => {
                    line.extend_from_slice(rest);
                    self.pos = self.buf.len();
                }
            }
        }
        Ok(line)
    }

    /// Moves the file position back over the bytes read ahead, so that the file position is
    /// the reader's.
    fn unread(&mut self) -> std::io::Result<()> {
        let ahead = self.buf.len() - self.pos;
        self.buf.clear();
        self.pos = 0;
        if ahead > 0 {
            self.file.seek(SeekFrom::Current(-(ahead as i64)))?;
        }
        Ok(())
    }

    fn write(&mut self, bytes: &[u8]) -> std::io::Result<()> {
        self.unread()?;
        self.file.write_all(bytes)
    }

    fn rewind(&mut self) -> std::io::Result<()> {
        self.buf.clear();
        self.pos = 0;
        self.file.seek(SeekFrom::Start(0)).map(|_| ())
    }

    fn truncate(&mut self) -> std::io::Result<()> {
        self.unread()?;
        let at = self.file.stream_position()?;
        self.file.set_len(at)
    }
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

/// An `IO.FS.Handle` for the file `f`.
#[cfg(unix)]
pub(crate) unsafe fn wrap_file(f: std::fs::File) -> Obj {
    lean_io_wrap_handle(HandleFile::File(RefCell::new(FileState::new(f))))
}

pub(crate) unsafe fn handle_file<'a>(h: Obj) -> &'a HandleFile {
    &*(lean_get_external_data(h) as *const HandleFile)
}

fn write_to(f: &HandleFile, bytes: &[u8]) -> std::io::Result<()> {
    match f {
        HandleFile::Stdout => std::io::stdout().write_all(bytes),
        HandleFile::Stderr => std::io::stderr().write_all(bytes),
        HandleFile::Stdin => Err(std::io::Error::from_raw_os_error(EBADF)),
        HandleFile::File(s) => s.borrow_mut().write(bytes),
    }
}

/// `Handle.mk : (@& FilePath) → FS.Mode → IO Handle`: `read`, `write`, `writeNew`, `readWrite`
/// or `append` (0–4).
#[cfg(unix)]
pub unsafe fn lean_io_prim_handle_mk(fname: Obj, mode: u8) -> Obj {
    let path = match crate::fs::path_of(fname) {
        Ok(p) => p,
        Err(e) => return e,
    };
    let mut o = std::fs::OpenOptions::new();
    match mode {
        0 => o.read(true),
        1 => o.write(true).create(true).truncate(true),
        2 => o.write(true).create_new(true),
        3 => o.read(true).write(true),
        _ => o.append(true).create(true),
    };
    match o.open(path) {
        Ok(f) => lean_io_result_mk_ok(wrap_file(f)),
        Err(e) => lean_io_result_mk_error(of_std(&e, Some(fname))),
    }
}

#[cfg(not(unix))]
pub unsafe fn lean_io_prim_handle_mk(_fname: Obj, _mode: u8) -> Obj {
    io_result_unsupported("opening a file")
}

/// `Handle.flush : (@& Handle) → IO Unit`.
pub unsafe fn lean_io_prim_handle_flush(h: Obj) -> Obj {
    io_unit(match handle_file(h) {
        HandleFile::Stdout => std::io::stdout().flush(),
        HandleFile::Stderr => std::io::stderr().flush(),
        HandleFile::Stdin => Ok(()),
        HandleFile::File(s) => s.borrow_mut().file.flush(),
    })
}

/// `Handle.putStr : (@& Handle) → (@& String) → IO Unit`.
pub unsafe fn lean_io_prim_handle_put_str(h: Obj, s: Obj) -> Obj {
    io_unit(write_to(handle_file(h), lean_string_bytes(s)))
}

/// `Handle.write : (@& Handle) → (@& ByteArray) → IO Unit`.
pub unsafe fn lean_io_prim_handle_write(h: Obj, buf: Obj) -> Obj {
    io_unit(write_to(handle_file(h), sarray_bytes(buf)))
}

/// `Handle.getLine : (@& Handle) → IO String`: up to and including the next newline.
pub unsafe fn lean_io_prim_handle_get_line(h: Obj) -> Obj {
    let r = match handle_file(h) {
        HandleFile::Stdin => {
            let mut line = Vec::new();
            std::io::stdin()
                .lock()
                .read_until(b'\n', &mut line)
                .map(|_| line)
        }
        HandleFile::File(s) => s.borrow_mut().get_line(),
        _ => Err(std::io::Error::from_raw_os_error(EBADF)),
    };
    match r {
        Ok(line) => lean_io_result_mk_ok(lean_mk_string_from_bytes(&line)),
        Err(e) => io_result_of_error(&e),
    }
}

/// `Handle.read : (@& Handle) → USize → IO ByteArray`.
pub unsafe fn lean_io_prim_handle_read(h: Obj, nbytes: usize) -> Obj {
    let f = handle_file(h);
    if matches!(f, HandleFile::Stdout | HandleFile::Stderr) {
        return io_result_of_error(&std::io::Error::from_raw_os_error(EBADF));
    }
    let r = lean_alloc_sarray(1, 0, nbytes);
    let buf = core::slice::from_raw_parts_mut(lean_sarray_cptr(r), nbytes);
    let n = match f {
        HandleFile::File(s) => s.borrow_mut().read(nbytes, buf),
        _ => std::io::stdin().lock().read(buf),
    };
    match n {
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

/// `Handle.isTty : (@& Handle) → BaseIO Bool`.
pub unsafe fn lean_io_prim_handle_is_tty(h: Obj) -> u8 {
    use std::io::IsTerminal;
    (match handle_file(h) {
        HandleFile::Stdin => std::io::stdin().is_terminal(),
        HandleFile::Stdout => std::io::stdout().is_terminal(),
        HandleFile::Stderr => std::io::stderr().is_terminal(),
        HandleFile::File(s) => s.borrow().file.is_terminal(),
    }) as u8
}

/// `Handle.rewind : (@& Handle) → IO Unit`.
pub unsafe fn lean_io_prim_handle_rewind(h: Obj) -> Obj {
    io_unit(match handle_file(h) {
        HandleFile::File(s) => s.borrow_mut().rewind(),
        _ => Err(std::io::Error::from_raw_os_error(ESPIPE)),
    })
}

/// `Handle.truncate : (@& Handle) → IO Unit`: truncates the file at the reader's position.
pub unsafe fn lean_io_prim_handle_truncate(h: Obj) -> Obj {
    io_unit(match handle_file(h) {
        HandleFile::File(s) => s.borrow_mut().truncate(),
        _ => Err(std::io::Error::from_raw_os_error(EINVAL)),
    })
}

#[cfg(unix)]
fn raw_fd(f: &HandleFile) -> i32 {
    use std::os::fd::AsRawFd;
    match f {
        HandleFile::Stdin => 0,
        HandleFile::Stdout => 1,
        HandleFile::Stderr => 2,
        HandleFile::File(s) => s.borrow().file.as_raw_fd(),
    }
}

#[cfg(unix)]
fn flock(f: &HandleFile, op: i32) -> std::io::Result<()> {
    if unsafe { libc::flock(raw_fd(f), op) } == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

/// `Handle.lock : (@& Handle) → (exclusive : Bool) → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_io_prim_handle_lock(h: Obj, exclusive: u8) -> Obj {
    let op = if exclusive != 0 {
        libc::LOCK_EX
    } else {
        libc::LOCK_SH
    };
    io_unit(flock(handle_file(h), op))
}

/// `Handle.tryLock : (@& Handle) → (exclusive : Bool) → IO Bool`.
#[cfg(unix)]
pub unsafe fn lean_io_prim_handle_try_lock(h: Obj, exclusive: u8) -> Obj {
    let op = if exclusive != 0 {
        libc::LOCK_EX
    } else {
        libc::LOCK_SH
    };
    match flock(handle_file(h), op | libc::LOCK_NB) {
        Ok(()) => lean_io_result_mk_ok(lean_box(1)),
        Err(e) if e.raw_os_error() == Some(libc::EWOULDBLOCK) => lean_io_result_mk_ok(lean_box(0)),
        Err(e) => io_result_of_error(&e),
    }
}

/// `Handle.unlock : (@& Handle) → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_io_prim_handle_unlock(h: Obj) -> Obj {
    io_unit(flock(handle_file(h), libc::LOCK_UN))
}

#[cfg(not(unix))]
pub unsafe fn lean_io_prim_handle_lock(_h: Obj, _exclusive: u8) -> Obj {
    io_result_unsupported("locking a file")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_prim_handle_try_lock(_h: Obj, _exclusive: u8) -> Obj {
    io_result_unsupported("locking a file")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_prim_handle_unlock(_h: Obj) -> Obj {
    io_result_unsupported("locking a file")
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

#[cfg(unix)]
fn mono_base() -> std::time::Instant {
    static BASE: std::sync::OnceLock<std::time::Instant> = std::sync::OnceLock::new();
    *BASE.get_or_init(std::time::Instant::now)
}

/// The time since the first call; zero on a target without a clock.
pub(crate) fn mono_elapsed() -> std::time::Duration {
    #[cfg(unix)]
    {
        mono_base().elapsed()
    }
    #[cfg(not(unix))]
    {
        std::time::Duration::ZERO
    }
}

/// `IO.monoMsNow : BaseIO Nat`.
pub unsafe fn lean_io_mono_ms_now() -> Obj {
    lean_uint64_to_nat(mono_elapsed().as_millis() as u64 + 1)
}

/// `IO.monoNanosNow : BaseIO Nat`.
pub unsafe fn lean_io_mono_nanos_now() -> Obj {
    lean_uint64_to_nat(mono_elapsed().as_nanos() as u64 + 1)
}

/// `IO.Process.exit : UInt8 → IO α`.
#[cfg(unix)]
pub unsafe fn lean_io_exit(code: u8) -> Obj {
    let _ = std::io::stdout().flush();
    std::process::exit(code as i32)
}

#[cfg(not(unix))]
pub unsafe fn lean_io_exit(_code: u8) -> Obj {
    io_result_unsupported("exiting the process")
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
