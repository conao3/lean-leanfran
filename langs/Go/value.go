package leanfran

import (
	"runtime"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

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
	region *Region
}

func (o *valueOwner) regionPtr() *unsafe.Pointer {
	return (*unsafe.Pointer)(unsafe.Pointer(&o.region))
}

func (o *valueOwner) loadRegion() *Region { return (*Region)(atomic.LoadPointer(o.regionPtr())) }

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
	mu    sync.Mutex
	track atomic.Bool
	leaks leakCounter
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
	used   int32
	active bool
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
		if len(inputs) == 0 {
			return ValueOperation{}
		}
		var region *Region
		for i := range inputs {
			if owner := inputs[i].owner; owner != nil {
				if r := owner.loadRegion(); r != nil {
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
	if op.region != nil {
		op.region.mu.Unlock()
	}
}

func (op ValueOperation) join(o *valueOwner) {
	if o == nil {
		return
	}
	r := o.loadRegion()
	if r == nil && atomic.CompareAndSwapPointer(o.regionPtr(), nil, unsafe.Pointer(op.region)) {
		return
	}
	if r == nil {
		r = o.loadRegion()
	}
	if r != op.region {
		panic(mixedRegions)
	}
}

func (o *valueOwner) clear() {
	o.raw = rt.Hole()
}

func (o *valueOwner) release() {
	if o != nil && !rt.IsHole(o.raw) {
		raw := o.raw
		o.clear()
		rt.Lean_dec(raw)
	}
}

func (o *valueOwner) check() {
	if o == nil || rt.IsHole(o.raw) {
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
	return v.owner.loadRegion()
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
	joining := false
	for i := range inputs {
		owner := inputs[i].owner
		if owner == nil {
			owner.check()
		}
		if r := owner.loadRegion(); r != op.region {
			if r != nil {
				panic(mixedRegions)
			}
			joining = true
		}
	}
	if joining {
		for i := range inputs {
			op.join(inputs[i].owner)
		}
	}
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

type leakCounter struct {
	leaked  atomic.Int64
	pending atomic.Int64
}

var (
	trackLeaks atomic.Bool
	allLeaks   leakCounter
)

func TrackLeakedValues(enabled bool) { trackLeaks.Store(enabled) }

func LeakedValues() int64 { return allLeaks.leaked.Load() }

func CollectLeakedValues() int64 { return allLeaks.collect() }

func (r *Region) TrackLeakedValues(enabled bool) { r.track.Store(enabled) }

func (r *Region) LeakedValues() int64 { return r.leaks.leaked.Load() }

func (r *Region) CollectLeakedValues() int64 { return r.leaks.collect() }

func (c *leakCounter) collect() int64 {
	previous := int64(-1)
	for range 100 {
		runtime.GC()
		time.Sleep(time.Millisecond)
		pending := c.pending.Load()
		if pending == previous {
			break
		}
		previous = pending
	}
	return c.leaked.Load()
}

func (c *leakCounter) watch(o *valueOwner) {
	c.pending.Add(1)
	runtime.SetFinalizer(o, func(o *valueOwner) {
		if !rt.IsHole(o.raw) {
			c.leaked.Add(1)
		}
		c.pending.Add(-1)
	})
}

func leakCounterOf(region *Region) *leakCounter {
	if trackLeaks.Load() {
		return &allLeaks
	}
	if region != nil && region.track.Load() {
		return &region.leaks
	}
	return nil
}

func newOwner(op ValueOperation, raw rt.V) *valueOwner {
	var owner *valueOwner
	switch counter := leakCounterOf(op.region); {
	case counter != nil:
		owner = &valueOwner{raw: raw, region: op.region}
		counter.watch(owner)
	case op.scope != nil && int(op.scope.used) < len(op.scope.slots):
		owner = &op.scope.slots[op.scope.used]
		op.scope.used++
		owner.raw, owner.region = raw, op.region
	default:
		owner = &valueOwner{raw: raw, region: op.region}
	}
	return owner
}

func WrapValue[T any](raw rt.V) Value[T] { return WrapValueIn[T](ValueOperation{}, raw) }

func WrapValueIn[T any](op ValueOperation, raw rt.V) Value[T] {
	return Value[T]{owner: newOwner(op, raw)}
}

func WrapFieldsIn[A, B any](op ValueOperation, pair rt.V) (Value[A], Value[B]) {
	a, b := OwnValueField(pair, 0), OwnValueField(pair, 1)
	if op.region == nil {
		op.region = &defaultRegion
	}
	if op.scope == nil && leakCounterOf(op.region) == nil {
		owners := &[2]valueOwner{{raw: a, region: op.region}, {raw: b, region: op.region}}
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
