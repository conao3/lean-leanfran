//! Files, directories and the environment of the process: `IO.FS`, `IO.getEnv`, `IO.appPath`,
//! the current directory, process and thread ids, random bytes and `timeit`.

#[cfg(unix)]
use crate::array::{lean_alloc_sarray, lean_array_push, lean_mk_empty_array, lean_sarray_cptr};
#[cfg(unix)]
use crate::int::lean_int64_to_int;
#[cfg(not(unix))]
use crate::io::io_result_unsupported;
#[cfg(unix)]
use crate::io::{io_result_of_error, lean_io_result_mk_error, lean_io_result_mk_ok, wrap_file};
#[cfg(unix)]
use crate::io_error::{
    embedded_nul_error, file_not_found_error, lean_mk_io_user_error, of_std, of_std_uv,
};
#[cfg(unix)]
use crate::model::scalar_offset;
use crate::nat::lean_uint64_to_nat;
use crate::object::*;
use crate::string::lean_mk_string;
#[cfg(unix)]
use crate::string::{lean_mk_string_from_bytes, lean_string_bytes};
#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;

/// The path of a borrowed `FilePath` (a `String`), or the `error` result for a path with a NUL
/// byte.
#[cfg(unix)]
pub(crate) unsafe fn path_of<'a>(p: Obj) -> Result<&'a std::path::Path, Obj> {
    let b = lean_string_bytes(p);
    if b.contains(&0) {
        Err(lean_io_result_mk_error(embedded_nul_error(p)))
    } else {
        Ok(std::path::Path::new(std::ffi::OsStr::from_bytes(b)))
    }
}

#[cfg(unix)]
unsafe fn mk_path(p: &std::path::Path) -> Obj {
    lean_mk_string_from_bytes(p.as_os_str().as_bytes())
}

#[cfg(unix)]
unsafe fn unit_or(r: std::io::Result<()>, err: impl FnOnce(&std::io::Error) -> Obj) -> Obj {
    match r {
        Ok(()) => lean_io_result_mk_ok(lean_box(0)),
        Err(e) => lean_io_result_mk_error(err(&e)),
    }
}

#[cfg(unix)]
macro_rules! path_or_return {
    ($p:expr) => {
        match path_of($p) {
            Ok(p) => p,
            Err(e) => return e,
        }
    };
}

/* Directories and files */

/// `IO.FS.readDir : @& FilePath → IO (Array DirEntry)`: `DirEntry` is `⟨root, fileName⟩`.
#[cfg(unix)]
pub unsafe fn lean_io_read_dir(dir: Obj) -> Obj {
    let path = path_or_return!(dir);
    let entries = match std::fs::read_dir(path) {
        Ok(it) => it,
        Err(e) => return lean_io_result_mk_error(of_std(&e, Some(dir))),
    };
    let mut arr = lean_mk_empty_array();
    for entry in entries.flatten() {
        let e = lean_alloc_ctor(0, 2, 0);
        lean_inc(dir);
        lean_ctor_set(e, 0, dir);
        lean_ctor_set(
            e,
            1,
            lean_mk_string_from_bytes(entry.file_name().as_bytes()),
        );
        arr = lean_array_push(arr, e);
    }
    lean_io_result_mk_ok(arr)
}

#[cfg(unix)]
unsafe fn system_time(sec: i64, nsec: i64) -> Obj {
    let o = lean_alloc_ctor(0, 1, 4);
    lean_ctor_set(o, 0, lean_int64_to_int(sec));
    lean_ctor_set_uint32(o, scalar_offset(1, 0), nsec as u32);
    o
}

/// `IO.FS.Metadata`: `accessed`, `modified`, `byteSize`, `numLinks` and `type` (`dir`, `file`,
/// `symlink`, `other`).
#[cfg(unix)]
unsafe fn metadata_obj(m: &std::fs::Metadata) -> Obj {
    use std::os::unix::fs::MetadataExt;
    let o = lean_alloc_ctor(0, 2, 17);
    lean_ctor_set(o, 0, system_time(m.atime(), m.atime_nsec()));
    lean_ctor_set(o, 1, system_time(m.mtime(), m.mtime_nsec()));
    lean_ctor_set_uint64(o, scalar_offset(2, 0), m.size());
    lean_ctor_set_uint64(o, scalar_offset(2, 8), m.nlink());
    let t = m.file_type();
    let ty = if t.is_dir() {
        0
    } else if t.is_file() {
        1
    } else if t.is_symlink() {
        2
    } else {
        3
    };
    lean_ctor_set_uint8(o, scalar_offset(2, 16), ty);
    o
}

