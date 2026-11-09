//! Child processes (`IO.Process.spawn` and `IO.Process.Child`), with `fork` and `execvp` as in
//! the C runtime: a command that cannot be executed is reported by the child on its standard
//! error, and the child exits with 255.

#[cfg(unix)]
use crate::array::{lean_array_get_core, lean_array_size};
#[cfg(not(unix))]
use crate::io::io_result_unsupported;
use crate::io::lean_io_result_mk_ok;
#[cfg(unix)]
use crate::io::{io_result_of_error, wrap_file};
use crate::model::scalar_offset;
use crate::object::*;
#[cfg(unix)]
use crate::string::lean_string_bytes;
#[cfg(unix)]
use std::ffi::CString;
#[cfg(unix)]
use std::io::Write;
#[cfg(unix)]
use std::os::fd::FromRawFd;

/// `IO.Process.Stdio`: `piped`, `inherit`, `null`.
#[cfg(unix)]
const PIPED: u8 = 0;
#[cfg(unix)]
const NUL: u8 = 2;

/// Offset of the pid in a `Child` (after its three handle fields), and of the `setsid` flag.
const PID_OFFSET: u32 = scalar_offset(3, 0);
const SETSID_OFFSET: u32 = scalar_offset(3, 4);

#[cfg(unix)]
unsafe fn c_string(s: Obj) -> CString {
    let b = lean_string_bytes(s);
    let end = b.iter().position(|&c| c == 0).unwrap_or(b.len());
    CString::new(&b[..end]).unwrap()
}

/// A pipe whose ends are closed on `exec`: `(read, write)`.
#[cfg(unix)]
fn pipe() -> std::io::Result<(i32, i32)> {
    let mut fds = [0i32; 2];
    #[cfg(target_os = "linux")]
    let r = unsafe { libc::pipe2(fds.as_mut_ptr(), libc::O_CLOEXEC) };
    #[cfg(not(target_os = "linux"))]
    let r = unsafe {
        let r = libc::pipe(fds.as_mut_ptr());
        if r == 0 {
            libc::fcntl(fds[0], libc::F_SETFD, libc::FD_CLOEXEC);
            libc::fcntl(fds[1], libc::F_SETFD, libc::FD_CLOEXEC);
        }
        r
    };
    if r == -1 {
        Err(std::io::Error::last_os_error())
    } else {
        Ok((fds[0], fds[1]))
    }
}

/// Writes `msg` on the standard error of the child, without allocating or locking.
#[cfg(unix)]
unsafe fn child_message(msg: &[u8]) {
    libc::write(2, msg.as_ptr() as *const libc::c_void, msg.len());
}

/// Connects the standard stream `target` of the child to its pipe end or `/dev/null`.
#[cfg(unix)]
unsafe fn child_stdio(mode: u8, pipe: Option<(i32, i32)>, target: i32, null: &CString) {
    if let Some((r, w)) = pipe {
        if target == 0 {
            libc::dup2(r, 0);
            libc::close(w);
        } else {
            libc::dup2(w, target);
            libc::close(r);
        }
    } else if mode == NUL {
        let flags = if target == 0 {
            libc::O_RDONLY
        } else {
            libc::O_WRONLY
        };
        let fd = libc::open(null.as_ptr(), flags);
        libc::dup2(fd, target);
    }
}

/// `IO.Process.spawn : SpawnArgs → IO (Child args.toStdioConfig)` (consumes `args`).
#[cfg(unix)]
pub unsafe fn lean_io_process_spawn(args: Obj) -> Obj {
    let r = spawn(args);
    lean_dec(args);
    r
}

#[cfg(not(unix))]
pub unsafe fn lean_io_process_spawn(args: Obj) -> Obj {
    lean_dec(args);
    io_result_unsupported("spawning a process")
}

