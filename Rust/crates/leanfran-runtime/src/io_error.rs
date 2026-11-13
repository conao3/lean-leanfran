//! `IO.Error`: its constructors, the translation of OS error codes (`lean_decode_io_error`,
//! after libuv's classification and messages, as the C runtime does), and `IO.Error.toString`.

use crate::model::scalar_offset;
use crate::object::*;
use crate::string::{lean_mk_string, lean_string_to_str};

/* Constructor indices of `IO.Error` */

const ALREADY_EXISTS: u32 = 0;
pub(crate) const OTHER_ERROR: u32 = 1;
const RESOURCE_BUSY: u32 = 2;
const RESOURCE_VANISHED: u32 = 3;
const UNSUPPORTED_OPERATION: u32 = 4;
const HARDWARE_FAULT: u32 = 5;
const UNSATISFIED_CONSTRAINTS: u32 = 6;
const ILLEGAL_OPERATION: u32 = 7;
const PROTOCOL_ERROR: u32 = 8;
const TIME_EXPIRED: u32 = 9;
const INTERRUPTED: u32 = 10;
const NO_FILE_OR_DIRECTORY: u32 = 11;
const INVALID_ARGUMENT: u32 = 12;
const PERMISSION_DENIED: u32 = 13;
const RESOURCE_EXHAUSTED: u32 = 14;
const INAPPROPRIATE_TYPE: u32 = 15;
const NO_SUCH_THING: u32 = 16;
pub(crate) const UNEXPECTED_EOF: u32 = 17;
pub(crate) const USER_ERROR: u32 = 18;

/// Whether the constructor `tag` has a file name field (`String` or `Option String`) before
/// `details`.
fn has_filename(tag: u32) -> bool {
    tag == ALREADY_EXISTS || (INTERRUPTED..=NO_SUCH_THING).contains(&tag)
}

/// A constructor with `osCode` and `details` (consumed) and, when `fname` is given, a file name
/// (consumed): `Option String` for the constructors whose file name is optional.
unsafe fn mk_error(tag: u32, fname: Option<Obj>, code: u32, details: Obj) -> Obj {
    if has_filename(tag) {
        let r = lean_alloc_ctor(tag, 2, 4);
        let f = match fname {
            Some(f) if tag == INTERRUPTED || tag == NO_FILE_OR_DIRECTORY => f,
            Some(f) => {
                let s = lean_alloc_ctor(1, 1, 0);
                lean_ctor_set(s, 0, f);
                s
            }
            None => lean_box(0),
        };
        lean_ctor_set(r, 0, f);
        lean_ctor_set(r, 1, details);
        lean_ctor_set_uint32(r, scalar_offset(2, 0), code);
        r
    } else {
        if let Some(f) = fname {
            lean_dec(f);
        }
        let r = lean_alloc_ctor(tag, 1, 4);
        lean_ctor_set(r, 0, details);
        lean_ctor_set_uint32(r, scalar_offset(1, 0), code);
        r
    }
}

/// `IO.userError msg` (consumes `msg`).
pub unsafe fn lean_mk_io_user_error(msg: Obj) -> Obj {
    let r = lean_alloc_ctor(USER_ERROR, 1, 0);
    lean_ctor_set(r, 0, msg);
    r
}

/// `IO.Error.otherError code details` (consumes `details`).
pub unsafe fn lean_mk_io_error_other_error(code: u32, details: Obj) -> Obj {
    mk_error(OTHER_ERROR, None, code, details)
}

/// `IO.Error.unexpectedEof`.
pub unsafe fn lean_mk_io_error_eof(_unit: Obj) -> Obj {
    lean_box(UNEXPECTED_EOF as usize)
}

/// The OS error codes that the runtime raises itself (Linux's on a target without an OS).
#[cfg(unix)]
pub(crate) use libc::{EBADF, EINVAL, ENOENT, ESPIPE};
#[cfg(not(unix))]
pub(crate) const EBADF: i32 = 9;
#[cfg(not(unix))]
pub(crate) const EINVAL: i32 = 22;
#[cfg(not(unix))]
pub(crate) const ESPIPE: i32 = 29;

/// `IO.Error.unsupportedOperation 0 "<what> is not supported on <target>"`: the error of the
/// operations that need an OS, on a target without one.
#[cfg(not(unix))]
pub(crate) unsafe fn unsupported_error(what: &str) -> Obj {
    let msg = format!("{what} is not supported on {}", env!("LEANFRAN_TARGET"));
    mk_error(UNSUPPORTED_OPERATION, None, 0, lean_mk_string(&msg))
}

