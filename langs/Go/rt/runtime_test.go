package rt

import (
	"sync"
	"sync/atomic"
	"testing"
)

func TestSharedUpdates(t *testing.T) {
	first := Lean_mk_string("é")
	old := Lean_array_push(Lean_mk_empty_array(), first)
	Lean_mark_persistent(old)
	last := Lean_string_push(Lean_array_uget(old, 0), '☃')
	updated := Lean_array_uset(old, 0, last)
	if got := String(Lean_array_uget_borrowed(old, 0)); got != "é" {
		t.Fatalf("source changed: %q", got)
	}
	if got := String(Lean_array_uget_borrowed(updated, 0)); got != "é☃" {
		t.Fatalf("updated element: %q", got)
	}
	if chars, bytes := Lean_string_length(last), Lean_string_utf8_byte_size(last); chars.n != 2 || bytes.n != 5 {
		t.Fatalf("updated lengths: %d characters, %d bytes", chars.n, bytes.n)
	}
	Lean_dec(updated)
	if last.p.rc != -1 || first.p.rc != 0 {
		t.Fatalf("updated refcount = %d, persistent refcount = %d", last.p.rc, first.p.rc)
	}
}

func TestCtorReuse(t *testing.T) {
	old := Lean_mk_string("old")
	obj := Lean_alloc_ctor(1, 1, 12)
	Lean_ctor_set(obj, 0, old)
	Lean_ctor_set_usize(obj, 1, 0xfedcba9876543210)
	Lean_ctor_set_uint16(obj, 18, 0xcafe)
	Lean_ctor_set_uint8(obj, 16, 0xff)

	reused := Reuse(Reset(obj, 1), 2, 1, 12, true)
	if reused.p != obj.p || Lean_obj_tag(reused) != 2 || old.p.rc != -1 {
		t.Fatal("reset and reuse did not release the field or reuse the allocation")
	}
	if n, u, b := Lean_ctor_get_usize(reused, 1), Lean_ctor_get_uint16(reused, 18), Lean_ctor_get_uint8(reused, 16); n != 0xfedcba9876543210 || u != 0xcafe || b != 0xff {
		t.Fatalf("scalar fields: %#x %#x %#x", n, u, b)
	}
	Lean_dec(reused)
}

func TestClosurePartialAndExtraArguments(t *testing.T) {
	add := func(_ *Tail, args []V) V { return Lean_box(args[0].n + args[1].n) }
	mk := func(_ *Tail, args []V) V { return Closure(add, 2, args[:1]) }
	f := Closure(mk, 2, nil)

	partial := Lean_apply(f, []V{Lean_box(9)})
	g := Lean_apply(partial, []V{Lean_box(2), Lean_box(3)})
	if g.n != 12 {
		t.Fatalf("over-applied closure = %d", g.n)
	}
}

func TestPersistentThunk(t *testing.T) {
	var calls atomic.Int32
	thunk := Lean_mark_persistent(Lean_mk_thunk(Closure(func(_ *Tail, _ []V) V {
		calls.Add(1)
		return Lean_mk_string("initialized")
	}, 1, nil)))

	var wg sync.WaitGroup
	for range 8 {
		wg.Go(func() {
			v := Lean_thunk_get_own(thunk)
			if got := String(v); got != "initialized" {
				t.Errorf("thunk returned %q", got)
			}
			Lean_dec(v)
		})
	}
	wg.Wait()
	if got := calls.Load(); got != 1 {
		t.Fatalf("thunk ran %d times", got)
	}
}

func TestPointerAddressesDistinguishWideScalars(t *testing.T) {
	wide := Lean_box(1 << 63)
	narrow := Lean_box(0)
	object := Lean_mk_string("object")
	a := Lean_ptr_addr(wide)
	if a == Lean_ptr_addr(narrow) || a == Lean_ptr_addr(object) || a != Lean_ptr_addr(wide) {
		t.Fatal("pointer addresses do not preserve distinct Lean values")
	}
}
