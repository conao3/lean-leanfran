package leanfran

import (
	"runtime"
	"sync"
	"sync/atomic"

	"github.com/conao3/leanfran-go/rt"
)

type (
	NatType              struct{}
	IntType              struct{}
	CharType             struct{}
	USizeType            struct{}
	ISizeType            struct{}
	ListType[T any]      struct{ _ [0]func(T) }
	ArrayType[T any]     struct{ _ [0]func(T) }
	OptionType[T any]    struct{ _ [0]func(T) }
	PairType[A, B any]   struct{ _ [0]func(A, B) }
	ExceptType[E, A any] struct{ _ [0]func(E, A) }
	FinType[N any]       struct{ _ [0]func(N) }
)

type Value[T any] struct {
	_     [0]func(T)
	owner *valueOwner
}

type valueOwner struct {
	raw   rt.V
	valid bool
}

type ValueInput[T any] struct {
	value Value[T]
	take  bool
}

type ValueUse struct {
	owner *valueOwner
	raw   rt.V
	take  bool
}

var valueMu sync.Mutex

func LockValues() { valueMu.Lock() }

func UnlockValues() { valueMu.Unlock() }

type ValueScope struct {
	state *valueScopeState
}

type valueScopeState struct {
	scope  ValueScope
	mu     sync.Mutex
	active bool
	used   int
	slots  [8]valueOwner
}

func WithValues(f func(*ValueScope)) {
	LockValues()
	defer UnlockValues()
	state := &valueScopeState{active: true}
	state.scope.state = state
	defer state.finish()
	f(&state.scope)
}

func (s *valueScopeState) finish() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.active = false
}

func BeginValueOperation(scope *ValueScope) {
	if scope == nil {
		LockValues()
		return
	}
	state := scope.state
	if state == nil {
		panic("leanfran: inactive ValueScope")
	}
	state.mu.Lock()
	if !state.active {
		state.mu.Unlock()
		panic("leanfran: inactive ValueScope")
	}
}

func EndValueOperation(scope *ValueScope) {
	if scope == nil {
		UnlockValues()
		return
	}
	scope.state.mu.Unlock()
}

func (o *valueOwner) clear() {
	o.raw = rt.V{}
	o.valid = false
}

func (o *valueOwner) release() {
	if o != nil && o.valid {
		raw := o.raw
		o.clear()
		rt.Lean_dec(raw)
	}
}

func (o *valueOwner) check() {
	if o == nil || !o.valid {
		panic("leanfran: empty Value")
	}
}

func (v Value[T]) Close() { v.CloseIn(nil) }

func (v Value[T]) CloseIn(scope *ValueScope) {
	BeginValueOperation(scope)
	defer EndValueOperation(scope)
	v.owner.release()
}

func (v Value[T]) IsExclusive() bool { return v.IsExclusiveIn(nil) }

func (v Value[T]) IsExclusiveIn(scope *ValueScope) bool {
	BeginValueOperation(scope)
	defer EndValueOperation(scope)
	v.owner.check()
	return rt.Lean_is_exclusive(v.owner.raw)
}

func (v Value[T]) Borrow() ValueInput[T] { return ValueInput[T]{value: v} }

func (v Value[T]) Take() ValueInput[T] { return ValueInput[T]{value: v, take: true} }

func (v ValueInput[T]) Use() ValueUse { return ValueUse{owner: v.value.owner, take: v.take} }

func (u ValueUse) Lean() rt.V { return u.raw }

func AcquireValueInputs(inputs []ValueUse) {
	for i, input := range inputs {
		input.owner.check()
		if input.take {
			for _, previous := range inputs[:i] {
				if previous.take && previous.owner == input.owner {
					panic("leanfran: Value taken twice in one call")
				}
			}
		}
	}
	for i := range inputs {
		input := &inputs[i]
		input.raw = input.owner.raw
		if !input.take {
			rt.Lean_inc(input.raw)
		}
	}
	for _, input := range inputs {
		if input.take {
			input.owner.clear()
		}
	}
}

var (
	trackLeaks   atomic.Bool
	leakedValues atomic.Int64
)