/// `IO.Error.noFileOrDirectory fname ENOENT ""` (borrows `fname`).
#[cfg(unix)]
pub(crate) unsafe fn file_not_found_error(fname: Obj) -> Obj {
    lean_inc(fname);
    mk_error(
        NO_FILE_OR_DIRECTORY,
        Some(fname),
        ENOENT as u32,
        lean_mk_string(""),
    )
}

/// `IO.Error.invalidArgument (some s) EINVAL "string contains NUL bytes"` (borrows `s`).
#[cfg(unix)]
pub(crate) unsafe fn embedded_nul_error(s: Obj) -> Obj {
    lean_inc(s);
    mk_error(
        INVALID_ARGUMENT,
        Some(s),
        EINVAL as u32,
        lean_mk_string("string contains NUL bytes"),
    )
}

/* OS error codes */

/// The libuv error of an OS error code: `(errno of the libuv code, libuv's message)`. The OS
/// codes of the platform are compared by name through `libc`.
#[cfg(unix)]
fn uv_of_errno(e: i32, approximate: bool) -> Option<(i32, &'static str)> {
    use libc as c;
    let table: &[(i32, &str)] = &[
        (c::E2BIG, "argument list too long"),
        (c::EACCES, "permission denied"),
        (c::EADDRINUSE, "address already in use"),
        (c::EADDRNOTAVAIL, "address not available"),
        (c::EAFNOSUPPORT, "address family not supported"),
        (c::EAGAIN, "resource temporarily unavailable"),
        (c::EBADF, "bad file descriptor"),
        (c::EBUSY, "resource busy or locked"),
        (c::ECONNABORTED, "software caused connection abort"),
        (c::ECONNREFUSED, "connection refused"),
        (c::ECONNRESET, "connection reset by peer"),
        (c::EDESTADDRREQ, "destination address required"),
        (c::EEXIST, "file already exists"),
        (c::EFAULT, "bad address in system call argument"),
        (c::EFBIG, "file too large"),
        (c::EHOSTUNREACH, "host is unreachable"),
        (c::EILSEQ, "illegal byte sequence"),
        (c::EINTR, "interrupted system call"),
        (c::EINVAL, "invalid argument"),
        (c::EIO, "i/o error"),
        (c::EISCONN, "socket is already connected"),
        (c::EISDIR, "illegal operation on a directory"),
        (c::ELOOP, "too many symbolic links encountered"),
        (c::EMFILE, "too many open files"),
        (c::EMLINK, "too many links"),
        (c::EMSGSIZE, "message too long"),
        (c::ENAMETOOLONG, "name too long"),
        (c::ENETDOWN, "network is down"),
        (c::ENETUNREACH, "network is unreachable"),
        (c::ENFILE, "file table overflow"),
        (c::ENOBUFS, "no buffer space available"),
        (c::ENODEV, "no such device"),
        (c::ENOENT, "no such file or directory"),
        (c::ENOMEM, "not enough memory"),
        (c::ENOPROTOOPT, "protocol not available"),
        (c::ENOSPC, "no space left on device"),
        (c::ENOSYS, "function not implemented"),
        (c::ENOTCONN, "socket is not connected"),
        (c::ENOTDIR, "not a directory"),
        (c::ENOTEMPTY, "directory not empty"),
        (c::ENOTSOCK, "socket operation on non-socket"),
        (c::ENOTTY, "inappropriate ioctl for device"),
        (c::ENXIO, "no such device or address"),
        (c::EOPNOTSUPP, "operation not supported on socket"),
        (c::EPERM, "operation not permitted"),
        (c::EPIPE, "broken pipe"),
        (c::EPROTO, "protocol error"),
        (c::EPROTONOSUPPORT, "protocol not supported"),
        (c::EPROTOTYPE, "protocol wrong type for socket"),
        (c::ERANGE, "result too large"),
        (c::EROFS, "read-only file system"),
        (c::ESPIPE, "invalid seek"),
        (c::ESRCH, "no such process"),
        (c::ETIMEDOUT, "connection timed out"),
        (c::ETXTBSY, "text file is busy"),
        (c::EXDEV, "cross-device link not permitted"),
        (c::ENODATA, "no data available"),
    ];
    let e = if approximate {
        // `lean_crt_to_uv_err`: the codes libuv cannot represent, as their closest libuv code.
        match e {
            _ if e == c::ENOMSG => c::ENODATA,
            _ if e == c::ENOEXEC || e == c::EDOM || e == c::ENOSTR => c::EINVAL,
            _ if e == c::EBADMSG => c::EPROTO,
            _ if e == c::ECHILD => c::ESRCH,
            _ if e == c::EDEADLK => c::EBUSY,
            _ if e == c::EIDRM => c::EPIPE,
            _ if e == c::EINPROGRESS => c::EISCONN,
            _ if e == c::ENETRESET || e == c::ENOLINK => c::ECONNRESET,
            _ if e == c::ENOLCK => c::EAGAIN,
            _ if e == c::ENOSR => c::ENOBUFS,
            _ if e == c::ETIME => c::ETIMEDOUT,
            _ => e,
        }
    } else {
        e
    };
    table.iter().find(|(n, _)| *n == e).copied()
}

