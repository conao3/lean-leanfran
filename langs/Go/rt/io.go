package rt

import (
	"bufio"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode"
	"unicode/utf8"
)

func Lean_io_result_mk_ok(v V) V       { return ctor(0, v) }
func Lean_io_result_mk_error(v V) V    { return ctor(1, v) }
func Lean_io_result_is_ok(v V) bool    { return Lean_obj_tag(v) == 0 }
func Lean_io_result_is_error(v V) bool { return Lean_obj_tag(v) == 1 }
func Lean_io_result_get_value(v V) V   { return Lean_ctor_get(v, 0) }
func Lean_io_result_get_error(v V) V   { return Lean_ctor_get(v, 0) }

func Lean_io_result_take_value(result V) V {
	v := own(Lean_io_result_get_value(result))
	Lean_dec(result)
	return v
}

func Lean_io_mk_world() V         { return V{} }
func Lean_mk_io_user_error(v V) V { return ctor(18, v) }

func Lean_panic_fn(v, message V) V {
	_, _ = fmt.Fprintln(os.Stderr, cString(message))
	Lean_dec(message)
	return v
}

func Lean_panic_fn_borrowed(v, message V) V { return Lean_panic_fn(own(v), message) }

func Lean_internal_panic(message string) {
	_, _ = fmt.Fprintln(os.Stderr, "INTERNAL PANIC: "+message)
	os.Exit(1)
}

func Lean_internal_panic_unreachable() {
	Lean_internal_panic("unreachable code has been reached")
}

func cString(v V) string {
	s, _, _ := strings.Cut(String(v), "\x00")
	return s
}

func ioErrorTag(errno syscall.Errno) uint16 {
	switch errno {
	case syscall.EEXIST, syscall.EINPROGRESS, syscall.EISCONN:
		return 0
	case syscall.EADDRINUSE, syscall.EBUSY, syscall.EDEADLK, syscall.ETXTBSY:
		return 2
	case syscall.ECONNRESET, syscall.EIDRM, syscall.ENETDOWN, syscall.ENETRESET, syscall.ENOLINK, syscall.EPIPE:
		return 3
	case syscall.EADDRNOTAVAIL, syscall.EAFNOSUPPORT, syscall.ENODEV, syscall.ENOPROTOOPT,
		syscall.ENOSYS, syscall.EOPNOTSUPP, syscall.ERANGE, syscall.ESPIPE, syscall.EXDEV:
		return 4
	case syscall.EIO:
		return 5
	case syscall.ENOTEMPTY:
		return 6
	case syscall.ENOTTY:
		return 7
	case syscall.EPROTO, syscall.EPROTONOSUPPORT, syscall.EPROTOTYPE:
		return 8
	case syscall.ETIMEDOUT:
		return 9
	case syscall.EINTR:
		return 10
	case syscall.ENOENT:
		return 11
	case syscall.ELOOP, syscall.ENAMETOOLONG, syscall.EDESTADDRREQ, syscall.EILSEQ, syscall.EINVAL,
		syscall.EDOM, syscall.EBADF, syscall.ENOEXEC, syscall.ENOTCONN, syscall.ENOTSOCK:
		return 12
	case syscall.EACCES, syscall.EROFS, syscall.ECONNABORTED, syscall.EFBIG, syscall.EPERM:
		return 13
	case syscall.EMFILE, syscall.ENFILE, syscall.ENOSPC, syscall.E2BIG, syscall.EAGAIN,
		syscall.EMLINK, syscall.EMSGSIZE, syscall.ENOBUFS, syscall.ENOLCK, syscall.ENOMEM:
		return 14
	case syscall.EISDIR, syscall.EBADMSG, syscall.ENOTDIR:
		return 15
	case syscall.ENXIO, syscall.EHOSTUNREACH, syscall.ENETUNREACH, syscall.ECHILD,
		syscall.ECONNREFUSED, syscall.ENOMSG, syscall.ESRCH:
		return 16
	default:
		return 1
	}
}

func ioErrorHasFilename(tag uint16) bool { return tag == 0 || tag >= 10 && tag <= 16 }