/// `System.FilePath.metadata : @& FilePath → IO Metadata`.
#[cfg(unix)]
pub unsafe fn lean_io_metadata(fname: Obj) -> Obj {
    let path = path_or_return!(fname);
    match std::fs::metadata(path) {
        Ok(m) => lean_io_result_mk_ok(metadata_obj(&m)),
        Err(e) => lean_io_result_mk_error(of_std_uv(&e, Some(fname))),
    }
}

/// `System.FilePath.symlinkMetadata : @& FilePath → IO Metadata`.
#[cfg(unix)]
pub unsafe fn lean_io_symlink_metadata(fname: Obj) -> Obj {
    let path = path_or_return!(fname);
    match std::fs::symlink_metadata(path) {
        Ok(m) => lean_io_result_mk_ok(metadata_obj(&m)),
        Err(e) => lean_io_result_mk_error(of_std_uv(&e, Some(fname))),
    }
}

/// `IO.FS.createDir : @& FilePath → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_io_create_dir(p: Obj) -> Obj {
    let path = path_or_return!(p);
    unit_or(std::fs::create_dir(path), |e| of_std(e, Some(p)))
}

/// `IO.FS.removeDir : @& FilePath → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_io_remove_dir(p: Obj) -> Obj {
    let path = path_or_return!(p);
    unit_or(std::fs::remove_dir(path), |e| of_std(e, Some(p)))
}

/// `IO.FS.removeFile : @& FilePath → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_io_remove_file(p: Obj) -> Obj {
    let path = path_or_return!(p);
    unit_or(std::fs::remove_file(path), |e| of_std_uv(e, Some(p)))
}

/// `IO.FS.rename : (old new : @& FilePath) → IO Unit`; the file name of an error is
/// `"<old> and/or <new>"`.
#[cfg(unix)]
pub unsafe fn lean_io_rename(from: Obj, to: Obj) -> Obj {
    let f = path_or_return!(from);
    let t = path_or_return!(to);
    unit_or(std::fs::rename(f, t), |e| {
        let mut both = lean_string_bytes(from).to_vec();
        both.extend_from_slice(b" and/or ");
        both.extend_from_slice(lean_string_bytes(to));
        let s = lean_mk_string_from_bytes(&both);
        let r = of_std(e, Some(s));
        lean_dec(s);
        r
    })
}

/// `IO.FS.hardLink : (orig link : @& FilePath) → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_io_hard_link(orig: Obj, link: Obj) -> Obj {
    let o = path_or_return!(orig);
    let l = path_or_return!(link);
    unit_or(std::fs::hard_link(o, l), |e| of_std_uv(e, Some(orig)))
}

/// `IO.FS.realPath : FilePath → IO FilePath` (consumes `fname`).
#[cfg(unix)]
pub unsafe fn lean_io_realpath(fname: Obj) -> Obj {
    let r = match path_of(fname) {
        Ok(p) => match std::fs::canonicalize(p) {
            Ok(real) => lean_io_result_mk_ok(mk_path(&real)),
            Err(_) => lean_io_result_mk_error(file_not_found_error(fname)),
        },
        Err(e) => e,
    };
    lean_dec(fname);
    r
}

/// `IO.setAccessRights` through `chmod : (@& FilePath) → UInt32 → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_chmod(fname: Obj, mode: u32) -> Obj {
    use std::os::unix::fs::PermissionsExt;
    let path = path_or_return!(fname);
    unit_or(
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(mode)),
        |e| of_std(e, Some(fname)),
    )
}

/// `uv_os_tmpdir`: `TMPDIR`, `TMP`, `TEMP` or `TEMPDIR`, else `/tmp`, without a trailing `/`.
#[cfg(unix)]
fn temp_dir() -> Vec<u8> {
    let mut d = ["TMPDIR", "TMP", "TEMP", "TEMPDIR"]
        .iter()
        .find_map(|v| std::env::var_os(v).filter(|s| !s.is_empty()))
        .map(|s| s.as_bytes().to_vec())
        .unwrap_or_else(|| b"/tmp".to_vec());
    if d.len() > 1 && d.ends_with(b"/") {
        d.pop();
    }
    d
}

/// `<tmpdir>/tmp.XXXXXXXX` as a C string, for `mkstemp` and `mkdtemp`.
#[cfg(unix)]
fn temp_template() -> Vec<u8> {
    let mut t = temp_dir();
    t.extend_from_slice(b"/tmp.XXXXXXXX\0");
    t
}

/// `IO.FS.createTempFile : IO (Handle × FilePath)`.
#[cfg(unix)]
pub unsafe fn lean_io_create_tempfile() -> Obj {
    use std::os::fd::FromRawFd;
    let mut t = temp_template();
    let fd = libc::mkstemp(t.as_mut_ptr() as *mut libc::c_char);
    if fd < 0 {
        return lean_io_result_mk_error(of_std_uv(&std::io::Error::last_os_error(), None));
    }
    let file = std::fs::File::from_raw_fd(fd);
    let pair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(pair, 0, wrap_file(file));
    lean_ctor_set(pair, 1, lean_mk_string_from_bytes(&t[..t.len() - 1]));
    lean_io_result_mk_ok(pair)
}

