"""IO externs of the runtime: results, handles and streams, ``ST.Ref``, the file system, the
environment of the process, child processes, promises and tasks of ``BaseIO`` actions.

In Lean 4.35 an ``IO`` action returns an ``EST.Out`` (``ok`` = constructor 0, ``error`` =
constructor 1, one object field), while a ``BaseIO``/``ST`` action returns its value itself.
The world parameter has the IR type ``void`` and is not passed to externs; closures over IO
actions receive it as ``0``. The behavior follows Lean's ``io.cpp`` and ``process.cpp``.
"""

import errno as E
import fcntl
import os
import signal
import sys
import tempfile
import threading
import time

from lean_python.runtime import (
    Closure,
    Ctor,
    LArray,
    LByteArray,
    Task,
    lean_apply,
    lean_dec,
    lean_inc,
    lean_internal_panic,
    lean_mark_persistent,
    register_external,
)

# ---------------------------------------------------------------------------
# Results


def io_ok(a):
    return Ctor(0, [a])


def io_error(e):
    return Ctor(1, [e])


# ---------------------------------------------------------------------------
# IO.Error

ALREADY_EXISTS = 0
OTHER_ERROR = 1
RESOURCE_BUSY = 2
RESOURCE_VANISHED = 3
UNSUPPORTED_OPERATION = 4
HARDWARE_FAULT = 5
UNSATISFIED_CONSTRAINTS = 6
ILLEGAL_OPERATION = 7
PROTOCOL_ERROR = 8
TIME_EXPIRED = 9
INTERRUPTED = 10
NO_FILE_OR_DIRECTORY = 11
INVALID_ARGUMENT = 12
PERMISSION_DENIED = 13
RESOURCE_EXHAUSTED = 14
INAPPROPRIATE_TYPE = 15
NO_SUCH_THING = 16
UNEXPECTED_EOF = 17
USER_ERROR = 18


def _has_filename(tag):
    return tag == ALREADY_EXISTS or INTERRUPTED <= tag <= NO_SUCH_THING


def _mk_error(tag, fname, code, details):
    if _has_filename(tag):
        if fname is None:
            f = 0
        elif tag in (INTERRUPTED, NO_FILE_OR_DIRECTORY):
            f = fname
        else:
            f = Ctor(1, [fname])
        r = Ctor(tag, [f, details])
        r.sc[16] = code
        return r
    r = Ctor(tag, [details])
    r.sc[8] = code
    return r


def mk_user_error(msg):
    return Ctor(USER_ERROR, [msg])


def _embedded_nul_error(s):
    return _mk_error(INVALID_ARGUMENT, s, E.EINVAL, b"string contains NUL bytes")


def _file_not_found_error(fname):
    return _mk_error(NO_FILE_OR_DIRECTORY, fname, E.ENOENT, b"")