/// The `IO.Error` of the OS error `errnum` (`decode_uv_error_impl`); `fname` is borrowed.
#[cfg(unix)]
unsafe fn decode(errnum: i32, approximate: bool, fname: Option<Obj>) -> Obj {
    use libc as c;
    let (uv, msg) = match uv_of_errno(errnum, approximate) {
        Some(p) => (p.0, p.1.to_string()),
        None => (0, format!("Unknown system error {}", -errnum)),
    };
    let details = lean_mk_string(&msg);
    let code = errnum as u32;
    let file = |f: Option<Obj>| f.inspect(|&f| lean_inc(f));
    let tag = match uv {
        0 => OTHER_ERROR,
        _ if uv == c::EINTR => INTERRUPTED,
        _ if [
            c::ELOOP,
            c::ENAMETOOLONG,
            c::EDESTADDRREQ,
            c::EBADF,
            c::EINVAL,
            c::EILSEQ,
            c::ENOTCONN,
            c::ENOTSOCK,
        ]
        .contains(&uv) =>
        {
            INVALID_ARGUMENT
        }
        _ if uv == c::ENOENT => NO_FILE_OR_DIRECTORY,
        _ if [c::EACCES, c::EROFS, c::ECONNABORTED, c::EFBIG, c::EPERM].contains(&uv) => {
            PERMISSION_DENIED
        }
        _ if [
            c::EMFILE,
            c::ENFILE,
            c::ENOSPC,
            c::E2BIG,
            c::EAGAIN,
            c::EMLINK,
            c::EMSGSIZE,
            c::ENOBUFS,
            c::ENOMEM,
        ]
        .contains(&uv) =>
        {
            RESOURCE_EXHAUSTED
        }
        _ if uv == c::EISDIR || uv == c::ENOTDIR => INAPPROPRIATE_TYPE,
        _ if [
            c::ENXIO,
            c::EHOSTUNREACH,
            c::ENETUNREACH,
            c::ECONNREFUSED,
            c::ENODATA,
            c::ESRCH,
        ]
        .contains(&uv) =>
        {
            NO_SUCH_THING
        }
        _ if uv == c::EEXIST || uv == c::EISCONN => ALREADY_EXISTS,
        _ if uv == c::EIO => HARDWARE_FAULT,
        _ if uv == c::ENOTEMPTY => UNSATISFIED_CONSTRAINTS,
        _ if uv == c::ENOTTY => ILLEGAL_OPERATION,
        _ if [c::ECONNRESET, c::ENETDOWN, c::EPIPE].contains(&uv) => RESOURCE_VANISHED,
        _ if [c::EPROTO, c::EPROTONOSUPPORT, c::EPROTOTYPE].contains(&uv) => PROTOCOL_ERROR,
        _ if uv == c::ETIMEDOUT => TIME_EXPIRED,
        _ if [c::EBUSY, c::ETXTBSY].contains(&uv) || uv == c::EADDRINUSE => RESOURCE_BUSY,
        _ if [
            c::EADDRNOTAVAIL,
            c::EAFNOSUPPORT,
            c::ENODEV,
            c::ENOPROTOOPT,
            c::ENOSYS,
            c::EOPNOTSUPP,
            c::ERANGE,
            c::ESPIPE,
            c::EXDEV,
        ]
        .contains(&uv) =>
        {
            UNSUPPORTED_OPERATION
        }
        _ => OTHER_ERROR,
    };
    let fname = if tag == INTERRUPTED || tag == NO_FILE_OR_DIRECTORY {
        Some(file(fname).unwrap_or_else(|| lean_mk_string("")))
    } else if has_filename(tag) {
        file(fname)
    } else {
        None
    };
    mk_error(tag, fname, code, details)
}

/// [`decode`] on a target without OS error codes, where every code is an unknown one.
#[cfg(not(unix))]
unsafe fn decode(errnum: i32, _approximate: bool, _fname: Option<Obj>) -> Obj {
    let msg = format!("Unknown system error {}", -errnum);
    mk_error(OTHER_ERROR, None, errnum as u32, lean_mk_string(&msg))
}

/// `lean_decode_io_error`: the `IO.Error` of the C library's `errno` value `errnum`; `fname`
/// (borrowed) is the file name or null.
pub unsafe fn lean_decode_io_error(errnum: i32, fname: Obj) -> Obj {
    decode(errnum, true, (!fname.is_null()).then_some(fname))
}

