package rt

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
)

type processOutput struct {
	mu     sync.Mutex
	ready  *sync.Cond
	data   bytes.Buffer
	result error
}

func (o *processOutput) Read(data []byte) (int, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	for o.data.Len() == 0 && o.result == nil {
		o.ready.Wait()
	}
	if o.data.Len() == 0 {
		return 0, o.result
	}
	return o.data.Read(data)
}

func (o *processOutput) Write(data []byte) (int, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if o.result != nil {
		return 0, o.result
	}
	n, err := o.data.Write(data)
	o.ready.Signal()
	return n, err
}

func (o *processOutput) finish(err error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if o.result == nil {
		o.result = err
		o.ready.Broadcast()
	}
}

func (o *processOutput) close() {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.result = os.ErrClosed
	o.data = bytes.Buffer{}
	o.ready.Broadcast()
}

func processReadHandle(file *os.File) V {
	value := newHandle(file, true)
	h := handle(value)
	o := &processOutput{}
	o.ready = sync.NewCond(&o.mu)
	h.reader = bufio.NewReader(o)
	h.output = o
	go func() {
		_, err := io.Copy(o, file)
		if err == nil {
			err = io.EOF
		}
		o.finish(err)
	}()
	return value
}

type process struct {
	pid      int
	cmd      *exec.Cmd
	group    bool
	done     chan struct{}
	exitCode V
	waitErr  error
	mu       sync.Mutex
	waited   bool
}

func (p *process) reap() {
	p.waitErr = p.cmd.Wait()
	var exitErr *exec.ExitError
	if errors.As(p.waitErr, &exitErr) {
		p.waitErr = nil
	}
	if p.waitErr == nil {
		status := p.cmd.ProcessState.Sys().(syscall.WaitStatus)
		if status.Signaled() {
			p.exitCode = Lean_box(uint64(128 + status.Signal()))
		} else {
			p.exitCode = Lean_box(uint64(status.ExitStatus()))
		}
	}
	close(p.done)
}