_UV_MESSAGES = [
    ("E2BIG", "argument list too long"),
    ("EACCES", "permission denied"),
    ("EADDRINUSE", "address already in use"),
    ("EADDRNOTAVAIL", "address not available"),
    ("EAFNOSUPPORT", "address family not supported"),
    ("EAGAIN", "resource temporarily unavailable"),
    ("EBADF", "bad file descriptor"),
    ("EBUSY", "resource busy or locked"),
    ("ECONNABORTED", "software caused connection abort"),
    ("ECONNREFUSED", "connection refused"),
    ("ECONNRESET", "connection reset by peer"),
    ("EDESTADDRREQ", "destination address required"),
    ("EEXIST", "file already exists"),
    ("EFAULT", "bad address in system call argument"),
    ("EFBIG", "file too large"),
    ("EHOSTUNREACH", "host is unreachable"),
    ("EILSEQ", "illegal byte sequence"),
    ("EINTR", "interrupted system call"),
    ("EINVAL", "invalid argument"),
    ("EIO", "i/o error"),
    ("EISCONN", "socket is already connected"),
    ("EISDIR", "illegal operation on a directory"),
    ("ELOOP", "too many symbolic links encountered"),
    ("EMFILE", "too many open files"),
    ("EMLINK", "too many links"),
    ("EMSGSIZE", "message too long"),
    ("ENAMETOOLONG", "name too long"),
    ("ENETDOWN", "network is down"),
    ("ENETUNREACH", "network is unreachable"),
    ("ENFILE", "file table overflow"),
    ("ENOBUFS", "no buffer space available"),
    ("ENODEV", "no such device"),
    ("ENOENT", "no such file or directory"),
    ("ENOMEM", "not enough memory"),
    ("ENOPROTOOPT", "protocol not available"),
    ("ENOSPC", "no space left on device"),
    ("ENOSYS", "function not implemented"),
    ("ENOTCONN", "socket is not connected"),
    ("ENOTDIR", "not a directory"),
    ("ENOTEMPTY", "directory not empty"),
    ("ENOTSOCK", "socket operation on non-socket"),
    ("ENOTTY", "inappropriate ioctl for device"),
    ("ENXIO", "no such device or address"),
    ("EOPNOTSUPP", "operation not supported on socket"),
    ("EPERM", "operation not permitted"),
    ("EPIPE", "broken pipe"),
    ("EPROTO", "protocol error"),
    ("EPROTONOSUPPORT", "protocol not supported"),
    ("EPROTOTYPE", "protocol wrong type for socket"),
    ("ERANGE", "result too large"),
    ("EROFS", "read-only file system"),
    ("ESPIPE", "invalid seek"),
    ("ESRCH", "no such process"),
    ("ETIMEDOUT", "connection timed out"),
    ("ETXTBSY", "text file is busy"),
    ("EXDEV", "cross-device link not permitted"),
    ("ENODATA", "no data available"),
]
_UV = {}
for _name, _msg in _UV_MESSAGES:
    if hasattr(E, _name):
        _UV.setdefault(getattr(E, _name), _msg)

_APPROX = {}
for _src, _dst in (
    ("ENOMSG", "ENODATA"),
    ("ENOEXEC", "EINVAL"),
    ("EDOM", "EINVAL"),
    ("ENOSTR", "EINVAL"),
    ("EBADMSG", "EPROTO"),
    ("ECHILD", "ESRCH"),
    ("EDEADLK", "EBUSY"),
    ("EIDRM", "EPIPE"),
    ("EINPROGRESS", "EISCONN"),
    ("ENETRESET", "ECONNRESET"),
    ("ENOLINK", "ECONNRESET"),
    ("ENOLCK", "EAGAIN"),
    ("ENOSR", "ENOBUFS"),
    ("ETIME", "ETIMEDOUT"),
):
    if hasattr(E, _src) and hasattr(E, _dst):
        _APPROX[getattr(E, _src)] = getattr(E, _dst)


def _codes(*names):
    return {getattr(E, n) for n in names if hasattr(E, n)}


_KINDS = [
    (_codes("EINTR"), INTERRUPTED),
    (
        _codes("ELOOP", "ENAMETOOLONG", "EDESTADDRREQ", "EBADF", "EINVAL", "EILSEQ", "ENOTCONN", "ENOTSOCK"),
        INVALID_ARGUMENT,
    ),
    (_codes("ENOENT"), NO_FILE_OR_DIRECTORY),
    (_codes("EACCES", "EROFS", "ECONNABORTED", "EFBIG", "EPERM"), PERMISSION_DENIED),
    (
        _codes("EMFILE", "ENFILE", "ENOSPC", "E2BIG", "EAGAIN", "EMLINK", "EMSGSIZE", "ENOBUFS", "ENOMEM"),
        RESOURCE_EXHAUSTED,
    ),
    (_codes("EISDIR", "ENOTDIR"), INAPPROPRIATE_TYPE),
    (_codes("ENXIO", "EHOSTUNREACH", "ENETUNREACH", "ECONNREFUSED", "ENODATA", "ESRCH"), NO_SUCH_THING),
    (_codes("EEXIST", "EISCONN"), ALREADY_EXISTS),
    (_codes("EIO"), HARDWARE_FAULT),
    (_codes("ENOTEMPTY"), UNSATISFIED_CONSTRAINTS),
    (_codes("ENOTTY"), ILLEGAL_OPERATION),
    (_codes("ECONNRESET", "ENETDOWN", "EPIPE"), RESOURCE_VANISHED),
    (_codes("EPROTO", "EPROTONOSUPPORT", "EPROTOTYPE"), PROTOCOL_ERROR),
    (_codes("ETIMEDOUT"), TIME_EXPIRED),
    (_codes("EBUSY", "ETXTBSY", "EADDRINUSE"), RESOURCE_BUSY),
    (
        _codes(
            "EADDRNOTAVAIL",
            "EAFNOSUPPORT",
            "ENODEV",
            "ENOPROTOOPT",
            "ENOSYS",
            "EOPNOTSUPP",
            "ERANGE",
            "ESPIPE",
            "EXDEV",
        ),
        UNSUPPORTED_OPERATION,
    ),
]