func ioError(err error) V {
	if errors.Is(err, io.EOF) {
		return Lean_box(17)
	}
	var errno syscall.Errno
	if !errors.As(err, &errno) {
		return Lean_mk_io_user_error(Lean_mk_string(err.Error()))
	}
	tag := ioErrorTag(errno)
	details := Lean_mk_string(errno.Error())
	n := 1
	if ioErrorHasFilename(tag) {
		n++
	}
	v := Lean_alloc_ctor(tag, n, 4)
	Lean_ctor_set_uint32(v, 8*n, uint32(errno))
	Lean_ctor_set(v, n-1, details)
	if n == 2 {
		var fileName string
		var pathErr *os.PathError
		var linkErr *os.LinkError
		switch {
		case errors.As(err, &pathErr):
			fileName = pathErr.Path
		case errors.As(err, &linkErr):
			fileName = linkErr.Old
		}
		if tag == 10 || tag == 11 {
			Lean_ctor_set(v, 0, Lean_mk_string(fileName))
		} else if fileName != "" {
			Lean_ctor_set(v, 0, ctor(1, Lean_mk_string(fileName)))
		}
	}
	return v
}

func ioResult(value V, err error) V {
	if err != nil {
		Lean_dec(value)
		return Lean_io_result_mk_error(ioError(err))
	}
	return Lean_io_result_mk_ok(value)
}

func decapitalize(s string) string {
	r, size := utf8.DecodeRuneInString(s)
	if size == 0 {
		return s
	}
	return string(unicode.ToLower(r)) + s[size:]
}

func ioErrorMessage(v V) string {
	tag := uint16(Lean_obj_tag(v))
	switch tag {
	case 17:
		return "end of file"
	case 18:
		return String(Lean_ctor_get(v, 0))
	}
	gists := [...]string{
		"already exists", "", "resource busy", "resource vanished", "unsupported operation",
		"hardware fault", "directory not empty", "illegal operation", "protocol error",
		"time expired", "interrupted system call", "no such file or directory", "invalid argument",
		"", "resource exhausted", "inappropriate type", "no such thing",
	}
	n := 1
	if ioErrorHasFilename(tag) {
		n++
	}
	details := decapitalize(String(Lean_ctor_get(v, n-1)))
	gist := gists[tag]
	if gist == "" {
		gist = details
	}
	switch tag {
	case 1, 5, 6, 11, 13:
		details = ""
	default:
		details = ", " + details
	}
	message := fmt.Sprintf("%s (error code: %d%s)", gist, Lean_ctor_get_uint32(v, 8*n), details)
	if n == 2 {
		file := Lean_ctor_get(v, 0)
		if tag == 10 || tag == 11 {
			message += "\n  file: " + String(file)
		} else if !Lean_is_scalar(file) {
			message += "\n  file: " + String(Lean_ctor_get(file, 0))
		}
	}
	return message
}

func Lean_io_error_to_string(v V) V {
	s := Lean_mk_string(ioErrorMessage(v))
	Lean_dec(v)
	return s
}

func Lean_io_result_show_error(result V) {
	msg, _, _ := strings.Cut(ioErrorMessage(Lean_io_result_get_error(result)), "\x00")
	_, _ = fmt.Fprintln(os.Stderr, "uncaught exception: "+msg)
}

func InitResult(result V) V {
	if Lean_io_result_is_error(result) {
		Lean_io_result_show_error(result)
		Lean_dec(result)
		os.Exit(1)
	}
	return Lean_io_result_take_value(result)
}

func Lean_run_main(main func(V, V) V, takesArgs, returnsCode bool) {
	var args V
	if takesArgs {
		for i := len(os.Args) - 1; i >= 1; i-- {
			args = ctor(1, Lean_mk_string(os.Args[i]), args)
		}
	}
	result := InitResult(main(args, Lean_io_mk_world()))
	if returnsCode {
		os.Exit(int(uint32(Lean_unbox(result))))
	}
	Lean_dec(result)
}

type fileHandle struct {
	mu     sync.Mutex
	file   *os.File
	reader *bufio.Reader
	owned  bool
}

func newHandle(file *os.File, owned bool) V {
	h := &fileHandle{file: file, reader: bufio.NewReader(file), owned: owned}
	return V{p: &Obj{rc: 1, kind: kindHandle, x: h}}
}

func (h *fileHandle) close() {
	if h.owned {
		_ = h.file.Close()
	}
}

