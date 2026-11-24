package rt

import (
	"errors"
	"os"
	"runtime"
	"strings"
	"syscall"
	"time"
)

func Lean_decode_io_error(code uint32, filename V) V {
	var err error = syscall.Errno(code)
	if filename.p != nil {
		err = &os.PathError{Path: String(filename), Err: err}
	}
	return ioError(err)
}

func embeddedNUL(path V) V {
	const code = uint32(syscall.EINVAL)
	value := Lean_alloc_ctor(12, 2, 4)
	Lean_ctor_set(value, 0, ctor(1, own(path)))
	Lean_ctor_set(value, 1, Lean_mk_string("string contains NUL bytes"))
	Lean_ctor_set_uint32(value, 16, code)
	return Lean_io_result_mk_error(value)
}

func pathAction(path V, action func(string) error) V {
	name := String(path)
	if strings.ContainsRune(name, 0) {
		return embeddedNUL(path)
	}
	if err := action(name); err != nil {
		return ioResult(V{}, &os.PathError{Path: name, Err: err})
	}
	return Lean_io_result_mk_ok(V{})
}

func Lean_chmod(path V, mode uint32) V {
	return pathAction(path, func(name string) error { return syscall.Chmod(name, mode) })
}

func lockMode(exclusive uint8) int {
	if exclusive != 0 {
		return syscall.LOCK_EX
	}
	return syscall.LOCK_SH
}

func lockHandle(value V, mode int) error {
	conn, err := handle(value).file.SyscallConn()
	if err != nil {
		return err
	}
	var lockErr error
	if err := conn.Control(func(fd uintptr) { lockErr = syscall.Flock(int(fd), mode) }); err != nil {
		return err
	}
	return lockErr
}

func Lean_io_prim_handle_lock(value V, exclusive uint8) V {
	return ioResult(V{}, lockHandle(value, lockMode(exclusive)))
}

func Lean_io_prim_handle_try_lock(value V, exclusive uint8) V {
	err := lockHandle(value, lockMode(exclusive)|syscall.LOCK_NB)
	if errors.Is(err, syscall.EWOULDBLOCK) {
		return Lean_io_result_mk_ok(V{})
	}
	return ioResult(Lean_box(1), err)
}

func Lean_io_prim_handle_unlock(value V) V {
	return ioResult(V{}, lockHandle(value, syscall.LOCK_UN))
}

func Lean_io_read_dir(directory V) V {
	path := String(directory)
	if strings.ContainsRune(path, 0) {
		return embeddedNUL(directory)
	}
	dir, err := os.Open(path)
	if err != nil {
		return ioResult(V{}, err)
	}
	names, err := dir.Readdirnames(-1)
	closeErr := dir.Close()
	if err != nil {
		return ioResult(V{}, err)
	}
	if closeErr != nil {
		return ioResult(V{}, closeErr)
	}
	entries := make([]V, 0, len(names))
	for _, name := range names {
		entries = append(entries, ctor(0, own(directory), Lean_mk_string(name)))
	}
	return Lean_io_result_mk_ok(array(entries))
}

func systemTime(seconds, nanos int64) V {
	value := Lean_alloc_ctor(0, 1, 4)
	Lean_ctor_set(value, 0, IntFromInt64(seconds))
	Lean_ctor_set_uint32(value, 8, uint32(nanos))
	return value
}

func metadata(filename V, stat func(string) (os.FileInfo, error)) V {
	path := String(filename)
	if strings.ContainsRune(path, 0) {
		return embeddedNUL(filename)
	}
	info, err := stat(path)
	if err != nil {
		return ioResult(V{}, err)
	}
	data := info.Sys().(*syscall.Stat_t)
	kind := uint8(3)
	switch mode := info.Mode(); {
	case mode.IsDir():
		kind = 0
	case mode.IsRegular():
		kind = 1
	case mode&os.ModeSymlink != 0:
		kind = 2
	}
	access := accessedTime(data)
	modified := info.ModTime()
	value := Lean_alloc_ctor(0, 2, 17)
	Lean_ctor_set(value, 0, systemTime(access.Unix(), int64(access.Nanosecond())))
	Lean_ctor_set(value, 1, systemTime(modified.Unix(), int64(modified.Nanosecond())))
	Lean_ctor_set_uint64(value, 16, uint64(info.Size()))
	Lean_ctor_set_uint64(value, 24, uint64(data.Nlink))
	Lean_ctor_set_uint8(value, 32, kind)
	return Lean_io_result_mk_ok(value)
}

func Lean_io_metadata(filename V) V         { return metadata(filename, os.Stat) }
func Lean_io_symlink_metadata(filename V) V { return metadata(filename, os.Lstat) }

func tempDirectory() string {
	for _, key := range []string{"TMPDIR", "TMP", "TEMP", "TEMPDIR"} {
		if value := os.Getenv(key); value != "" {
			return value
		}
	}
	return os.TempDir()
}

func Lean_io_create_tempfile() V {
	file, err := os.CreateTemp(tempDirectory(), "tmp.")
	if err != nil {
		return ioResult(V{}, withoutPath(err))
	}
	return Lean_io_result_mk_ok(ctor(0, newHandle(file, true), Lean_mk_string(file.Name())))
}

func Lean_io_create_tempdir() V {
	path, err := os.MkdirTemp(tempDirectory(), "tmp.")
	if err != nil {
		return ioResult(V{}, withoutPath(err))
	}
	return Lean_io_result_mk_ok(Lean_mk_string(path))
}

func Lean_get_current_time() V {
	now := time.Now()
	return Lean_io_result_mk_ok(ctor(0, IntFromInt64(now.Unix()), IntFromInt64(int64(now.Nanosecond()))))
}

func Lean_system_platform_windows(_ V) uint8    { return Bool(runtime.GOOS == "windows") }
func Lean_system_platform_osx(_ V) uint8        { return Bool(runtime.GOOS == "darwin") }
func Lean_system_platform_linux(_ V) uint8      { return Bool(runtime.GOOS == "linux") }
func Lean_system_platform_emscripten(_ V) uint8 { return 0 }

func Lean_internal_get_hardware_concurrency(_ V) uint32 { return uint32(runtime.NumCPU()) }

func Lean_io_get_tid() uint64 { return threadID() }