def decode_error(errnum, approximate, fname=None):
    """The ``IO.Error`` of the OS error ``errnum`` (``decode_uv_error_impl``)."""
    e = _APPROX.get(errnum, errnum) if approximate else errnum
    msg = _UV.get(e)
    if msg is None:
        uv = 0
        msg = f"Unknown system error {-errnum}"
    else:
        uv = e
    tag = OTHER_ERROR
    if uv != 0:
        for codes, kind in _KINDS:
            if uv in codes:
                tag = kind
                break
    if tag in (INTERRUPTED, NO_FILE_OR_DIRECTORY):
        f = fname if fname is not None else b""
    elif _has_filename(tag):
        f = fname
    else:
        f = None
    return _mk_error(tag, f, errnum, msg.encode())


def _of_os(ex, fname=None, approximate=True):
    if isinstance(ex, OSError) and ex.errno is not None:
        return decode_error(ex.errno, approximate, fname)
    return _mk_error(OTHER_ERROR, None, 0, str(ex).encode())


def _err(ex, fname=None, approximate=True):
    return io_error(_of_os(ex, fname, approximate))


def _decap(s):
    return s[:1].lower() + s[1:] if s else s


def _fopen_error(gist, fname, code, details):
    if details is not None:
        return f"{_decap(gist)} (error code: {code}, {_decap(details)})\n  file: {fname}"
    return f"{_decap(gist)} (error code: {code})\n  file: {fname}"


def _other_error(gist, code, details):
    if details is not None:
        return f"{_decap(gist)} (error code: {code}, {_decap(details)})"
    return f"{_decap(gist)} (error code: {code})"


def _str(b):
    return b.decode("utf-8", "surrogatepass")


def io_error_to_string(e):
    """``IO.Error.toString``."""
    if isinstance(e, int):
        return "end of file"
    tag = e.tag
    if tag == USER_ERROR:
        return _str(e.objs[0])
    if _has_filename(tag):
        f = e.objs[0]
        if tag in (INTERRUPTED, NO_FILE_OR_DIRECTORY):
            fname = _str(f)
        elif isinstance(f, int):
            fname = None
        else:
            fname = _str(f.objs[0])
        details = _str(e.objs[1])
        code = e.sc[16]
    else:
        fname = None
        details = _str(e.objs[0])
        code = e.sc[8]

    def with_file(gist, d):
        if fname is not None:
            return _fopen_error(gist, fname, code, d)
        return _other_error(gist, code, d)

    d = details
    table = {
        INAPPROPRIATE_TYPE: lambda: with_file("inappropriate type", d),
        INTERRUPTED: lambda: with_file("interrupted system call", d),
        INVALID_ARGUMENT: lambda: with_file("invalid argument", d),
        NO_FILE_OR_DIRECTORY: lambda: with_file("no such file or directory", None),
        NO_SUCH_THING: lambda: with_file("no such thing", d),
        PERMISSION_DENIED: lambda: with_file(details, None),
        RESOURCE_EXHAUSTED: lambda: with_file("resource exhausted", d),
        ALREADY_EXISTS: lambda: with_file("already exists", d),
        OTHER_ERROR: lambda: _other_error(details, code, None),
        RESOURCE_BUSY: lambda: _other_error("resource busy", code, d),
        RESOURCE_VANISHED: lambda: _other_error("resource vanished", code, d),
        HARDWARE_FAULT: lambda: _other_error("hardware fault", code, None),
        ILLEGAL_OPERATION: lambda: _other_error("illegal operation", code, d),
        PROTOCOL_ERROR: lambda: _other_error("protocol error", code, d),
        TIME_EXPIRED: lambda: _other_error("time expired", code, d),
        UNSATISFIED_CONSTRAINTS: lambda: _other_error("directory not empty", code, None),
        UNSUPPORTED_OPERATION: lambda: _other_error("unsupported operation", code, d),
    }
    f = table.get(tag)
    return f() if f else ""