func handle(v V) *fileHandle { return v.p.x.(*fileHandle) }

func Lean_io_prim_handle_mk(name V, mode uint8) V {
	flags := [...]int{
		os.O_RDONLY, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, os.O_WRONLY | os.O_CREATE | os.O_EXCL,
		os.O_RDWR, os.O_WRONLY | os.O_CREATE | os.O_APPEND,
	}
	file, err := os.OpenFile(cString(name), flags[mode], 0o666)
	if err != nil {
		return ioResult(V{}, err)
	}
	return Lean_io_result_mk_ok(newHandle(file, true))
}

func Lean_io_prim_handle_is_tty(v V) uint8 {
	return Bool(isTerminal(handle(v).file.Fd()))
}

func Lean_io_prim_handle_flush(_ V) V { return Lean_io_result_mk_ok(V{}) }

func Lean_io_prim_handle_get_line(v V) V {
	h := handle(v)
	h.mu.Lock()
	line, err := h.reader.ReadString('\n')
	h.mu.Unlock()
	if errors.Is(err, io.EOF) {
		err = nil
	}
	return ioResult(Lean_mk_string(strings.ToValidUTF8(line, "\uFFFD")), err)
}

func Lean_io_prim_handle_read(v V, count uint64) V {
	h := handle(v)
	h.mu.Lock()
	defer h.mu.Unlock()
	if count == 0 {
		return Lean_io_result_mk_ok(byteArray(nil))
	}
	data := make([]byte, count)
	n, err := io.ReadFull(h.reader, data)
	if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
		err = nil
	}
	return ioResult(byteArray(data[:n]), err)
}

func (h *fileHandle) write(data []byte) V {
	h.mu.Lock()
	defer h.mu.Unlock()
	if n := h.reader.Buffered(); n > 0 {
		if _, err := h.file.Seek(-int64(n), io.SeekCurrent); err != nil {
			return ioResult(V{}, err)
		}
		h.reader.Reset(h.file)
	}
	_, err := h.file.Write(data)
	return ioResult(V{}, err)
}

func Lean_io_prim_handle_put_str(v, s V) V   { return handle(v).write(stringData(s).data) }
func Lean_io_prim_handle_write(v, bytes V) V { return handle(v).write(byteData(bytes).values) }

func Lean_io_prim_handle_rewind(v V) V {
	h := handle(v)
	h.mu.Lock()
	defer h.mu.Unlock()
	_, err := h.file.Seek(0, io.SeekStart)
	if err == nil {
		h.reader.Reset(h.file)
	}
	return ioResult(V{}, err)
}

func Lean_io_prim_handle_truncate(v V) V {
	h := handle(v)
	h.mu.Lock()
	defer h.mu.Unlock()
	offset, err := h.file.Seek(0, io.SeekCurrent)
	if err == nil {
		err = h.file.Truncate(offset - int64(h.reader.Buffered()))
	}
	return ioResult(V{}, err)
}

func Lean_stream_of_handle(v V) V {
	Lean_inc_n(v, 5)
	return ctor(0,
		Closure(func(_ *Tail, args []V) V {
			result := Lean_io_prim_handle_flush(args[0])
			Lean_dec(args[0])
			return result
		}, 2, []V{v}),
		Closure(func(_ *Tail, args []V) V {
			result := Lean_io_prim_handle_read(args[0], args[1].n)
			Lean_dec(args[0])
			return result
		}, 3, []V{v}),
		Closure(func(_ *Tail, args []V) V {
			result := Lean_io_prim_handle_write(args[0], args[1])
			Lean_dec(args[0])
			Lean_dec(args[1])
			return result
		}, 3, []V{v}),
		Closure(func(_ *Tail, args []V) V {
			result := Lean_io_prim_handle_get_line(args[0])
			Lean_dec(args[0])
			return result
		}, 2, []V{v}),
		Closure(func(_ *Tail, args []V) V {
			result := Lean_io_prim_handle_put_str(args[0], args[1])
			Lean_dec(args[0])
			Lean_dec(args[1])
			return result
		}, 3, []V{v}),
		Closure(func(_ *Tail, args []V) V {
			result := Lean_io_prim_handle_is_tty(args[0])
			Lean_dec(args[0])
			return Lean_box(uint64(result))
		}, 2, []V{v}),
	)
}