#[cfg(unix)]
unsafe fn spawn(args: Obj) -> Obj {
    let cfg = lean_ctor_get(args, 0);
    let modes = [
        lean_ctor_get_uint8(cfg, 0),
        lean_ctor_get_uint8(cfg, 1),
        lean_ctor_get_uint8(cfg, 2),
    ];
    let cmd = c_string(lean_ctor_get(args, 1));
    let argv_arr = lean_ctor_get(args, 2);
    let cwd = lean_ctor_get(args, 3);
    let env = lean_ctor_get(args, 4);
    let inherit_env = lean_ctor_get_uint8(args, scalar_offset(5, 0)) != 0;
    let do_setsid = lean_ctor_get_uint8(args, scalar_offset(5, 1)) != 0;
    if modes[0] == 1 {
        let _ = std::io::stdout().flush();
    }

    let mut pipes = [None, None, None];
    for i in 0..3 {
        if modes[i] == PIPED {
            match pipe() {
                Ok(p) => pipes[i] = Some(p),
                Err(e) => return io_result_of_error(&e),
            }
        }
    }

    let mut argv_c = vec![cmd.clone()];
    for i in 0..lean_array_size(argv_arr) {
        argv_c.push(c_string(lean_array_get_core(argv_arr, i)));
    }
    let mut argv: Vec<*const libc::c_char> = argv_c.iter().map(|s| s.as_ptr()).collect();
    argv.push(core::ptr::null());
    let env_c: Vec<(CString, Option<CString>)> = (0..lean_array_size(env))
        .map(|i| {
            let pair = lean_array_get_core(env, i);
            let v = lean_ctor_get(pair, 1);
            let v = (!lean_is_scalar(v)).then(|| c_string(lean_ctor_get(v, 0)));
            (c_string(lean_ctor_get(pair, 0)), v)
        })
        .collect();
    let cwd_c = (!lean_is_scalar(cwd)).then(|| c_string(lean_ctor_get(cwd, 0)));
    let null = CString::new("/dev/null").unwrap();
    let mut cwd_msg = b"could not change directory to ".to_vec();
    if let Some(c) = &cwd_c {
        cwd_msg.extend_from_slice(c.as_bytes());
    }
    cwd_msg.push(b'\n');
    let mut exec_msg = b"could not execute external process '".to_vec();
    exec_msg.extend_from_slice(cmd.as_bytes());
    exec_msg.extend_from_slice(b"'\n");

    let pid = libc::fork();
    if pid == 0 {
        if !inherit_env {
            #[cfg(target_os = "linux")]
            libc::clearenv();
            #[cfg(not(target_os = "linux"))]
            {
                extern "C" {
                    static mut environ: *const *const libc::c_char;
                }
                environ = core::ptr::null();
            }
        }
        for (k, v) in &env_c {
            match v {
                Some(v) => libc::setenv(k.as_ptr(), v.as_ptr(), 1),
                None => libc::unsetenv(k.as_ptr()),
            };
        }
        for (i, target) in [0, 1, 2].into_iter().enumerate() {
            child_stdio(modes[i], pipes[i], target, &null);
        }
        if let Some(c) = &cwd_c {
            if libc::chdir(c.as_ptr()) < 0 {
                child_message(&cwd_msg);
                libc::_exit(255);
            }
        }
        if do_setsid {
            libc::setsid();
        }
        libc::execvp(argv[0], argv.as_ptr());
        child_message(&exec_msg);
        libc::_exit(255);
    } else if pid == -1 {
        let e = std::io::Error::last_os_error();
        for (r, w) in pipes.into_iter().flatten() {
            libc::close(r);
            libc::close(w);
        }
        return io_result_of_error(&e);
    }

    let child = lean_alloc_ctor(0, 3, 5);
    for (i, p) in pipes.into_iter().enumerate() {
        let h = match p {
            Some((r, w)) => {
                let (ours, theirs) = if i == 0 { (w, r) } else { (r, w) };
                libc::close(theirs);
                wrap_file(std::fs::File::from_raw_fd(ours))
            }
            None => lean_box(0),
        };
        lean_ctor_set(child, i as u32, h);
    }
    lean_ctor_set_uint32(child, PID_OFFSET, pid as u32);
    lean_ctor_set_uint8(child, SETSID_OFFSET, do_setsid as u8);
    lean_io_result_mk_ok(child)
}