/// `lean_decode_uv_error`: the `IO.Error` of the libuv error `errnum` (a negated `errno`).
pub unsafe fn lean_decode_uv_error(errnum: i32, fname: Obj) -> Obj {
    decode(-errnum, false, (!fname.is_null()).then_some(fname))
}

/// The `IO.Error` of a Rust I/O error: its OS code when it has one, otherwise
/// `otherError 0` with Rust's message. `fname` is borrowed.
pub(crate) unsafe fn of_std(e: &std::io::Error, fname: Option<Obj>) -> Obj {
    match e.raw_os_error() {
        Some(n) => decode(n, true, fname),
        None => lean_mk_io_error_other_error(0, lean_mk_string(&e.to_string())),
    }
}

/// The same as [`of_std`] for the errors of the calls that the C runtime makes through libuv.
#[cfg(unix)]
pub(crate) unsafe fn of_std_uv(e: &std::io::Error, fname: Option<Obj>) -> Obj {
    match e.raw_os_error() {
        Some(n) => decode(n, false, fname),
        None => lean_mk_io_error_other_error(0, lean_mk_string(&e.to_string())),
    }
}

/* IO.Error.toString */

fn decapitalize(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        Some(f) => f.to_ascii_lowercase().to_string() + c.as_str(),
        None => String::new(),
    }
}

fn fopen_error(gist: &str, fname: &str, code: u32, details: Option<&str>) -> String {
    match details {
        Some(d) => format!(
            "{} (error code: {code}, {})\n  file: {fname}",
            decapitalize(gist),
            decapitalize(d)
        ),
        None => format!(
            "{} (error code: {code})\n  file: {fname}",
            decapitalize(gist)
        ),
    }
}

fn other_error(gist: &str, code: u32, details: Option<&str>) -> String {
    match details {
        Some(d) => format!(
            "{} (error code: {code}, {})",
            decapitalize(gist),
            decapitalize(d)
        ),
        None => format!("{} (error code: {code})", decapitalize(gist)),
    }
}

/// `IO.Error.toString` of the borrowed `e`.
pub unsafe fn io_error_to_string(e: Obj) -> String {
    if lean_is_scalar(e) {
        return "end of file".to_string();
    }
    let tag = lean_ptr_tag(e) as u32;
    if tag == USER_ERROR {
        return lean_string_to_str(lean_ctor_get(e, 0)).to_string();
    }
    let (fname, details, code) = if has_filename(tag) {
        let f = lean_ctor_get(e, 0);
        let f = if tag == INTERRUPTED || tag == NO_FILE_OR_DIRECTORY {
            Some(lean_string_to_str(f))
        } else if lean_is_scalar(f) {
            None
        } else {
            Some(lean_string_to_str(lean_ctor_get(f, 0)))
        };
        (
            f,
            lean_string_to_str(lean_ctor_get(e, 1)),
            lean_ctor_get_uint32(e, scalar_offset(2, 0)),
        )
    } else {
        (
            None,
            lean_string_to_str(lean_ctor_get(e, 0)),
            lean_ctor_get_uint32(e, scalar_offset(1, 0)),
        )
    };
    let d = Some(details);
    let with_file = |gist: &str, details: Option<&str>| match fname {
        Some(f) => fopen_error(gist, f, code, details),
        None => other_error(gist, code, details),
    };
    match tag {
        INAPPROPRIATE_TYPE => with_file("inappropriate type", d),
        INTERRUPTED => with_file("interrupted system call", d),
        INVALID_ARGUMENT => with_file("invalid argument", d),
        NO_FILE_OR_DIRECTORY => with_file("no such file or directory", None),
        NO_SUCH_THING => with_file("no such thing", d),
        PERMISSION_DENIED => with_file(details, None),
        RESOURCE_EXHAUSTED => with_file("resource exhausted", d),
        ALREADY_EXISTS => with_file("already exists", d),
        OTHER_ERROR => other_error(details, code, None),
        RESOURCE_BUSY => other_error("resource busy", code, d),
        RESOURCE_VANISHED => other_error("resource vanished", code, d),
        HARDWARE_FAULT => other_error("hardware fault", code, None),
        ILLEGAL_OPERATION => other_error("illegal operation", code, d),
        PROTOCOL_ERROR => other_error("protocol error", code, d),
        TIME_EXPIRED => other_error("time expired", code, d),
        UNSATISFIED_CONSTRAINTS => other_error("directory not empty", code, None),
        UNSUPPORTED_OPERATION => other_error("unsupported operation", code, d),
        _ => String::new(),
    }
}
