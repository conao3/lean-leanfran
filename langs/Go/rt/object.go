package rt

import "math"

type V struct {
	p *Obj
	n uint64
}

type Obj struct {
	rc   int32
	tag  uint16
	kind uint8
	fs   []V
	x    any
}

const (
	kindCtor uint8 = iota
	kindClosure
	kindArray
	kindByteArray
	kindFloatArray
	kindString
	kindBigInt
	kindThunk
	kindRef
	kindHandle
	kindTask
	kindPromise
)

func Lean_box(n uint64) V   { return V{n: n} }
func Lean_unbox(v V) uint64 { return v.n }
func ValBits(v V) uint64    { return v.n }

func Bool(b bool) uint8 { return decision(b) }

func Lean_is_scalar(v V) bool         { return v.p == nil }
func Lean_is_exclusive(v V) bool      { return v.p != nil && v.p.rc == 1 }
func Lean_is_exclusive_obj(v V) uint8 { return Bool(Lean_is_exclusive(v)) }
func Lean_is_shared(v V) bool         { return v.p != nil && v.p.rc > 1 }

func Lean_obj_tag(v V) uint64 {
	if v.p == nil {
		return v.n
	}
	switch v.p.kind {
	case kindClosure:
		return 245
	case kindArray:
		return 246
	case kindByteArray, kindFloatArray:
		return 248
	case kindString:
		return 249
	case kindBigInt:
		return 250
	case kindThunk:
		return 251
	case kindTask:
		return 252
	case kindRef:
		return 253
	case kindHandle:
		return 254
	case kindPromise:
		return 244
	default:
		return uint64(v.p.tag)
	}
}

func Lean_inc(v V) {
	if v.p != nil && v.p.rc > 0 {
		v.p.rc++
	}
}

func Lean_inc_n(v V, n int) {
	if v.p != nil && v.p.rc > 0 {
		v.p.rc += int32(n)
	}
}

func Lean_inc_ref(v V)          { Lean_inc(v) }
func Lean_inc_ref_n(v V, n int) { Lean_inc_n(v, n) }

func own(v V) V {
	Lean_inc(v)
	return v
}

func Lean_dec(v V) {
	if v.p == nil || v.p.rc <= 0 {
		return
	}
	v.p.rc--
	if v.p.rc != 0 {
		return
	}
	stack := []*Obj{v.p}
	for len(stack) != 0 {
		i := len(stack) - 1
		o := stack[i]
		stack = stack[:i]
		if o.kind == kindPromise {
			resolveTask(o.fs[0], V{})
		}
		for _, f := range o.fs {
			if f.p != nil && f.p.rc > 0 {
				f.p.rc--
				if f.p.rc == 0 {
					stack = append(stack, f.p)
				}
			}
		}
		if o.kind == kindHandle {
			o.x.(*fileHandle).close()
		}
		o.rc = -1
		clear(o.fs)
		o.fs = nil
		o.x = nil
	}
}

func Lean_dec_ref(v V) { Lean_dec(v) }

func Lean_mark_persistent(v V) V {
	if v.p == nil || v.p.rc <= 0 {
		return v
	}
	stack := []*Obj{v.p}
	for len(stack) != 0 {
		i := len(stack) - 1
		o := stack[i]
		stack = stack[:i]
		if o.rc <= 0 {
			continue
		}
		o.rc = 0
		for _, f := range o.fs {
			if f.p != nil && f.p.rc > 0 {
				stack = append(stack, f.p)
			}
		}
	}
	return v
}

func Lean_alloc_ctor(tag uint16, numObjs, scalarBytes int) V {
	words := numObjs + (scalarBytes+7)/8
	var p *Obj
	if words <= 4 {
		o := &struct {
			Obj
			fields [4]V
		}{}
		o.fs = o.fields[:words:words]
		p = &o.Obj
	} else {
		p = &Obj{fs: make([]V, words)}
	}
	p.rc = 1
	p.tag = tag
	p.kind = kindCtor
	return V{p: p}
}

func ctor(tag uint16, fields ...V) V {
	v := Lean_alloc_ctor(tag, len(fields), 0)
	copy(v.p.fs, fields)
	return v
}

func Lean_ctor_get(v V, i int) V        { return v.p.fs[i] }
func Lean_ctor_set(v V, i int, value V) { v.p.fs[i] = value }
func Lean_ctor_set_tag(v V, tag uint16) { v.p.tag = tag }

func Lean_ctor_release(v V, i int) {
	Lean_dec(v.p.fs[i])
	v.p.fs[i] = V{}
}

func Lean_ctor_get_usize(v V, i int) uint64    { return v.p.fs[i].n }
func Lean_ctor_set_usize(v V, i int, n uint64) { v.p.fs[i].n = n }

func ctorBits(v V, offset int) uint64 {
	return v.p.fs[offset/8].n >> (8 * (offset % 8))
}

func setCtorBits(v V, offset int, n, mask uint64) {
	f := &v.p.fs[offset/8].n
	shift := 8 * (offset % 8)
	*f = *f&^(mask<<shift) | (n << shift)
}

func Lean_ctor_get_uint8(v V, offset int) uint8   { return uint8(ctorBits(v, offset)) }
func Lean_ctor_get_uint16(v V, offset int) uint16 { return uint16(ctorBits(v, offset)) }
func Lean_ctor_get_uint32(v V, offset int) uint32 { return uint32(ctorBits(v, offset)) }
func Lean_ctor_get_uint64(v V, offset int) uint64 { return ctorBits(v, offset) }
func Lean_ctor_get_float(v V, offset int) float64 { return math.Float64frombits(ctorBits(v, offset)) }

func Lean_ctor_get_float32(v V, offset int) float32 {
	return math.Float32frombits(uint32(ctorBits(v, offset)))
}

func Lean_ctor_set_uint8(v V, offset int, n uint8) { setCtorBits(v, offset, uint64(n), math.MaxUint8) }

func Lean_ctor_set_uint16(v V, offset int, n uint16) {
	setCtorBits(v, offset, uint64(n), math.MaxUint16)
}

func Lean_ctor_set_uint32(v V, offset int, n uint32) {
	setCtorBits(v, offset, uint64(n), math.MaxUint32)
}
func Lean_ctor_set_uint64(v V, offset int, n uint64) { setCtorBits(v, offset, n, math.MaxUint64) }
func Lean_ctor_set_float(v V, offset int, n float64) {
	Lean_ctor_set_uint64(v, offset, math.Float64bits(n))
}

func Lean_ctor_set_float32(v V, offset int, n float32) {
	Lean_ctor_set_uint32(v, offset, math.Float32bits(n))
}

func Reset(v V, count int) V {
	if Lean_is_exclusive(v) {
		for i := range count {
			Lean_ctor_release(v, i)
		}
		return v
	}
	Lean_dec(v)
	return V{}
}

func Reuse(v V, tag uint16, numObjs, scalarBytes int, updateTag bool) V {
	if v.p == nil {
		return Lean_alloc_ctor(tag, numObjs, scalarBytes)
	}
	if updateTag {
		Lean_ctor_set_tag(v, tag)
	}
	return v
}
