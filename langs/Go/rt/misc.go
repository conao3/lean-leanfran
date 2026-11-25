package rt

import (
	"bytes"
	"encoding/binary"
	"slices"
	"sync"
	"sync/atomic"
	"unsafe"
)

func Lean_inc_ret(v V) V { return own(v) }

func Lean_reset(v V, count int) V { return Reset(v, count) }

func Lean_reuse(v V, tag uint16, numObjs, scalarBytes int, updateTag bool) V {
	return Reuse(v, tag, numObjs, scalarBytes, updateTag)
}

func Lean_trampoline(fn func(*Tail, []V) V, args []V) V { return Run(fn, args) }

func Lean_void_mk(v V) V {
	Lean_dec(v)
	return V{}
}

var scalarAddresses struct {
	sync.Mutex
	cells map[uint64]*uint64
}

func Lean_ptr_addr(v V) uint64 {
	if v.p != nil {
		return uint64(uintptr(unsafe.Pointer(v.p)))
	}
	if v.n < 1<<63 {
		return v.n<<1 | 1
	}
	scalarAddresses.Lock()
	defer scalarAddresses.Unlock()
	if scalarAddresses.cells == nil {
		scalarAddresses.cells = make(map[uint64]*uint64)
	}
	cell := scalarAddresses.cells[v.n]
	if cell == nil {
		cell = new(uint64)
		scalarAddresses.cells[v.n] = cell
	}
	return uint64(uintptr(unsafe.Pointer(cell)))
}

func Lean_array_propagate_mark(_, dst V) V { return dst }

func Lean_dbg_trace_if_shared(message, v V) V {
	if v.p != nil && !Lean_is_exclusive(v) {
		writeDebugTrace(Lean_mk_string("shared RC " + cString(message)))
	}
	return v
}

func Lean_string_lt(a, b V) uint8 { return Lean_string_dec_lt(a, b) }

func Lean_string_memcmp(a, b, left, right, length V) uint8 {
	if length.n == 0 && length.p == nil {
		return 1
	}
	x, y := stringData(a).data, stringData(b).data
	if left.p != nil || right.p != nil || length.p != nil ||
		left.n > uint64(len(x)) || right.n > uint64(len(y)) ||
		length.n > uint64(len(x))-left.n || length.n > uint64(len(y))-right.n {
		Lean_internal_panic("String comparison exceeds the available byte range")
	}
	return Bool(bytes.Equal(x[left.n:left.n+length.n], y[right.n:right.n+length.n]))
}

func hashBytes(data []byte) uint64 {
	const multiplier uint64 = 0xc6a4a7935bd1e995
	hash := 11 ^ uint64(len(data))*multiplier
	for len(data) >= 8 {
		word := binary.LittleEndian.Uint64(data) * multiplier
		hash = (hash ^ (word^word>>47)*multiplier) * multiplier
		data = data[8:]
	}
	if len(data) > 0 {
		var tail [8]byte
		copy(tail[:], data)
		hash = (hash ^ binary.LittleEndian.Uint64(tail[:])) * multiplier
	}
	hash = (hash ^ hash>>47) * multiplier
	return hash ^ hash>>47
}

func Lean_string_hash(v V) uint64     { return hashBytes(stringData(v).data) }
func Lean_byte_array_hash(v V) uint64 { return hashBytes(byteData(v).values) }

func Lean_byte_array_copy_slice(src, srcOff, dst, dstOff, length V, exact uint8) V {
	source := byteData(src).values
	start := natAtMost(srcOff, len(source)+1)
	count := natAtMost(length, max(0, len(source)-start))
	dstIndex := natAtMost(dstOff, len(byteData(dst).values))
	Lean_dec(srcOff)
	Lean_dec(dstOff)
	Lean_dec(length)
	if count == 0 {
		return dst
	}
	dst = exclusiveBytes(dst)
	data := byteData(dst)
	if extra := dstIndex + count - len(data.values); extra > 0 {
		if exact != 0 && cap(data.values)-len(data.values) < extra {
			sized := make([]byte, len(data.values), len(data.values)+extra)
			copy(sized, data.values)
			data.values = sized
		}
		data.values = slices.Grow(data.values, extra)
		data.values = data.values[:len(data.values)+extra]
	}
	copy(data.values[dstIndex:], source[start:start+count])
	return dst
}

func natAtMost(v V, limit int) int {
	if v.p != nil || v.n > uint64(limit) {
		return limit
	}
	return int(v.n)
}

var initializing atomic.Bool

func SetInitializing(value bool) { initializing.Store(value) }

func Lean_io_initializing() uint8 {
	return Bool(initializing.Load())
}

func Lean_name_eq(a, b V) uint8 {
	for a != b {
		if a.p == nil || b.p == nil || a.p.tag != b.p.tag {
			return 0
		}
		x, y := Lean_ctor_get(a, 1), Lean_ctor_get(b, 1)
		if a.p.tag == 1 {
			if Lean_string_dec_eq(x, y) == 0 {
				return 0
			}
		} else if Lean_nat_dec_eq(x, y) == 0 {
			return 0
		}
		a, b = Lean_ctor_get(a, 0), Lean_ctor_get(b, 0)
	}
	return 1
}
