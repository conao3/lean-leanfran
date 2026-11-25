package leanfran

import (
	"fmt"
	"math/big"
	"strings"
	"unicode/utf8"

	"github.com/conao3/leanfran-go/rt"
	"github.com/conao3/leanfran-go/schema"
)

type Issue struct {
	Message string
	Path    []any
}

type ValidationError struct {
	Issues []Issue
}

func (e *ValidationError) Error() string {
	if len(e.Issues) == 0 {
		return "validation failed"
	}
	issue := e.Issues[0]
	if len(issue.Path) == 0 {
		return issue.Message
	}
	segments := make([]string, len(issue.Path))
	for i, segment := range issue.Path {
		segments[i] = fmt.Sprint(segment)
	}
	return strings.Join(segments, ".") + ": " + issue.Message
}

type IOError struct {
	Message string
}

func (e *IOError) Error() string { return e.Message }

type ExceptError[E any] struct {
	Value E
}

func (e *ExceptError[E]) Error() string { return fmt.Sprint(e.Value) }

type Pair[A, B any] struct {
	Fst A
	Snd B
}

type Except[E, A any] struct {
	Error *E
	Ok    A
}

type Codec[T any] struct {
	Desc     *schema.Desc
	ToLean   func(T) rt.V
	FromLean func(rt.V) T
	Check    func(*ValidationError, T)
}

func (e *ValidationError) Add(message string, path ...any) {
	e.Issues = append(e.Issues, Issue{Message: message, Path: path})
}

func (e *ValidationError) Prefix(start int, path ...any) {
	for i := start; i < len(e.Issues); i++ {
		e.Issues[i].Path = append(append([]any(nil), path...), e.Issues[i].Path...)
	}
}

func (e *ValidationError) Err() error {
	if len(e.Issues) != 0 {
		return e
	}
	return nil
}

func CheckAt[T any](e *ValidationError, c Codec[T], value T, path ...any) {
	if c.Check != nil {
		start := len(e.Issues)
		c.Check(e, value)
		e.Prefix(start, path...)
	}
}

func Validate[T any](c Codec[T], value T, path ...any) error {
	var validation ValidationError
	CheckAt(&validation, c, value, path...)
	return validation.Err()
}

func Zero[T any]() (zero T) { return zero }

func Ref[T any](desc func() *schema.Desc, to func(T) rt.V, from func(rt.V) T, check func(*ValidationError, T)) Codec[T] {
	return Codec[T]{Desc: &schema.Desc{Kind: "ref", Ref: desc}, ToLean: to, FromLean: from, Check: check}
}

func Scalar[T any](kind string, bits int, to func(T) rt.V, from func(rt.V) T) Codec[T] {
	return Codec[T]{Desc: &schema.Desc{Kind: kind, Bits: bits}, ToLean: to, FromLean: from}
}

type fixed interface {
	~int | ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~int8 | ~int16 | ~int32 | ~int64
}

func Fixed[T fixed](kind string, bits int) Codec[T] {
	return Scalar(kind, bits, func(x T) rt.V { return rt.Lean_box(uint64(x)) }, func(v rt.V) T { return T(rt.Lean_unbox(v)) })
}

func Big(kind string, bound string) Codec[*big.Int] {
	to, from := rt.IntFromBig, rt.IntBig
	if kind != "int" {
		to, from = rt.NatFromBig, rt.NatBig
	}
	c := Scalar(kind, 0, to, from)
	c.Desc.Bound = bound
	var limit *big.Int
	if bound != "" {
		limit, _ = new(big.Int).SetString(bound, 10)
	}
	c.Check = func(e *ValidationError, x *big.Int) {
		if issue := IntegerIssue(x, kind != "int"); issue != "" {
			e.Add(issue)
		} else if limit != nil && x.Cmp(limit) >= 0 {
			e.Add("expected an integer less than " + bound)
		}
	}
	return c
}

func IntegerIssue(x *big.Int, nonnegative bool) string {
	switch {
	case x == nil:
		return "expected an integer"
	case nonnegative && x.Sign() < 0:
		return "expected a nonnegative integer"
	default:
		return ""
	}
}

func Fin(bound string) Codec[uint64] {
	c := Scalar("fin", 64, rt.NatFromUint64, rt.NatUint64)
	c.Desc.Bound = bound
	if limit, ok := new(big.Int).SetString(bound, 10); ok && limit.IsUint64() {
		n := limit.Uint64()
		c.Check = func(e *ValidationError, x uint64) {
			if x >= n {
				e.Add("expected an integer less than " + bound)
			}
		}
	}
	return c
}

func Bool() Codec[bool] {
	return Scalar("bool", 0, func(v bool) rt.V { return rt.Lean_box(uint64(rt.Bool(v))) }, func(v rt.V) bool { return rt.Lean_unbox(v) != 0 })
}

func String() Codec[string] {
	c := Scalar("string", 0, rt.Lean_mk_string, rt.String)
	c.Check = func(e *ValidationError, x string) {
		if !utf8.ValidString(x) {
			e.Add("expected valid UTF-8")
		}
	}
	return c
}