def lean_mk_io_user_error(msg):
    return mk_user_error(msg)


def lean_decode_io_error(errnum, fname):
    return decode_error(errnum, True, fname)


def lean_io_result_show_error(r):
    sys.stdout.flush()
    sys.stderr.write(f"uncaught exception: {io_error_to_string(r.objs[0])}\n")
    sys.stderr.flush()


# ---------------------------------------------------------------------------
# Handles

STDIN = 0
STDOUT = 1
STDERR = 2

_READ_CHUNK = 8192


class Handle:
    """An ``IO.FS.Handle``: a standard stream (``std``) or a file descriptor with a read buffer."""

    __slots__ = ("buf", "fd", "pos", "rc", "std")

    def __init__(self, std=None, fd=None):
        self.rc = 1
        self.std = std
        self.fd = fd
        self.buf = b""
        self.pos = 0

    def close(self):
        fd = self.fd
        if fd is not None:
            self.fd = None
            try:
                os.close(fd)
            except OSError:
                pass

    def __del__(self):
        self.close()

    def fill(self):
        if self.pos < len(self.buf):
            return True
        self.pos = 0
        while True:
            try:
                self.buf = os.read(self.fd, _READ_CHUNK)
                return len(self.buf) > 0
            except InterruptedError:
                continue
            except OSError:
                self.buf = b""
                raise

    def read(self, n):
        out = bytearray()
        while len(out) < n:
            if not self.fill():
                break
            k = min(len(self.buf) - self.pos, n - len(out))
            out += self.buf[self.pos : self.pos + k]
            self.pos += k
        return bytes(out)

    def get_line(self):
        line = bytearray()
        while self.fill():
            rest = self.buf[self.pos :]
            i = rest.find(b"\n")
            if i >= 0:
                line += rest[: i + 1]
                self.pos += i + 1
                break
            line += rest
            self.pos = len(self.buf)
        return bytes(line)

    def unread(self):
        ahead = len(self.buf) - self.pos
        self.buf = b""
        self.pos = 0
        if ahead > 0:
            os.lseek(self.fd, -ahead, os.SEEK_CUR)

    def write(self, data):
        self.unread()
        view = memoryview(data)
        while view:
            n = os.write(self.fd, view)
            view = view[n:]

    def rewind(self):
        self.buf = b""
        self.pos = 0
        os.lseek(self.fd, 0, os.SEEK_SET)

    def truncate(self):
        self.unread()
        at = os.lseek(self.fd, 0, os.SEEK_CUR)
        os.ftruncate(self.fd, at)


register_external(Handle, Handle.close)


def _bad(code):
    return OSError(code, os.strerror(code))


def _write_to(h, data):
    if h.std == STDOUT:
        sys.stdout.flush()
        sys.stdout.buffer.write(data)
    elif h.std == STDERR:
        sys.stderr.flush()
        sys.stderr.buffer.write(data)
    elif h.std == STDIN:
        raise _bad(E.EBADF)
    else:
        h.write(data)


def _unit(fn):
    try:
        fn()
        return io_ok(0)
    except OSError as ex:
        return _err(ex)


def _path(p):
    if b"\0" in p:
        return None
    return p


_MODE_FLAGS = {
    0: os.O_RDONLY,
    1: os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
    2: os.O_WRONLY | os.O_CREAT | os.O_EXCL,
    3: os.O_RDWR,
    4: os.O_WRONLY | os.O_APPEND | os.O_CREAT,
}


def lean_io_prim_handle_mk(fname, mode):
    p = _path(fname)
    if p is None:
        return io_error(_embedded_nul_error(fname))
    try:
        fd = os.open(p, _MODE_FLAGS.get(mode, _MODE_FLAGS[4]) | os.O_CLOEXEC, 0o666)
    except OSError as ex:
        return _err(ex, fname)
    return io_ok(Handle(fd=fd))


