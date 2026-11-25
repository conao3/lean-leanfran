package rt

import (
	"bytes"
	"strconv"
	"unicode/utf8"
)

type leanString struct {
	data  []byte
	count int
}

func makeString(data []byte, count int) V {
	return V{p: newObjX(kindString, nil, &leanString{data, count})}
}

func Lean_mk_string(s string) V { return makeString([]byte(s), utf8.RuneCountInString(s)) }

func stringData(v V) *leanString { return v.p.ext().x.(*leanString) }

func String(v V) string { return string(stringData(v).data) }

func exclusiveString(v V) V {
	if Lean_is_exclusive(v) {
		return v
	}
	s := stringData(v)
	copy := makeString(bytes.Clone(s.data), s.count)
	Lean_dec(v)
	return copy
}

func Lean_string_append(a, b V) V {
	a = exclusiveString(a)
	as, bs := stringData(a), stringData(b)
	as.data = append(as.data, bs.data...)
	as.count += bs.count
	return a
}

func Lean_string_push(v V, c uint32) V {
	v = exclusiveString(v)
	s := stringData(v)
	s.data = utf8.AppendRune(s.data, rune(c))
	s.count++
	return v
}

func Lean_string_length(v V) V         { return Lean_box(uint64(stringData(v).count)) }
func Lean_string_len(v V) uint64       { return uint64(stringData(v).count) }
func Lean_string_size(v V) uint64      { return uint64(len(stringData(v).data)) + 1 }
func Lean_string_utf8_byte_size(v V) V { return Lean_box(Lean_string_size(v) - 1) }

func Lean_string_mk(list V) V {
	data := make([]byte, 0)
	count := 0
	for l := list; l.p != nil; l = Lean_ctor_get(l, 1) {
		data = utf8.AppendRune(data, rune(Lean_unbox(Lean_ctor_get(l, 0))))
		count++
	}
	Lean_dec(list)
	return makeString(data, count)
}

func Lean_string_data(v V) V {
	data := stringData(v).data
	var list V
	for len(data) > 0 {
		c, size := utf8.DecodeLastRune(data)
		list = ctor(1, Lean_box(uint64(c)), list)
		data = data[:len(data)-size]
	}
	Lean_dec(v)
	return list
}

func Lean_string_dec_eq(a, b V) uint8 {
	return Bool(a.p == b.p || bytes.Equal(stringData(a).data, stringData(b).data))
}

func Lean_string_dec_lt(a, b V) uint8 {
	return Bool(bytes.Compare(stringData(a).data, stringData(b).data) < 0)
}

func Lean_string_compare(a, b V) uint8 {
	return uint8(bytes.Compare(stringData(a).data, stringData(b).data) + 1)
}

func Lean_string_is_valid_pos(v, i V) uint8 {
	data := stringData(v).data
	return Bool(i.p == nil && (i.n == uint64(len(data)) || i.n < uint64(len(data)) && utf8.RuneStart(data[i.n])))
}

func Lean_string_utf8_at_end(v, i V) uint8 {
	return Bool(i.p != nil || i.n >= uint64(len(stringData(v).data)))
}

func runeAt(v, i V) (rune, int) {
	data := stringData(v).data
	if i.p != nil || i.n >= uint64(len(data)) || !utf8.RuneStart(data[i.n]) {
		return 'A', 0
	}
	return utf8.DecodeRune(data[i.n:])
}

func Lean_string_utf8_get(v, i V) uint32 {
	r, _ := runeAt(v, i)
	return uint32(r)
}

func Lean_string_utf8_get_fast(v, i V) uint32 { return Lean_string_utf8_get(v, i) }

func Lean_string_utf8_get_opt(v, i V) V {
	r, size := runeAt(v, i)
	if size == 0 {
		return V{}
	}
	return ctor(1, Lean_box(uint64(r)))
}

func Lean_string_utf8_get_bang(v, i V) uint32 {
	r, size := runeAt(v, i)
	if size == 0 {
		Lean_panic_fn(V{}, Lean_mk_string("Error: invalid `String.Pos` at `String.get!`"))
	}
	return uint32(r)
}

func Lean_string_uget_byte_fast(v V, i uint64) uint8 {
	s := stringData(v).data
	if i == uint64(len(s)) {
		return 0
	}
	return s[i]
}

func Lean_string_get_byte_fast(v, i V) uint8 { return Lean_string_uget_byte_fast(v, i.n) }

func Lean_string_utf8_next(v, i V) V {
	_, size := runeAt(v, i)
	return Lean_nat_add(i, Lean_box(uint64(max(1, size))))
}

func Lean_string_utf8_next_fast(v, i V) V { return Lean_string_utf8_next(v, i) }

func Lean_string_utf8_prev(v, i V) V {
	data := stringData(v).data
	if i.p != nil || i.n > uint64(len(data)) {
		return Lean_nat_sub(i, Lean_box(1))
	}
	j := i.n
	for j > 0 {
		j--
		if utf8.RuneStart(data[j]) {
			break
		}
	}
	return Lean_box(j)
}

func Lean_string_utf8_extract(v, start, end V) V {
	if Lean_string_is_valid_pos(v, start) == 0 {
		return Lean_mk_string("")
	}
	data := stringData(v).data
	if Lean_string_is_valid_pos(v, end) == 0 {
		end = Lean_box(uint64(len(data)))
	}
	if end.n <= start.n {
		return Lean_mk_string("")
	}
	return Lean_mk_string(string(data[start.n:end.n]))
}

func Lean_string_utf8_extract_fast(v, start, end V) V {
	return Lean_string_utf8_extract(v, start, end)
}

func Lean_string_utf8_set(v, i V, c uint32) V {
	_, size := runeAt(v, i)
	if size == 0 {
		return v
	}
	v = exclusiveString(v)
	s := stringData(v)
	var buf [utf8.UTFMax]byte
	n := utf8.EncodeRune(buf[:], rune(c))
	if n == size {
		copy(s.data[i.n:], buf[:n])
	} else {
		tail := bytes.Clone(s.data[i.n+uint64(size):])
		s.data = append(s.data[:i.n], buf[:n]...)
		s.data = append(s.data, tail...)
	}
	return v
}

func Lean_string_of_usize(n uint64) V { return Lean_mk_string(strconv.FormatUint(n, 10)) }

func Lean_string_to_utf8(v V) V {
	return byteArray(bytes.Clone(stringData(v).data))
}

func Lean_string_validate_utf8(v V) uint8 { return Bool(utf8.Valid(byteData(v).values)) }

func Lean_string_from_utf8_unchecked(v V) V {
	s := Lean_mk_string(string(byteData(v).values))
	Lean_dec(v)
	return s
}