func Char() Codec[rune] {
	c := Fixed[rune]("char", 32)
	c.Check = func(e *ValidationError, x rune) {
		if !utf8.ValidRune(x) {
			e.Add("expected a Unicode scalar")
		}
	}
	return c
}

func Unit() Codec[struct{}] {
	return Scalar("unit", 0, func(struct{}) rt.V { return rt.V{} }, func(rt.V) struct{} { return struct{}{} })
}

func Option[T any](item Codec[T]) Codec[*T] {
	c := Scalar("option", 0, func(x *T) rt.V {
		if x == nil {
			return rt.V{}
		}
		return Ctor(1, item.ToLean(*x))
	}, func(v rt.V) *T {
		if rt.Lean_obj_tag(v) == 0 {
			return nil
		}
		x := item.FromLean(rt.Lean_ctor_get(v, 0))
		return &x
	})
	c.Desc.First = item.Desc
	if item.Check != nil {
		c.Check = func(e *ValidationError, x *T) {
			if x != nil {
				item.Check(e, *x)
			}
		}
	}
	return c
}

func Sequence[T any](kind string, item Codec[T]) Codec[[]T] {
	c := Scalar(kind, 0, func(x []T) rt.V {
		if kind == "list" {
			var list rt.V
			for i := len(x) - 1; i >= 0; i-- {
				list = Ctor(1, item.ToLean(x[i]), list)
			}
			return list
		}
		fields := make([]rt.V, len(x))
		for i, value := range x {
			fields[i] = item.ToLean(value)
		}
		return rt.Array(fields)
	}, func(v rt.V) []T {
		if kind == "list" {
			out := []T{}
			for rt.Lean_obj_tag(v) != 0 {
				out = append(out, item.FromLean(rt.Lean_ctor_get(v, 0)))
				v = rt.Lean_ctor_get(v, 1)
			}
			return out
		}
		out := make([]T, rt.Lean_array_size(v))
		for i := range out {
			out[i] = item.FromLean(rt.Lean_array_uget_borrowed(v, uint64(i)))
		}
		return out
	})
	c.Desc.First = item.Desc
	if item.Check != nil {
		c.Check = func(e *ValidationError, x []T) {
			for i, v := range x {
				start := len(e.Issues)
				item.Check(e, v)
				if len(e.Issues) != start {
					e.Prefix(start, i)
				}
			}
		}
	}
	return c
}

func Product[A, B any](a Codec[A], b Codec[B]) Codec[Pair[A, B]] {
	c := Scalar("prod", 0, func(x Pair[A, B]) rt.V {
		return Ctor(0, a.ToLean(x.Fst), b.ToLean(x.Snd))
	}, func(v rt.V) Pair[A, B] {
		return Pair[A, B]{Fst: a.FromLean(rt.Lean_ctor_get(v, 0)), Snd: b.FromLean(rt.Lean_ctor_get(v, 1))}
	})
	c.Desc.First, c.Desc.Second = a.Desc, b.Desc
	c.Check = func(e *ValidationError, x Pair[A, B]) {
		CheckAt(e, a, x.Fst, 0)
		CheckAt(e, b, x.Snd, 1)
	}
	return c
}

func Result[E, A any](e Codec[E], a Codec[A]) Codec[Except[E, A]] {
	c := Scalar("except", 0, func(x Except[E, A]) rt.V {
		if x.Error != nil {
			return Ctor(0, e.ToLean(*x.Error))
		}
		return Ctor(1, a.ToLean(x.Ok))
	}, func(v rt.V) Except[E, A] {
		item := rt.Lean_ctor_get(v, 0)
		if rt.Lean_obj_tag(v) == 0 {
			err := e.FromLean(item)
			return Except[E, A]{Error: &err}
		}
		return Except[E, A]{Ok: a.FromLean(item)}
	})
	c.Desc.First, c.Desc.Second = e.Desc, a.Desc
	c.Check = func(err *ValidationError, x Except[E, A]) {
		if x.Error != nil {
			CheckAt(err, e, *x.Error, "error")
		} else {
			CheckAt(err, a, x.Ok, "ok")
		}
	}
	return c
}

func Ctor(tag uint16, values ...rt.V) rt.V {
	out := rt.Lean_alloc_ctor(tag, len(values), 0)
	for i, v := range values {
		rt.Lean_ctor_set(out, i, v)
	}
	return out
}

func ReadIO(result rt.V) (rt.V, error) {
	if rt.Lean_io_result_is_ok(result) {
		return rt.Lean_io_result_take_value(result), nil
	}
	defer rt.Lean_dec(result)
	rt.Lean_inc(rt.Lean_io_result_get_error(result))
	message := rt.Lean_io_error_to_string(rt.Lean_io_result_get_error(result))
	defer rt.Lean_dec(message)
	return rt.V{}, &IOError{Message: rt.String(message)}
}