def lean_io_prim_handle_flush(h):
    def go():
        if h.std == STDOUT:
            sys.stdout.flush()
            sys.stdout.buffer.flush()
        elif h.std == STDERR:
            sys.stderr.flush()
            sys.stderr.buffer.flush()

    return _unit(go)


def lean_io_prim_handle_put_str(h, s):
    return _unit(lambda: _write_to(h, s))


def lean_io_prim_handle_write(h, buf):
    return _unit(lambda: _write_to(h, bytes(buf.data)))


def lean_io_prim_handle_get_line(h):
    try:
        if h.std == STDIN:
            line = sys.stdin.buffer.readline()
        elif h.std is None:
            line = h.get_line()
        else:
            raise _bad(E.EBADF)
    except OSError as ex:
        return _err(ex)
    return io_ok(line)


def lean_io_prim_handle_read(h, nbytes):
    try:
        if h.std in (STDOUT, STDERR):
            raise _bad(E.EBADF)
        if h.std == STDIN:
            data = sys.stdin.buffer.read1(nbytes) if nbytes else b""
        else:
            data = h.read(nbytes)
    except OSError as ex:
        return _err(ex)
    return io_ok(LByteArray(bytearray(data)))


def lean_io_prim_handle_is_tty(h):
    fd = h.std if h.std is not None else h.fd
    return os.isatty(fd)


def lean_io_prim_handle_rewind(h):
    def go():
        if h.std is not None:
            raise _bad(E.ESPIPE)
        h.rewind()

    return _unit(go)


def lean_io_prim_handle_truncate(h):
    def go():
        if h.std is not None:
            raise _bad(E.EINVAL)
        h.truncate()

    return _unit(go)


def _fd(h):
    return h.std if h.std is not None else h.fd


def lean_io_prim_handle_lock(h, exclusive):
    return _unit(lambda: fcntl.flock(_fd(h), fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH))


def lean_io_prim_handle_try_lock(h, exclusive):
    op = fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH
    try:
        fcntl.flock(_fd(h), op | fcntl.LOCK_NB)
        return io_ok(1)
    except BlockingIOError:
        return io_ok(0)
    except OSError as ex:
        if ex.errno in (E.EWOULDBLOCK, E.EAGAIN):
            return io_ok(0)
        return _err(ex)


def lean_io_prim_handle_unlock(h):
    return _unit(lambda: fcntl.flock(_fd(h), fcntl.LOCK_UN))


# ---------------------------------------------------------------------------
# Streams (``IO.FS.Stream.ofHandle``)


def _stream_flush(h, _w):
    return lean_io_prim_handle_flush(h)


def _stream_read(h, n, _w):
    return lean_io_prim_handle_read(h, n)


def _stream_write(h, b, _w):
    return lean_io_prim_handle_write(h, b)


def _stream_get_line(h, _w):
    return lean_io_prim_handle_get_line(h)


def _stream_put_str(h, s, _w):
    return lean_io_prim_handle_put_str(h, s)


def _stream_is_tty(h, _w):
    return lean_io_prim_handle_is_tty(h)


def lean_stream_of_handle(h):
    return Ctor(
        0,
        [
            Closure(_stream_flush, 2, [h]),
            Closure(_stream_read, 3, [h]),
            Closure(_stream_write, 3, [h]),
            Closure(_stream_get_line, 2, [h]),
            Closure(_stream_put_str, 3, [h]),
            Closure(_stream_is_tty, 2, [h]),
        ],
    )


_streams = threading.local()


def _current(name, std):
    s = getattr(_streams, name, None)
    if s is None:
        s = lean_mark_persistent(lean_stream_of_handle(Handle(std=std)))
        setattr(_streams, name, s)
    return s


def _swap(name, std, h):
    old = _current(name, std)
    setattr(_streams, name, lean_mark_persistent(h))
    return old


def lean_get_stdin():
    return _current("stdin", STDIN)


def lean_get_stdout():
    return _current("stdout", STDOUT)


def lean_get_stderr():
    return _current("stderr", STDERR)


def lean_get_set_stdin(h):
    return _swap("stdin", STDIN, h)


def lean_get_set_stdout(h):
    return _swap("stdout", STDOUT, h)