var standardStreams = struct {
	sync.Mutex
	values [3]V
}{
	values: [3]V{
		Lean_mark_persistent(Lean_stream_of_handle(newHandle(os.Stdin, false))),
		Lean_mark_persistent(Lean_stream_of_handle(newHandle(os.Stdout, false))),
		Lean_mark_persistent(Lean_stream_of_handle(newHandle(os.Stderr, false))),
	},
}

func getStream(i int) V {
	standardStreams.Lock()
	defer standardStreams.Unlock()
	return standardStreams.values[i]
}

func setStream(i int, stream V) V {
	standardStreams.Lock()
	defer standardStreams.Unlock()
	old := standardStreams.values[i]
	standardStreams.values[i] = Lean_mark_persistent(stream)
	return old
}

func Lean_get_stdin() V         { return getStream(0) }
func Lean_get_stdout() V        { return getStream(1) }
func Lean_get_stderr() V        { return getStream(2) }
func Lean_get_set_stdin(v V) V  { return setStream(0, v) }
func Lean_get_set_stdout(v V) V { return setStream(1, v) }
func Lean_get_set_stderr(v V) V { return setStream(2, v) }

func Lean_dbg_trace(message, fn V) V {
	stream := Lean_get_stderr()
	out := own(Lean_ctor_get(stream, 4))
	Lean_dec(stream)
	result := Lean_apply(out, []V{Lean_string_push(message, '\n'), {}})
	if Lean_io_result_is_error(result) {
		Lean_internal_panic("Could not write debug trace")
	}
	Lean_dec(result)
	return Lean_apply(fn, []V{{}})
}

func Lean_dbg_sleep(ms uint32, fn V) V {
	time.Sleep(time.Duration(ms) * time.Millisecond)
	return Lean_apply(fn, []V{{}})
}

var monotonicStart = time.Now()

func Lean_io_mono_ms_now() V { return Lean_box(uint64(time.Since(monotonicStart).Milliseconds())) }

func Lean_io_mono_nanos_now() V { return Lean_box(uint64(time.Since(monotonicStart).Nanoseconds())) }

func Lean_io_get_random_bytes(count uint64) V {
	if count > uint64(int(^uint(0)>>1)) {
		return ioResult(V{}, syscall.ENOMEM)
	}
	data := make([]byte, int(count))
	_, err := rand.Read(data)
	return ioResult(byteArray(data), err)
}

func Lean_system_platform_nbits(_ V) V { return Lean_box(64) }

func Lean_io_getenv(v V) V {
	s, ok := os.LookupEnv(cString(v))
	if !ok {
		return V{}
	}
	return ctor(1, Lean_mk_string(s))
}

func Lean_io_current_dir() V {
	path, err := os.Getwd()
	return ioResult(Lean_mk_string(path), err)
}

func Lean_io_process_get_current_dir() V    { return Lean_io_current_dir() }
func Lean_io_process_set_current_dir(v V) V { return ioResult(V{}, os.Chdir(cString(v))) }
func Lean_io_process_get_pid() uint32       { return uint32(os.Getpid()) }

func Lean_io_app_path() V {
	path, err := os.Executable()
	return ioResult(Lean_mk_string(path), err)
}

func Lean_io_realpath(v V) V {
	path := cString(v)
	Lean_dec(v)
	resolved, err := filepath.EvalSymlinks(path)
	if err == nil {
		resolved, err = filepath.Abs(resolved)
	}
	return ioResult(Lean_mk_string(resolved), err)
}

func Lean_io_remove_file(v V) V  { return ioResult(V{}, syscall.Unlink(cString(v))) }
func Lean_io_remove_dir(v V) V   { return ioResult(V{}, syscall.Rmdir(cString(v))) }
func Lean_io_create_dir(v V) V   { return ioResult(V{}, os.Mkdir(cString(v), 0o777)) }
func Lean_io_rename(a, b V) V    { return ioResult(V{}, os.Rename(cString(a), cString(b))) }
func Lean_io_hard_link(a, b V) V { return ioResult(V{}, os.Link(cString(a), cString(b))) }

func Lean_io_exit(code uint8) V {
	os.Exit(int(code))
	return V{}
}

func Lean_io_force_exit(code uint8) V { return Lean_io_exit(code) }
