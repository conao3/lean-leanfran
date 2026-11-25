package rt

import (
	"bytes"
	"math"
	"slices"
)

type scalarArray[T byte | float64] struct {
	values []T
}

func byteArray(values []byte) V {
	return V{p: newObjX(kindByteArray, nil, &scalarArray[byte]{values})}
}

func floatArray(values []float64) V {
	return V{p: newObjX(kindFloatArray, nil, &scalarArray[float64]{values})}
}

func byteData(v V) *scalarArray[byte]     { return v.p.objExt().x.(*scalarArray[byte]) }
func floatData(v V) *scalarArray[float64] { return v.p.objExt().x.(*scalarArray[float64]) }

func Lean_sarray_size(v V) uint64 {
	if v.p.kindOf() == kindByteArray {
		return uint64(len(byteData(v).values))
	}
	return uint64(len(floatData(v).values))
}

func Lean_sarray_dec_eq(a, b V) uint8 {
	if a.p == b.p {
		return 1
	}
	if a.p.kindOf() == kindByteArray {
		return Bool(bytes.Equal(byteData(a).values, byteData(b).values))
	}
	return Bool(slices.EqualFunc(floatData(a).values, floatData(b).values, func(a, b float64) bool {
		return math.Float64bits(a) == math.Float64bits(b)
	}))
}

func arrayCapacity(n V) int {
	if n.p != nil || n.n > uint64(int(^uint(0)>>1)) {
		Lean_internal_panic("out of memory")
	}
	return int(n.n)
}

func Lean_mk_empty_byte_array(capacity V) V {
	return byteArray(make([]byte, 0, arrayCapacity(capacity)))
}

func Lean_byte_array_mk(a V) V {
	values := make([]byte, len(a.p.s().fs))
	for i, v := range a.p.s().fs {
		values[i] = byte(v.n)
	}
	Lean_dec(a)
	return byteArray(values)
}

func Lean_byte_array_data(a V) V {
	data := byteData(a).values
	fields := make([]V, len(data))
	for i, b := range data {
		fields[i] = Lean_box(uint64(b))
	}
	Lean_dec(a)
	return array(fields)
}

func Lean_byte_array_size(a V) V               { return Lean_box(uint64(len(byteData(a).values))) }
func Lean_byte_array_uget(a V, i uint64) uint8 { return byteData(a).values[i] }
func Lean_byte_array_fget(a, i V) uint8        { return Lean_byte_array_uget(a, i.n) }

func Lean_byte_array_get(a, i V) uint8 {
	if i.p == nil && i.n < Lean_sarray_size(a) {
		return Lean_byte_array_uget(a, i.n)
	}
	return 0
}

func exclusiveBytes(a V) V {
	if Lean_is_exclusive(a) {
		return a
	}
	copy := byteArray(bytes.Clone(byteData(a).values))
	Lean_dec(a)
	return copy
}

func Lean_byte_array_push(a V, b uint8) V {
	a = exclusiveBytes(a)
	data := byteData(a)
	data.values = append(data.values, b)
	return a
}

func Lean_byte_array_uset(a V, i uint64, b uint8) V {
	a = exclusiveBytes(a)
	byteData(a).values[i] = b
	return a
}

func Lean_byte_array_fset(a, i V, b uint8) V { return Lean_byte_array_uset(a, i.n, b) }

func Lean_byte_array_set(a, i V, b uint8) V {
	if i.p == nil && i.n < Lean_sarray_size(a) {
		return Lean_byte_array_uset(a, i.n, b)
	}
	return a
}

func Lean_mk_empty_float_array(capacity V) V {
	return floatArray(make([]float64, 0, arrayCapacity(capacity)))
}

func Lean_float_array_mk(a V) V {
	values := make([]float64, len(a.p.s().fs))
	for i, v := range a.p.s().fs {
		values[i] = math.Float64frombits(v.n)
	}
	Lean_dec(a)
	return floatArray(values)
}

func Lean_float_array_data(a V) V {
	data := floatData(a).values
	fields := make([]V, len(data))
	for i, f := range data {
		fields[i] = Lean_box(math.Float64bits(f))
	}
	Lean_dec(a)
	return array(fields)
}

func Lean_float_array_size(a V) V                 { return Lean_box(uint64(len(floatData(a).values))) }
func Lean_float_array_uget(a V, i uint64) float64 { return floatData(a).values[i] }
func Lean_float_array_fget(a, i V) float64        { return Lean_float_array_uget(a, i.n) }

func Lean_float_array_get(a, i V) float64 {
	if i.p == nil && i.n < Lean_sarray_size(a) {
		return Lean_float_array_uget(a, i.n)
	}
	return 0
}

func exclusiveFloats(a V) V {
	if Lean_is_exclusive(a) {
		return a
	}
	copy := floatArray(slices.Clone(floatData(a).values))
	Lean_dec(a)
	return copy
}

func Lean_float_array_push(a V, f float64) V {
	a = exclusiveFloats(a)
	data := floatData(a)
	data.values = append(data.values, f)
	return a
}

func Lean_float_array_uset(a V, i uint64, f float64) V {
	a = exclusiveFloats(a)
	floatData(a).values[i] = f
	return a
}

func Lean_float_array_fset(a, i V, f float64) V { return Lean_float_array_uset(a, i.n, f) }

func Lean_float_array_set(a, i V, f float64) V {
	if i.p == nil && i.n < Lean_sarray_size(a) {
		return Lean_float_array_uset(a, i.n, f)
	}
	return a
}

func BytesFromSlice(values []byte) V { return byteArray(append([]byte(nil), values...)) }
func Bytes(v V) []byte               { return append([]byte{}, byteData(v).values...) }