def lean_get_set_stderr(h):
    return _swap("stderr", STDERR, h)


# ---------------------------------------------------------------------------
# ST.Ref


class STRef:
    __slots__ = ("value",)

    def __init__(self, value):
        self.value = value


def lean_st_mk_ref(a):
    return STRef(a)


def lean_st_ref_get(r):
    v = r.value
    if v is None:
        _internal("null reference read")
    lean_inc(v)
    return v


def lean_st_ref_take(r):
    v = r.value
    if v is None:
        _internal("null reference read")
    r.value = None
    return v


def lean_st_ref_put(r, a):
    r.value = a
    return 0


def lean_st_ref_swap(r, a):
    old = r.value
    if old is None:
        _internal("null reference read")
    r.value = a
    return old


def lean_st_ref_ptr_eq(r1, r2):
    return r1 is r2


def _internal(msg):
    lean_internal_panic(msg)


# ---------------------------------------------------------------------------
# Clocks

_MONO_BASE = time.monotonic_ns()


def lean_io_mono_ms_now():
    return (time.monotonic_ns() - _MONO_BASE) // 1_000_000 + 1


def lean_io_mono_nanos_now():
    return time.monotonic_ns() - _MONO_BASE + 1


# ---------------------------------------------------------------------------
# Platform


def lean_system_platform_windows(_unit=0):
    return sys.platform == "win32"


def lean_system_platform_osx(_unit=0):
    return sys.platform == "darwin"


def lean_system_platform_linux(_unit=0):
    return sys.platform.startswith("linux")


def lean_system_platform_emscripten(_unit=0):
    return sys.platform == "emscripten"


def lean_internal_get_hardware_concurrency(_unit=0):
    return os.cpu_count() or 0


# ---------------------------------------------------------------------------
# Files and directories


def _with_path(p, fn):
    if b"\0" in p:
        return io_error(_embedded_nul_error(p))
    return fn(p)


def _unit_or(fn, fname, approximate=True):
    try:
        fn()
        return io_ok(0)
    except OSError as ex:
        return _err(ex, fname, approximate)


def lean_io_read_dir(d):
    def go(p):
        try:
            names = os.listdir(p)
        except OSError as ex:
            return _err(ex, d)
        return io_ok(LArray([Ctor(0, [d, n]) for n in names]))

    return _with_path(d, go)


def _system_time(sec, nsec):
    o = Ctor(0, [sec])
    o.sc[8] = nsec
    return o