func TrackLeakedValues(enabled bool) { trackLeaks.Store(enabled) }

func LeakedValues() int64 { return leakedValues.Load() }

func countLeakedValue(o *valueOwner) {
	if o.valid {
		leakedValues.Add(1)
	}
}

func newOwner(scope *ValueScope, raw rt.V) *valueOwner {
	if trackLeaks.Load() {
		owner := &valueOwner{raw: raw, valid: true}
		runtime.SetFinalizer(owner, countLeakedValue)
		return owner
	}
	if scope != nil {
		state := scope.state
		if state.used < len(state.slots) {
			owner := &state.slots[state.used]
			state.used++
			owner.raw, owner.valid = raw, true
			return owner
		}
	}
	return &valueOwner{raw: raw, valid: true}
}

func WrapValue[T any](raw rt.V) Value[T] { return WrapValueIn[T](nil, raw) }

func WrapValueIn[T any](scope *ValueScope, raw rt.V) Value[T] {
	return Value[T]{owner: newOwner(scope, raw)}
}

func WrapFieldsIn[A, B any](scope *ValueScope, pair rt.V) (Value[A], Value[B]) {
	a, b := OwnValueField(pair, 0), OwnValueField(pair, 1)
	if scope == nil && !trackLeaks.Load() {
		owners := &[2]valueOwner{{raw: a, valid: true}, {raw: b, valid: true}}
		return Value[A]{owner: &owners[0]}, Value[B]{owner: &owners[1]}
	}
	return Value[A]{owner: newOwner(scope, a)}, Value[B]{owner: newOwner(scope, b)}
}

func NewValue[T, G any](codec Codec[G], v G, path string) (Value[T], error) {
	return newValue[T](nil, codec, v, path)
}

func NewValueIn[T, G any](scope *ValueScope, codec Codec[G], v G, path string) (Value[T], error) {
	if scope == nil {
		return NewValue[T](codec, v, path)
	}
	BeginValueOperation(scope)
	defer EndValueOperation(scope)
	return newValue[T](scope, codec, v, path)
}

func NewUncheckedValueIn[T, G any](scope *ValueScope, codec Codec[G], v G) Value[T] {
	if scope != nil {
		BeginValueOperation(scope)
		defer EndValueOperation(scope)
	}
	return WrapValueIn[T](scope, codec.ToLean(v))
}

var validations = sync.Pool{New: func() any { return new(ValidationError) }}

func newValue[T, G any](scope *ValueScope, codec Codec[G], v G, path string) (Value[T], error) {
	if codec.Check != nil {
		validation := validations.Get().(*ValidationError)
		codec.Check(validation, v)
		if len(validation.Issues) != 0 {
			failed := &ValidationError{Issues: validation.Issues}
			failed.Prefix(0, path)
			validation.Issues = nil
			validations.Put(validation)
			return Value[T]{}, failed
		}
		validations.Put(validation)
	}
	return WrapValueIn[T](scope, codec.ToLean(v)), nil
}

func ReadValue[T, G any](codec Codec[G], v Value[T]) G { return ReadValueIn(nil, codec, v) }

func ReadValueIn[T, G any](scope *ValueScope, codec Codec[G], v Value[T]) G {
	BeginValueOperation(scope)
	defer EndValueOperation(scope)
	v.owner.check()
	return codec.FromLean(v.owner.raw)
}

func OwnValueField(v rt.V, i int) rt.V {
	field := rt.Lean_ctor_get(v, i)
	rt.Lean_inc(field)
	return field
}

func SplitValue[A, B any](v ValueInput[PairType[A, B]]) (Value[A], Value[B]) {
	return SplitValueIn(nil, v)
}

func SplitValueIn[A, B any](scope *ValueScope, v ValueInput[PairType[A, B]]) (Value[A], Value[B]) {
	BeginValueOperation(scope)
	defer EndValueOperation(scope)
	inputs := [1]ValueUse{v.Use()}
	AcquireValueInputs(inputs[:])
	raw := inputs[0].Lean()
	defer rt.Lean_dec(raw)
	return WrapFieldsIn[A, B](scope, raw)
}