/// `IO.FS.createTempDir : IO FilePath`.
#[cfg(unix)]
pub unsafe fn lean_io_create_tempdir() -> Obj {
    let mut t = temp_template();
    if libc::mkdtemp(t.as_mut_ptr() as *mut libc::c_char).is_null() {
        return lean_io_result_mk_error(of_std_uv(&std::io::Error::last_os_error(), None));
    }
    lean_io_result_mk_ok(lean_mk_string_from_bytes(&t[..t.len() - 1]))
}

/* The process */

/// `IO.getEnv : @& String → BaseIO (Option String)`.
#[cfg(unix)]
pub unsafe fn lean_io_getenv(var: Obj) -> Obj {
    let name = lean_string_bytes(var);
    if name.contains(&0) {
        return lean_box(0);
    }
    match std::env::var_os(std::ffi::OsStr::from_bytes(name)) {
        Some(v) => {
            let s = lean_alloc_ctor(1, 1, 0);
            lean_ctor_set(s, 0, lean_mk_string_from_bytes(v.as_bytes()));
            s
        }
        None => lean_box(0),
    }
}

/// `IO.appPath : IO FilePath`: the executable, with symbolic links resolved.
#[cfg(unix)]
pub unsafe fn lean_io_app_path() -> Obj {
    match std::env::current_exe() {
        Ok(p) => lean_io_result_mk_ok(mk_path(&p)),
        Err(_) => lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(
            "failed to locate application",
        ))),
    }
}

/// `IO.currentDir : IO FilePath`.
#[cfg(unix)]
pub unsafe fn lean_io_current_dir() -> Obj {
    match std::env::current_dir() {
        Ok(p) => lean_io_result_mk_ok(mk_path(&p)),
        Err(_) => lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(
            "failed to retrieve current working directory",
        ))),
    }
}

/// `IO.Process.getCurrentDir : IO FilePath`.
#[cfg(unix)]
pub unsafe fn lean_io_process_get_current_dir() -> Obj {
    match std::env::current_dir() {
        Ok(p) => lean_io_result_mk_ok(mk_path(&p)),
        Err(e) => io_result_of_error(&e),
    }
}

/// `IO.Process.setCurrentDir : @& FilePath → IO Unit`.
#[cfg(unix)]
pub unsafe fn lean_io_process_set_current_dir(p: Obj) -> Obj {
    let path = path_or_return!(p);
    unit_or(std::env::set_current_dir(path), |e| of_std(e, Some(p)))
}

/// `IO.Process.getPID : BaseIO UInt32`.
#[cfg(unix)]
pub unsafe fn lean_io_process_get_pid() -> u32 {
    std::process::id()
}