/// The exit code of a `waitpid` status: the signal number plus 128 for a signal (bash's
/// convention).
#[cfg(unix)]
fn exit_code(status: i32) -> u32 {
    if libc::WIFEXITED(status) {
        libc::WEXITSTATUS(status) as u32
    } else {
        128 + libc::WTERMSIG(status) as u32
    }
}

unsafe fn pid_of(child: Obj) -> i32 {
    lean_ctor_get_uint32(child, PID_OFFSET) as i32
}

/// `Child.wait : (@& Child cfg) → IO UInt32`.
#[cfg(unix)]
pub unsafe fn lean_io_process_child_wait(_cfg: Obj, child: Obj) -> Obj {
    let mut status = 0;
    if libc::waitpid(pid_of(child), &mut status, 0) == -1 {
        return io_result_of_error(&std::io::Error::last_os_error());
    }
    lean_io_result_mk_ok(lean_box_uint32(exit_code(status)))
}

/// `Child.tryWait : (@& Child cfg) → IO (Option UInt32)`.
#[cfg(unix)]
pub unsafe fn lean_io_process_child_try_wait(_cfg: Obj, child: Obj) -> Obj {
    let mut status = 0;
    match libc::waitpid(pid_of(child), &mut status, libc::WNOHANG) {
        -1 => io_result_of_error(&std::io::Error::last_os_error()),
        0 => lean_io_result_mk_ok(lean_box(0)),
        _ => {
            let s = lean_alloc_ctor(1, 1, 0);
            lean_ctor_set(s, 0, lean_box_uint32(exit_code(status)));
            lean_io_result_mk_ok(s)
        }
    }
}

/// `Child.kill : (@& Child cfg) → IO Unit`: `SIGKILL` to the process, or to its process group
/// when it was spawned with `setsid`.
#[cfg(unix)]
pub unsafe fn lean_io_process_child_kill(_cfg: Obj, child: Obj) -> Obj {
    let pid = pid_of(child);
    let r = if lean_ctor_get_uint8(child, SETSID_OFFSET) != 0 {
        libc::killpg(pid, libc::SIGKILL)
    } else {
        libc::kill(pid, libc::SIGKILL)
    };
    if r == -1 {
        return io_result_of_error(&std::io::Error::last_os_error());
    }
    lean_io_result_mk_ok(lean_box(0))
}

#[cfg(not(unix))]
pub unsafe fn lean_io_process_child_wait(_cfg: Obj, _child: Obj) -> Obj {
    io_result_unsupported("waiting for a process")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_process_child_try_wait(_cfg: Obj, _child: Obj) -> Obj {
    io_result_unsupported("waiting for a process")
}

#[cfg(not(unix))]
pub unsafe fn lean_io_process_child_kill(_cfg: Obj, _child: Obj) -> Obj {
    io_result_unsupported("killing a process")
}

/// `Child.pid : Child cfg → UInt32` (consumes `child`).
pub unsafe fn lean_io_process_child_pid(_cfg: Obj, child: Obj) -> u32 {
    let pid = pid_of(child) as u32;
    lean_dec(child);
    pid
}

/// `Child.takeStdin : Child cfg → IO (cfg.stdin.toHandleType × Child ..)` (consumes `child`):
/// the stdin handle, and the child without it.
pub unsafe fn lean_io_process_child_take_stdin(_cfg: Obj, child: Obj) -> Obj {
    let rest = lean_alloc_ctor(0, 3, 5);
    lean_ctor_set(rest, 0, lean_box(0));
    for i in 1..3 {
        let h = lean_ctor_get(child, i);
        lean_inc(h);
        lean_ctor_set(rest, i, h);
    }
    lean_ctor_set_uint32(rest, PID_OFFSET, pid_of(child) as u32);
    lean_ctor_set_uint8(
        rest,
        SETSID_OFFSET,
        lean_ctor_get_uint8(child, SETSID_OFFSET),
    );
    let stdin = lean_ctor_get(child, 0);
    lean_inc(stdin);
    lean_dec(child);
    let pair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(pair, 0, stdin);
    lean_ctor_set(pair, 1, rest);
    lean_io_result_mk_ok(pair)
}
