package rt

import "sync"

type closure struct {
	fn    func(*Tail, []V) V
	arity int
}

func Closure(fn func(*Tail, []V) V, arity int, fixed []V) V {
	return V{p: &Obj{rc: 1, kind: kindClosure, fs: append([]V(nil), fixed...), x: closure{fn, arity}}}
}

type Tail struct {
	next  func(*Tail, []V) V
	args  []V
	small [8]V
	extra *extraArgs
}

type extraArgs struct {
	values []V
	next   *extraArgs
}

func (t *Tail) schedule(fn func(*Tail, []V) V, args []V) {
	if t.args == nil {
		t.args = t.small[:0]
	}
	t.args = append(t.args[:0], args...)
	t.next = fn
}

func Run(fn func(*Tail, []V) V, args []V) V {
	var t Tail
	for {
		t.next = nil
		v := fn(&t, args)
		if t.next != nil {
			fn, args = t.next, t.args
			continue
		}
		if t.extra == nil {
			return v
		}
		extra := t.extra
		t.extra = extra.next
		v = TailApply(&t, v, extra.values)
		for t.next == nil && t.extra != nil {
			extra = t.extra
			t.extra = extra.next
			v = TailApply(&t, v, extra.values)
		}
		if t.next == nil {
			return v
		}
		fn, args = t.next, t.args
	}
}

func TailCall(t *Tail, fn func(*Tail, []V) V, args []V) V {
	t.schedule(fn, args)
	return V{}
}

func Lean_apply(f V, args []V) V {
	return Run(func(t *Tail, args []V) V { return TailApply(t, f, args) }, args)
}

func TailApply(t *Tail, f V, args []V) V {
	c := f.p.x.(closure)
	fixed := f.p.fs
	missing := c.arity - len(fixed)
	if len(args) < missing {
		all := make([]V, 0, len(fixed)+len(args))
		for _, v := range fixed {
			all = append(all, own(v))
		}
		all = append(all, args...)
		Lean_dec(f)
		return V{p: &Obj{rc: 1, kind: kindClosure, fs: all, x: c}}
	}
	if len(args) > missing {
		t.extra = &extraArgs{values: append([]V(nil), args[missing:]...), next: t.extra}
	}
	if len(fixed) == 0 {
		t.schedule(c.fn, args[:missing])
	} else {
		var buf [8]V
		all := buf[:0]
		for _, v := range fixed {
			all = append(all, own(v))
		}
		t.schedule(c.fn, append(all, args[:missing]...))
	}
	Lean_dec(f)
	return V{}
}

type thunk struct {
	mu     sync.Mutex
	forced bool
}

func Lean_mk_thunk(fn V) V {
	return V{p: &Obj{rc: 1, kind: kindThunk, fs: []V{fn}, x: &thunk{}}}
}

func Lean_thunk_pure(v V) V {
	return V{p: &Obj{rc: 1, kind: kindThunk, fs: []V{v}, x: &thunk{forced: true}}}
}

func Lean_thunk_get(v V) V {
	state := v.p.x.(*thunk)
	state.mu.Lock()
	defer state.mu.Unlock()
	if !state.forced {
		result := Lean_apply(v.p.fs[0], []V{{}})
		if v.p.rc == 0 {
			Lean_mark_persistent(result)
		}
		v.p.fs[0] = result
		state.forced = true
	}
	return v.p.fs[0]
}

func Lean_thunk_get_own(v V) V { return own(Lean_thunk_get(v)) }

type ref struct {
	mu    sync.Mutex
	empty bool
}

func Lean_st_mk_ref(v V) V {
	return V{p: &Obj{rc: 1, kind: kindRef, fs: []V{v}, x: &ref{}}}
}

func Lean_st_ref_get(v V) V {
	state := v.p.x.(*ref)
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.empty {
		Lean_internal_panic("null reference read")
	}
	return own(v.p.fs[0])
}

func Lean_st_ref_put(v, value V) V {
	state := v.p.x.(*ref)
	state.mu.Lock()
	defer state.mu.Unlock()
	if !state.empty {
		Lean_internal_panic("ref.put on a nonempty reference")
	}
	if v.p.rc == 0 {
		Lean_mark_persistent(value)
	}
	v.p.fs[0] = value
	state.empty = false
	return V{}
}

func Lean_st_ref_take(v V) V        { return swapRef(v, V{}, true) }
func Lean_st_ref_swap(v, value V) V { return swapRef(v, value, false) }

func swapRef(v, value V, empty bool) V {
	state := v.p.x.(*ref)
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.empty {
		Lean_internal_panic("null reference read")
	}
	if v.p.rc == 0 {
		Lean_mark_persistent(value)
	}
	old := v.p.fs[0]
	v.p.fs[0] = value
	state.empty = empty
	return old
}

func Lean_st_ref_ptr_eq(a, b V) uint8 { return Bool(a.p == b.p) }