/// `IO.getTID : BaseIO UInt64`: the id of the OS thread.
pub unsafe fn lean_io_get_tid() -> u64 {
    #[cfg(target_os = "linux")]
    {
        libc::syscall(libc::SYS_gettid) as u64
    }
    #[cfg(target_os = "macos")]
    {
        let mut tid = 0u64;
        libc::pthread_threadid_np(0, &mut tid);
        tid
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
    {
        0
    }
}

/// `IO.getRandomBytes : USize → IO ByteArray`, from `/dev/urandom`.
#[cfg(unix)]
pub unsafe fn lean_io_get_random_bytes(n: usize) -> Obj {
    use std::io::Read;
    if n == 0 {
        return lean_io_result_mk_ok(lean_alloc_sarray(1, 0, 0));
    }
    let mut f = match std::fs::File::open("/dev/urandom") {
        Ok(f) => f,
        Err(e) => {
            let name = lean_mk_string("/dev/urandom");
            let r = lean_io_result_mk_error(of_std(&e, Some(name)));
            lean_dec(name);
            return r;
        }
    };
    let r = lean_alloc_sarray(1, n, n);
    let buf = core::slice::from_raw_parts_mut(lean_sarray_cptr(r), n);
    match f.read_exact(buf) {
        Ok(()) => lean_io_result_mk_ok(r),
        Err(e) => {
            lean_dec_ref(r);
            io_result_of_error(&e)
        }
    }
}

/// `IO.Process.forceExit : UInt8 → IO α`: exits without flushing the standard streams.
#[cfg(unix)]
pub unsafe fn lean_io_force_exit(code: u8) -> Obj {
    libc::_exit(code as i32)
}

/* Targets without an OS: the file system and the process are unsupported operations */

#[cfg(not(unix))]
pub unsafe fn lean_io_read_dir(_dir: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_metadata(_fname: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_symlink_metadata(_fname: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_create_dir(_p: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_remove_dir(_p: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_remove_file(_p: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_rename(_from: Obj, _to: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_hard_link(_orig: Obj, _link: Obj) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_realpath(fname: Obj) -> Obj {
    lean_dec(fname);
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_chmod(_fname: Obj, _mode: u32) -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_create_tempfile() -> Obj {
    io_result_unsupported("the file system")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_create_tempdir() -> Obj {
    io_result_unsupported("the file system")
}

/// No variable is set.
#[cfg(not(unix))]
pub unsafe fn lean_io_getenv(_var: Obj) -> Obj {
    lean_box(0)
}

#[cfg(not(unix))]
pub unsafe fn lean_io_app_path() -> Obj {
    io_result_unsupported("the application path")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_current_dir() -> Obj {
    io_result_unsupported("the current directory")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_process_get_current_dir() -> Obj {
    io_result_unsupported("the current directory")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_process_set_current_dir(_p: Obj) -> Obj {
    io_result_unsupported("the current directory")
}

/// The process id 0.
#[cfg(not(unix))]
pub unsafe fn lean_io_process_get_pid() -> u32 {
    0
}

#[cfg(not(unix))]
pub unsafe fn lean_io_get_random_bytes(_n: usize) -> Obj {
    io_result_unsupported("random bytes")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_force_exit(_code: u8) -> Obj {
    io_result_unsupported("exiting the process")
}

/* Profiling */

/// `std::setprecision(3)` of a C++ stream: 3 significant digits, `%g`-style.
fn g3(x: f64) -> String {
    if x == 0.0 {
        return "0".to_string();
    }
    let s = format!("{:.2e}", x);
    let (m, e) = s.split_once('e').unwrap();
    let e: i32 = e.parse().unwrap();
    let trim = |s: &str| {
        if s.contains('.') {
            s.trim_end_matches('0').trim_end_matches('.').to_string()
        } else {
            s.to_string()
        }
    };
    if !(-4..3).contains(&e) {
        let sign = if e < 0 { '-' } else { '+' };
        return format!("{}e{sign}{:02}", trim(m), e.abs());
    }
    trim(&format!("{:.*}", (2 - e) as usize, x))
}

/// Prints `s` and a newline on the current standard error stream (`IO.eprintln`).
unsafe fn eprintln_stream(s: &str) {
    let err = crate::io::lean_get_stderr();
    let put = lean_ctor_get(err, 4);
    lean_inc(put);
    lean_dec(err);
    let r = crate::closure::lean_apply_2(put, lean_mk_string(&format!("{s}\n")), lean_box(0));
    lean_dec(r);
}

/// `timeit : (@& String) → IO α → IO α`: runs the action and prints `<msg> <time>` on the
/// standard error stream.
pub unsafe fn lean_io_timeit(msg: Obj, f: Obj) -> Obj {
    let start = crate::io::mono_elapsed();
    let r = crate::closure::lean_apply_1(f, lean_box(0));
    let d = (crate::io::mono_elapsed() - start).as_secs_f64();
    let m = crate::string::lean_string_to_str(msg);
    let line = if d < 1.0 {
        format!("{m} {}ms", g3(d * 1000.0))
    } else {
        format!("{m} {}s", g3(d))
    };
    eprintln_stream(&line);
    r
}

/// `allocprof : (@& String) → IO α → IO α`: runs the action (this runtime keeps no
/// allocation profile, so it prints an empty line).
pub unsafe fn lean_io_allocprof(_msg: Obj, f: Obj) -> Obj {
    let r = crate::closure::lean_apply_1(f, lean_box(0));
    eprintln_stream("");
    r
}

thread_local! {
    static HEARTBEATS: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
}

/// `IO.getNumHeartbeats : BaseIO Nat`: the value last set by `setNumHeartbeats` (this runtime
/// counts no heartbeats).
pub unsafe fn lean_io_get_num_heartbeats() -> Obj {
    lean_uint64_to_nat(HEARTBEATS.get())
}

/// `IO.setNumHeartbeats : Nat → BaseIO Unit` (consumes `count`).
pub unsafe fn lean_io_set_heartbeats(count: Obj) -> Obj {
    HEARTBEATS.set(crate::uint::lean_uint64_of_nat(count));
    lean_dec(count);
    lean_box(0)
}

#[cfg(test)]
mod tests {
    use super::g3;

    #[test]
    fn three_significant_digits() {
        assert_eq!(g3(1.23456), "1.23");
        assert_eq!(g3(12.0), "12");
        assert_eq!(g3(123.456), "123");
        assert_eq!(g3(0.0123456), "0.0123");
        assert_eq!(g3(999.7), "1e+03");
        assert_eq!(g3(0.0000012345), "1.23e-06");
    }
}