def _metadata_obj(st):
    import stat

    o = Ctor(
        0,
        [
            _system_time(int(st.st_atime_ns // 1_000_000_000), st.st_atime_ns % 1_000_000_000),
            _system_time(int(st.st_mtime_ns // 1_000_000_000), st.st_mtime_ns % 1_000_000_000),
        ],
    )
    o.sc[16] = st.st_size
    o.sc[24] = st.st_nlink
    m = st.st_mode
    if stat.S_ISDIR(m):
        ty = 0
    elif stat.S_ISREG(m):
        ty = 1
    elif stat.S_ISLNK(m):
        ty = 2
    else:
        ty = 3
    o.sc[32] = ty
    return o


def lean_io_metadata(fname):
    def go(p):
        try:
            return io_ok(_metadata_obj(os.stat(p)))
        except OSError as ex:
            return _err(ex, fname, False)

    return _with_path(fname, go)


def lean_io_symlink_metadata(fname):
    def go(p):
        try:
            return io_ok(_metadata_obj(os.lstat(p)))
        except OSError as ex:
            return _err(ex, fname, False)

    return _with_path(fname, go)


def lean_io_create_dir(p):
    return _with_path(p, lambda q: _unit_or(lambda: os.mkdir(q, 0o777), p))


def lean_io_remove_dir(p):
    return _with_path(p, lambda q: _unit_or(lambda: os.rmdir(q), p))


def lean_io_remove_file(p):
    return _with_path(p, lambda q: _unit_or(lambda: os.unlink(q), p, False))


def lean_io_rename(src, dst):
    if b"\0" in src:
        return io_error(_embedded_nul_error(src))
    if b"\0" in dst:
        return io_error(_embedded_nul_error(dst))
    try:
        os.rename(src, dst)
        return io_ok(0)
    except OSError as ex:
        return _err(ex, src + b" and/or " + dst)


def lean_io_hard_link(orig, link):
    if b"\0" in orig:
        return io_error(_embedded_nul_error(orig))
    if b"\0" in link:
        return io_error(_embedded_nul_error(link))
    return _unit_or(lambda: os.link(orig, link), orig, False)


def lean_io_realpath(fname):
    def go(p):
        try:
            return io_ok(os.path.realpath(p, strict=True))
        except OSError:
            return io_error(_file_not_found_error(fname))

    return _with_path(fname, go)


def lean_chmod(fname, mode):
    return _with_path(fname, lambda p: _unit_or(lambda: os.chmod(p, mode), fname))


def _temp_dir():
    for v in ("TMPDIR", "TMP", "TEMP", "TEMPDIR"):
        d = os.environb.get(v.encode())
        if d:
            break
    else:
        d = b"/tmp"
    if len(d) > 1 and d.endswith(b"/"):
        d = d[:-1]
    return d


def lean_io_create_tempfile():
    try:
        fd, path = tempfile.mkstemp(prefix=b"tmp.", dir=_temp_dir())
    except OSError as ex:
        return _err(ex, None, False)
    return io_ok(Ctor(0, [Handle(fd=fd), path]))


def lean_io_create_tempdir():
    try:
        path = tempfile.mkdtemp(prefix=b"tmp.", dir=_temp_dir())
    except OSError as ex:
        return _err(ex, None, False)
    return io_ok(path)


# ---------------------------------------------------------------------------
# The process


def lean_io_getenv(var):
    if b"\0" in var:
        return 0
    v = os.environb.get(var)
    return 0 if v is None else Ctor(1, [v])


def lean_io_app_path():
    try:
        return io_ok(os.path.realpath(os.fsencode(sys.executable), strict=True))
    except OSError:
        return io_error(mk_user_error(b"failed to locate application"))


def lean_io_current_dir():
    try:
        return io_ok(os.getcwdb())
    except OSError:
        return io_error(mk_user_error(b"failed to retrieve current working directory"))


def lean_io_process_get_current_dir():
    try:
        return io_ok(os.getcwdb())
    except OSError as ex:
        return _err(ex)


def lean_io_process_set_current_dir(p):
    return _with_path(p, lambda q: _unit_or(lambda: os.chdir(q), p))


def lean_io_process_get_pid():
    return os.getpid()


def lean_io_get_tid():
    return threading.get_native_id()


def lean_io_get_random_bytes(n):
    if n == 0:
        return io_ok(LByteArray(bytearray()))
    try:
        return io_ok(LByteArray(bytearray(os.urandom(n))))
    except OSError as ex:
        return _err(ex)


def lean_io_exit(code):
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(code)


def lean_io_force_exit(code):
    os._exit(code)


def lean_runtime_mark_persistent(a):
    return lean_mark_persistent(a)


def lean_runtime_mark_multi_threaded(a):
    return a


# ---------------------------------------------------------------------------
# Child processes

PIPED = 0
INHERIT = 1
NULL = 2


def _cstr(b):
    i = b.find(b"\0")
    return b if i < 0 else b[:i]


def lean_io_process_spawn(args):
    cfg = args.objs[0]
    modes = [cfg.sc.get(0, INHERIT), cfg.sc.get(1, INHERIT), cfg.sc.get(2, INHERIT)]
    cmd = _cstr(args.objs[1])
    argv = [cmd] + [_cstr(a) for a in args.objs[2].data]
    cwd = args.objs[3]
    env = args.objs[4]
    inherit_env = bool(args.sc.get(40, 1))
    do_setsid = bool(args.sc.get(41, 0))
    sys.stdout.flush()
    sys.stderr.flush()

    pipes = [None, None, None]
    try:
        for i in range(3):
            if modes[i] == PIPED:
                pipes[i] = os.pipe2(os.O_CLOEXEC)
    except OSError as ex:
        return _err(ex)

    child_env = dict(os.environb) if inherit_env else {}
    for pair in env.data:
        k = _cstr(pair.objs[0])
        v = pair.objs[1]
        if isinstance(v, int):
            child_env.pop(k, None)
        else:
            child_env[k] = _cstr(v.objs[0])
    cwd_c = None if isinstance(cwd, int) else _cstr(cwd.objs[0])
    cwd_msg = b"could not change directory to " + (cwd_c or b"") + b"\n"
    exec_msg = b"could not execute external process '" + cmd + b"'\n"

    try:
        pid = os.fork()
    except OSError as ex:
        for p in pipes:
            if p:
                os.close(p[0])
                os.close(p[1])
        return _err(ex)
    if pid == 0:
        try:
            for i, target in enumerate((0, 1, 2)):
                p = pipes[i]
                if p is not None:
                    r, w = p
                    if target == 0:
                        os.dup2(r, 0)
                        os.close(w)
                    else:
                        os.dup2(w, target)
                        os.close(r)
                elif modes[i] == NULL:
                    fd = os.open(b"/dev/null", os.O_RDONLY if target == 0 else os.O_WRONLY)
                    os.dup2(fd, target)
            if cwd_c is not None:
                try:
                    os.chdir(cwd_c)
                except OSError:
                    os.write(2, cwd_msg)
                    os._exit(255)
            if do_setsid:
                os.setsid()
            try:
                os.execvpe(cmd, argv, child_env)
            except OSError:
                pass
            os.write(2, exec_msg)
        finally:
            os._exit(255)

    handles = []
    for i, p in enumerate(pipes):
        if p is None:
            handles.append(0)
            continue
        r, w = p
        ours, theirs = (w, r) if i == 0 else (r, w)
        os.close(theirs)
        handles.append(Handle(fd=ours))
    child = Ctor(0, handles)
    child.sc[24] = pid
    child.sc[28] = 1 if do_setsid else 0
    return io_ok(child)


def _exit_code(status):
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    return 128 + os.WTERMSIG(status)


def lean_io_process_child_wait(_cfg, child):
    try:
        _, status = os.waitpid(child.sc[24], 0)
    except OSError as ex:
        return _err(ex)
    return io_ok(_exit_code(status))


def lean_io_process_child_try_wait(_cfg, child):
    try:
        pid, status = os.waitpid(child.sc[24], os.WNOHANG)
    except OSError as ex:
        return _err(ex)
    if pid == 0:
        return io_ok(0)
    return io_ok(Ctor(1, [_exit_code(status)]))


def lean_io_process_child_kill(_cfg, child):
    pid = child.sc[24]
    try:
        if child.sc.get(28, 0):
            os.killpg(pid, signal.SIGKILL)
        else:
            os.kill(pid, signal.SIGKILL)
    except OSError as ex:
        return _err(ex)
    return io_ok(0)


def lean_io_process_child_pid(_cfg, child):
    return child.sc[24]


def lean_io_process_child_take_stdin(_cfg, child):
    out, err = child.objs[1], child.objs[2]
    lean_inc(out)
    lean_inc(err)
    rest = Ctor(0, [0, out, err])
    rest.sc[24] = child.sc[24]
    rest.sc[28] = child.sc.get(28, 0)
    stdin = child.objs[0]
    lean_inc(stdin)
    lean_dec(child)
    return io_ok(Ctor(0, [stdin, rest]))


# ---------------------------------------------------------------------------
# Tasks of BaseIO actions and promises (tasks run synchronously)


def lean_io_as_task(act, prio=0):
    return Task(lean_mark_persistent(lean_apply(act, [0])))


def lean_io_map_task(f, t, prio=0, sync=0):
    return Task(lean_mark_persistent(lean_apply(f, [t.value, 0])))


def lean_io_bind_task(t, f, prio=0, sync=0):
    return lean_apply(f, [t.value, 0])


def lean_io_check_canceled():
    return False


def lean_io_cancel(t):
    return 0


def lean_io_get_task_state(t):
    return 1 if t.value is None else 2


def lean_io_wait_any(tasks):
    return tasks.objs[0].value


class Promise:
    __slots__ = ("task",)

    def __init__(self):
        self.task = Task(None)


def lean_io_promise_new():
    return Promise()


def lean_io_promise_resolve(value, p):
    if p.task.value is None:
        p.task.value = lean_mark_persistent(Ctor(1, [value]))
    return 0


def lean_io_promise_result_opt(p):
    return p.task