func (p *process) wait(try bool) V {
	if try {
		select {
		case <-p.done:
		default:
			return Lean_io_result_mk_ok(V{})
		}
	} else {
		<-p.done
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.waited {
		return ioResult(V{}, syscall.ECHILD)
	}
	p.waited = true
	if p.waitErr != nil {
		return ioResult(V{}, p.waitErr)
	}
	if try {
		return Lean_io_result_mk_ok(ctor(1, p.exitCode))
	}
	return Lean_io_result_mk_ok(p.exitCode)
}

func processEnv(args V) []string {
	env := []string{}
	if Lean_ctor_get_uint8(args, 40) != 0 {
		env = os.Environ()
	}
	for _, edit := range Lean_ctor_get(args, 4).p.s().fs {
		key := cString(Lean_ctor_get(edit, 0))
		if key == "" || strings.ContainsRune(key, '=') {
			continue
		}
		value := Lean_ctor_get(edit, 1)
		prefix := key + "="
		i := 0
		for i < len(env) && !strings.HasPrefix(env[i], prefix) {
			i++
		}
		switch {
		case value.p == nil:
			if i < len(env) {
				env = append(env[:i], env[i+1:]...)
			}
		case i == len(env):
			env = append(env, prefix+cString(Lean_ctor_get(value, 0)))
		default:
			env[i] = prefix + cString(Lean_ctor_get(value, 0))
		}
	}
	return env
}

func processExecutable(name, cwd string, env []string) string {
	if strings.ContainsRune(name, '/') {
		return name
	}
	if name == "" {
		return ""
	}
	path := "/bin:/usr/bin"
	for _, entry := range env {
		if value, ok := strings.CutPrefix(entry, "PATH="); ok {
			path = value
			break
		}
	}
	for directory := range strings.SplitSeq(path, string(os.PathListSeparator)) {
		candidate := filepath.Join(directory, name)
		resolved := candidate
		if !filepath.IsAbs(candidate) {
			resolved = filepath.Join(cwd, candidate)
		}
		info, err := os.Stat(resolved)
		if err == nil && !info.IsDir() && syscall.Access(resolved, 1) == nil {
			return candidate
		}
	}
	return ""
}

func childStreams(config V) (parent, child [3]*os.File, err error) {
	for i, inherited := range []*os.File{os.Stdin, os.Stdout, os.Stderr} {
		switch Lean_ctor_get_uint8(config, i) {
		case 0:
			var r, w *os.File
			r, w, err = os.Pipe()
			if i == 0 {
				parent[i], child[i] = w, r
			} else {
				parent[i], child[i] = r, w
			}
		case 1:
			child[i] = inherited
		case 2:
			mode := os.O_WRONLY
			if i == 0 {
				mode = os.O_RDONLY
			}
			child[i], err = os.OpenFile(os.DevNull, mode, 0)
		default:
			err = syscall.EINVAL
		}
		if err != nil {
			return parent, child, err
		}
	}
	return parent, child, nil
}

func closeChildStreams(streams [3]*os.File) {
	for _, f := range streams {
		if f != nil && f != os.Stdin && f != os.Stdout && f != os.Stderr {
			_ = f.Close()
		}
	}
}

func launchChild(args V, streams [3]*os.File) (*exec.Cmd, bool, error) {
	cmdName := cString(Lean_ctor_get(args, 1))
	argv := []string{cmdName}
	for _, arg := range Lean_ctor_get(args, 2).p.s().fs {
		argv = append(argv, cString(arg))
	}
	cwd := ""
	badCwd := false
	if value := Lean_ctor_get(args, 3); value.p != nil {
		cwd = cString(Lean_ctor_get(value, 0))
		info, err := os.Stat(cwd)
		badCwd = err != nil || !info.IsDir() || syscall.Access(cwd, 1) != nil
	}
	env := processEnv(args)
	group := Lean_ctor_get_uint8(args, 41) != 0
	newCommand := func(path string, arguments, environment []string, dir string) *exec.Cmd {
		return &exec.Cmd{
			Path: path, Args: arguments, Env: environment, Dir: dir,
			Stdin: streams[0], Stdout: streams[1], Stderr: streams[2],
			SysProcAttr: &syscall.SysProcAttr{Setsid: group},
		}
	}
	if path := processExecutable(cmdName, cwd, env); !badCwd && path != "" {
		command := newCommand(path, argv, env, cwd)
		err := command.Start()
		if errors.Is(err, syscall.ENOEXEC) {
			command = newCommand("/bin/sh", append([]string{"sh", path}, argv[1:]...), env, cwd)
			err = command.Start()
		}
		if err == nil {
			return command, group, nil
		}
		var errno syscall.Errno
		if !errors.As(err, &errno) || !execFailure(errno) {
			return nil, false, err
		}
	}
	diagnostic := fmt.Sprintf("could not execute external process '%s'", cmdName)
	if badCwd {
		diagnostic = "could not change directory to " + cwd
	}
	command := newCommand("/bin/sh", []string{"sh", "-c", `printf '%s\n' "$1" >&2; exit 255`, "sh", diagnostic}, []string{}, "")
	return command, group, command.Start()
}

func execFailure(errno syscall.Errno) bool {
	switch errno {
	case syscall.ENOENT, syscall.ENOTDIR, syscall.EACCES, syscall.EPERM, syscall.ELOOP,
		syscall.EISDIR, syscall.ENAMETOOLONG, syscall.E2BIG, syscall.ETXTBSY:
		return true
	default:
		return false
	}
}

func Lean_io_process_spawn(args V) V {
	defer Lean_dec(args)
	parent, child, err := childStreams(Lean_ctor_get(args, 0))
	defer closeChildStreams(child)
	if err != nil {
		closeChildStreams(parent)
		return ioResult(V{}, withoutPath(err))
	}
	command, group, err := launchChild(args, child)
	if err != nil {
		closeChildStreams(parent)
		return ioResult(V{}, withoutPath(err))
	}
	state := &process{pid: command.Process.Pid, cmd: command, group: group, done: make(chan struct{})}
	result := newCtorX3(state)
	if parent[0] != nil {
		Lean_ctor_set(result, 0, newHandle(parent[0], true))
	}
	for _, i := range []int{1, 2} {
		if parent[i] != nil {
			Lean_ctor_set(result, i, processReadHandle(parent[i]))
		}
	}
	go state.reap()
	return Lean_io_result_mk_ok(result)
}

func childProcess(child V) *process { return child.p.ctorExt().x.(*process) }

func Lean_io_process_child_wait(_, child V) V { return childProcess(child).wait(false) }

func Lean_io_process_child_try_wait(_, child V) V { return childProcess(child).wait(true) }

func Lean_io_process_child_kill(_, child V) V {
	state := childProcess(child)
	var err error
	if state.group {
		select {
		case <-state.done:
			err = syscall.ESRCH
		default:
			err = syscall.Kill(-state.pid, syscall.SIGKILL)
		}
	} else {
		err = state.cmd.Process.Kill()
		if errors.Is(err, os.ErrProcessDone) {
			err = syscall.ESRCH
		}
	}
	return ioResult(V{}, err)
}

func Lean_io_process_child_pid(_, child V) uint32 {
	pid := childProcess(child).pid
	Lean_dec(child)
	return uint32(pid)
}

func Lean_io_process_child_take_stdin(_, child V) V {
	result := newCtorX3(childProcess(child))
	Lean_ctor_set(result, 1, own(Lean_ctor_get(child, 1)))
	Lean_ctor_set(result, 2, own(Lean_ctor_get(child, 2)))
	stdin := own(Lean_ctor_get(child, 0))
	Lean_dec(child)
	return Lean_io_result_mk_ok(ctor(0, stdin, result))
}
