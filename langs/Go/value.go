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
	raw    rt.V
	valid  bool
	region atomic.Pointer[Region]
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

type Region struct {
	mu sync.Mutex
}

var defaultRegion Region

func NewRegion() *Region { return new(Region) }

type ValueScope struct {
	state *valueScopeState
}

type valueScopeState struct {
	scope  ValueScope
	region *Region
	mu     sync.Mutex
	active bool
	used   int
	slots  [8]valueOwner
}

func WithValues(f func(*ValueScope)) { defaultRegion.WithValues(f) }

func (r *Region) WithValues(f func(*ValueScope)) {
	r.mu.Lock()
	defer r.mu.Unlock()
	state := &valueScopeState{region: r, active: true}
	state.scope.state = state
	defer state.finish()
	f(&state.scope)
}

func (s *valueScopeState) finish() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.active = false
}

type ValueOperation struct {
	region *Region
	scope  *valueScopeState
}

const mixedRegions = "leanfran: Values from different Regions in one call"

func BeginValueOperation(scope *ValueScope, inputs []ValueUse) ValueOperation {
	if scope == nil {
		var region *Region
		for i := range inputs {
			if owner := inputs[i].owner; owner != nil {
				if r := owner.region.Load(); r != nil {
					if region == nil {
						region = r
					} else if r != region {
						panic(mixedRegions)
					}
				}
			}
		}
		if region == nil {
			region = &defaultRegion
		}
		region.mu.Lock()
		return ValueOperation{region: region}
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
	return ValueOperation{region: state.region, scope: state}
}

func (op ValueOperation) End() {
	if op.scope != nil {
		op.scope.mu.Unlock()
		return
	}
	op.region.mu.Unlock()
}

func (op ValueOperation) join(o *valueOwner) {
	if o == nil {
		return
	}
	r := o.region.Load()
	if r == nil && o.region.CompareAndSwap(nil, op.region) {
		return
	}
	if r == nil {
		r = o.region.Load()
	}
	if r != op.region {
		panic(mixedRegions)
	}
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
	op := v.begin(scope)
	defer op.End()
	op.join(v.owner)
	v.owner.release()
}

func (v Value[T]) begin(scope *ValueScope) ValueOperation {
	inputs := [1]ValueUse{{owner: v.owner}}
	return BeginValueOperation(scope, inputs[:])
}

func (v Value[T]) Region() *Region {
	if v.owner == nil {
		return nil
	}
	return v.owner.region.Load()
}

func (v Value[T]) IsExclusive() bool { return v.IsExclusiveIn(nil) }

func (v Value[T]) IsExclusiveIn(scope *ValueScope) bool {
	op := v.begin(scope)
	defer op.End()
	op.join(v.owner)
	v.owner.check()
	return rt.Lean_is_exclusive(v.owner.raw)
}

func (v Value[T]) Borrow() ValueInput[T] { return ValueInput[T]{value: v} }

func (v Value[T]) Take() ValueInput[T] { return ValueInput[T]{value: v, take: true} }

func (v ValueInput[T]) Use() ValueUse { return ValueUse{owner: v.value.owner, take: v.take} }

func (u ValueUse) Lean() rt.V { return u.raw }

func (op ValueOperation) Acquire(inputs []ValueUse) {
	for i, input := range inputs {
		op.join(input.owner)
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

func newOwner(op ValueOperation, raw rt.V) *valueOwner {
	var owner *valueOwner
	switch {
	case trackLeaks.Load():
		owner = &valueOwner{raw: raw, valid: true}
		runtime.SetFinalizer(owner, countLeakedValue)
	case op.scope != nil && op.scope.used < len(op.scope.slots):
		owner = &op.scope.slots[op.scope.used]
		op.scope.used++
		owner.raw, owner.valid = raw, true
	default:
		owner = &valueOwner{raw: raw, valid: true}
	}
	if op.region != nil {
		owner.region.Store(op.region)
	}
	return owner
}

func WrapValue[T any](raw rt.V) Value[T] { return WrapValueIn[T](ValueOperation{}, raw) }

func WrapValueIn[T any](op ValueOperation, raw rt.V) Value[T] {
	return Value[T]{owner: newOwner(op, raw)}
}

func WrapFieldsIn[A, B any](op ValueOperation, pair rt.V) (Value[A], Value[B]) {
	a, b := OwnValueField(pair, 0), OwnValueField(pair, 1)
	if op.scope == nil && !trackLeaks.Load() {
		owners := &[2]valueOwner{{raw: a, valid: true}, {raw: b, valid: true}}
		owners[0].region.Store(op.region)
		owners[1].region.Store(op.region)
		return Value[A]{owner: &owners[0]}, Value[B]{owner: &owners[1]}
	}
	return Value[A]{owner: newOwner(op, a)}, Value[B]{owner: newOwner(op, b)}
}

func NewValue[T, G any](codec Codec[G], v G, path string) (Value[T], error) {
	return newValue[T](ValueOperation{}, codec, v, path)
}

func NewValueIn[T, G any](scope *ValueScope, codec Codec[G], v G, path string) (Value[T], error) {
	if scope == nil {
		return NewValue[T](codec, v, path)
	}
	op := BeginValueOperation(scope, nil)
	defer op.End()
	return newValue[T](op, codec, v, path)
}

func NewUncheckedValueIn[T, G any](scope *ValueScope, codec Codec[G], v G) Value[T] {
	if scope == nil {
		return WrapValue[T](codec.ToLean(v))
	}
	op := BeginValueOperation(scope, nil)
	defer op.End()
	return WrapValueIn[T](op, codec.ToLean(v))
}

var validations = sync.Pool{New: func() any { return new(ValidationError) }}

func newValue[T, G any](op ValueOperation, codec Codec[G], v G, path string) (Value[T], error) {
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
	return WrapValueIn[T](op, codec.ToLean(v)), nil
}

func ReadValue[T, G any](codec Codec[G], v Value[T]) G { return ReadValueIn(nil, codec, v) }

func ReadValueIn[T, G any](scope *ValueScope, codec Codec[G], v Value[T]) G {
	op := v.begin(scope)
	defer op.End()
	op.join(v.owner)
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
	inputs := [1]ValueUse{v.Use()}
	op := BeginValueOperation(scope, inputs[:])
	defer op.End()
	op.Acquire(inputs[:])
	raw := inputs[0].Lean()
	defer rt.Lean_dec(raw)
	return WrapFieldsIn[A, B](op, raw)
}
