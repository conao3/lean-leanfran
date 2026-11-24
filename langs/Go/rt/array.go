package rt

func array(fields []V) V {
	return V{p: &Obj{rc: 1, kind: kindArray, fs: fields}}
}

func Lean_mk_empty_array() V { return array(nil) }

func Lean_mk_empty_array_with_capacity(n V) V {
	return array(make([]V, 0, arrayCapacity(n)))
}

func Lean_mk_array(n, value V) V {
	a := Lean_mk_empty_array_with_capacity(n)
	for range n.n {
		a.p.fs = append(a.p.fs, own(value))
	}
	Lean_dec(value)
	return a
}

func Lean_array_mk(list V) V {
	a := Lean_mk_empty_array()
	for l := list; l.p != nil; l = Lean_ctor_get(l, 1) {
		a.p.fs = append(a.p.fs, own(Lean_ctor_get(l, 0)))
	}
	Lean_dec(list)
	return a
}

func Lean_array_to_list(a V) V {
	var list V
	for i := len(a.p.fs) - 1; i >= 0; i-- {
		list = ctor(1, own(a.p.fs[i]), list)
	}
	Lean_dec(a)
	return list
}

func Lean_array_size(a V) uint64 { return uint64(len(a.p.fs)) }
func Lean_array_get_size(a V) V  { return Lean_box(Lean_array_size(a)) }

func Lean_array_sz(a V) V {
	n := Lean_array_get_size(a)
	Lean_dec(a)
	return n
}

func Lean_array_uget_borrowed(a V, i uint64) V { return a.p.fs[i] }
func Lean_array_uget(a V, i uint64) V          { return own(Lean_array_uget_borrowed(a, i)) }
func Lean_array_fget_borrowed(a, i V) V        { return Lean_array_uget_borrowed(a, i.n) }
func Lean_array_fget(a, i V) V                 { return Lean_array_uget(a, i.n) }

func Lean_array_get_panic(def V) V {
	return Lean_panic_fn(def, Lean_mk_string("Error: index out of bounds"))
}

func Lean_array_get(def, a, i V) V {
	if i.p == nil && i.n < Lean_array_size(a) {
		return Lean_array_uget(a, i.n)
	}
	return Lean_array_get_panic(own(def))
}

func Lean_array_get_borrowed(def, a, i V) V {
	if i.p == nil && i.n < Lean_array_size(a) {
		return Lean_array_uget_borrowed(a, i.n)
	}
	return Lean_array_get_panic(own(def))
}

func Lean_copy_array(a V) V {
	fields := make([]V, len(a.p.fs))
	for i, f := range a.p.fs {
		fields[i] = own(f)
	}
	return array(fields)
}

func Lean_ensure_exclusive_array(a V) V {
	if Lean_is_exclusive(a) {
		return a
	}
	copy := Lean_copy_array(a)
	Lean_dec(a)
	return copy
}

func Lean_array_push(a, v V) V {
	a = Lean_ensure_exclusive_array(a)
	a.p.fs = append(a.p.fs, v)
	return a
}

func Lean_array_uset(a V, i uint64, v V) V {
	a = Lean_ensure_exclusive_array(a)
	Lean_dec(a.p.fs[i])
	a.p.fs[i] = v
	return a
}

func Lean_array_fset(a, i, v V) V { return Lean_array_uset(a, i.n, v) }

func Lean_array_set_panic(a, v V) V {
	Lean_dec(v)
	return Lean_panic_fn(a, Lean_mk_string("Error: index out of bounds"))
}

func Lean_array_set(a, i, v V) V {
	if i.p == nil && i.n < Lean_array_size(a) {
		return Lean_array_uset(a, i.n, v)
	}
	return Lean_array_set_panic(a, v)
}

func Lean_array_pop(a V) V {
	n := len(a.p.fs)
	if n > 0 {
		a = Lean_ensure_exclusive_array(a)
		Lean_dec(a.p.fs[n-1])
		a.p.fs[n-1] = V{}
		a.p.fs = a.p.fs[:n-1]
	}
	return a
}

func Lean_array_uswap(a V, i, j uint64) V {
	if i != j {
		a = Lean_ensure_exclusive_array(a)
		a.p.fs[i], a.p.fs[j] = a.p.fs[j], a.p.fs[i]
	}
	return a
}

func Lean_array_fswap(a, i, j V) V { return Lean_array_uswap(a, i.n, j.n) }

func Lean_array_swap(a, i, j V) V {
	if i.p != nil || j.p != nil || i.n >= Lean_array_size(a) || j.n >= Lean_array_size(a) {
		return a
	}
	return Lean_array_uswap(a, i.n, j.n)
}

func Lean_array_extract(a, start, stop V) V {
	if start.p != nil || start.n >= Lean_array_size(a) {
		return Lean_mk_empty_array()
	}
	end := Lean_array_size(a)
	if stop.p == nil {
		end = max(start.n, min(end, stop.n))
	}
	fields := make([]V, end-start.n)
	for i, field := range a.p.fs[start.n:end] {
		fields[i] = own(field)
	}
	return array(fields)
}
