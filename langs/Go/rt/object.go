package rt

import (
	"math"
	"unsafe"
)

type V struct {
	p *Obj
	n uint64
}

type Obj struct {
	rc   int32
	tag  uint8
	kind uint8
	nfs  uint16
}

const (
	headerSize = unsafe.Sizeof(Obj{})
	fieldSize  = unsafe.Sizeof(V{})
	hasX       = 0x80
)

type objS struct {
	Obj
	fs []V
}

type extSlot struct{ x any }

type objX struct {
	objS
	extSlot
}

type ctorN[A any] struct {
	Obj
	_ A
}

type ctorX[A any] struct {
	Obj
	_ A
	extSlot
}

func newObjX(kind uint8, fs []V, x any) *Obj {
	o := &objX{objS: objS{Obj: Obj{rc: 1, kind: kind | hasX}, fs: fs}, extSlot: extSlot{x}}
	return &o.Obj
}

func newCtorX3(x any) V {
	o := &ctorX[[3]V]{Obj: Obj{rc: 1, kind: kindCtor | hasX, nfs: 3}, extSlot: extSlot{x}}
	return V{p: &o.Obj}
}

func (o *Obj) kindOf() uint8 { return o.kind &^ hasX }

func (o *Obj) s() *objS { return (*objS)(unsafe.Pointer(o)) }

func (o *Obj) field(i int) *V {
	return (*V)(unsafe.Add(unsafe.Pointer(o), headerSize+uintptr(i)*fieldSize))
}

func (o *Obj) children() []V {
	if o.kind&^hasX != kindCtor {
		return o.s().fs
	}
	if o.nfs == 0 {
		return nil
	}
	return unsafe.Slice(o.field(0), o.nfs)
}

func (o *Obj) objExt() *objX {
	if o.kind <= kindCtor|hasX {
		Lean_internal_panic("object without a Go value")
	}
	return (*objX)(unsafe.Pointer(o))
}

func (o *Obj) ctorExt() *extSlot {
	if o.kind != kindCtor|hasX {
		Lean_internal_panic("object without a Go value")
	}
	return (*extSlot)(unsafe.Add(unsafe.Pointer(o), headerSize+uintptr(o.nfs)*fieldSize))
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
	if v.p.kind&^hasX == kindCtor {
		return uint64(v.p.tag)
	}
	switch v.p.kind &^ hasX {
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
	freeObj(v.p)
}

func freeObj(root *Obj) {
	var buf [16]*Obj
	stack := append(buf[:0], root)
	for len(stack) != 0 {
		i := len(stack) - 1
		o := stack[i]
		stack = stack[:i]
		kind := o.kindOf()
		if kind == kindPromise {
			resolveTask(o.s().fs[0], V{})
		}
		for _, f := range o.children() {
			if f.p != nil && f.p.rc > 0 {
				f.p.rc--
				if f.p.rc == 0 {
					stack = append(stack, f.p)
				}
			}
		}
		if kind == kindHandle {
			o.objExt().x.(*fileHandle).close()
		}
		o.rc = -1
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
		for _, f := range o.children() {
			if f.p != nil && f.p.rc > 0 {
				stack = append(stack, f.p)
			}
		}
	}
	return v
}

func allocCtor[A any](words int) *Obj {
	o := new(ctorN[A])
	o.nfs = uint16(words)
	return &o.Obj
}

func Lean_alloc_ctor(tag uint16, numObjs, scalarBytes int) V {
	words := numObjs + (scalarBytes+7)/8
	var p *Obj
	switch {
	case words == 0:
		p = &Obj{}
	case words <= 2:
		if words == 1 {
			p = allocCtor[[1]V](1)
		} else {
			p = allocCtor[[2]V](2)
		}
	case words <= 4:
		if words == 3 {
			p = allocCtor[[3]V](3)
		} else {
			p = allocCtor[[4]V](4)
		}
	default:
		p = allocLargeCtor(words)
	}
	p.rc = 1
	p.tag = uint8(tag)
	return V{p: p}
}

func allocLargeCtor(words int) *Obj {
	switch {
	case words <= 5:
		return allocCtor[[5]V](words)
	case words <= 6:
		return allocCtor[[6]V](words)
	case words <= 8:
		return allocCtor[[8]V](words)
	case words <= 12:
		return allocCtor[[12]V](words)
	case words <= 16:
		return allocCtor[[16]V](words)
	case words <= 24:
		return allocCtor[[24]V](words)
	case words <= 32:
		return allocCtor[[32]V](words)
	case words <= 64:
		return allocCtor[[64]V](words)
	case words <= 128:
		return allocCtor[[128]V](words)
	case words <= 256:
		return allocCtor[[256]V](words)
	case words <= 512:
		return allocCtor[[512]V](words)
	}
	Lean_internal_panic("constructor with more than 512 words")
	return nil
}

func ctor(tag uint16, fields ...V) V {
	v := Lean_alloc_ctor(tag, len(fields), 0)
	for i, f := range fields {
		*v.p.field(i) = f
	}
	return v
}

func Lean_ctor_get(v V, i int) V        { return *v.p.field(i) }
func Lean_ctor_set(v V, i int, value V) { *v.p.field(i) = value }
func Lean_ctor_set_tag(v V, tag uint16) { v.p.tag = uint8(tag) }

func Lean_ctor_release(v V, i int) {
	f := v.p.field(i)
	Lean_dec(*f)
	*f = V{}
}

func Lean_ctor_get_usize(v V, i int) uint64    { return v.p.field(i).n }
func Lean_ctor_set_usize(v V, i int, n uint64) { v.p.field(i).n = n }

func ctorBits(v V, offset int) uint64 {
	return v.p.field(offset/8).n >> (8 * (offset % 8))
}

func setCtorBits(v V, offset int, n, mask uint64) {
	f := &v.p.field(offset / 8).n
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

var hole = Obj{rc: -1}

func Hole() V { return V{p: &hole} }

func IsHole(v V) bool { return v.p == &hole }
