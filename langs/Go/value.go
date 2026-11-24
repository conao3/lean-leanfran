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
	valid atomic.Bool
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

func (o *valueOwner) clear() {
	o.raw = rt.V{}
	o.valid.Store(false)
}

func (o *valueOwner) release() {
	if o != nil && o.valid.Load() {
		raw := o.raw
		o.clear()
		rt.Lean_dec(raw)
	}
}

func (o *valueOwner) check() {
	if o == nil || !o.valid.Load() {
		panic("leanfran: empty Value")
	}
}

func (v Value[T]) Close() {
	LockValues()
	defer UnlockValues()
	v.owner.release()
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

func releaseFinalizedValue(o *valueOwner) {
	if !o.valid.Load() {
		return
	}
	LockValues()
	defer UnlockValues()
	o.release()
}

func WrapValue[T any](raw rt.V) Value[T] {
	owner := &valueOwner{raw: raw}
	owner.valid.Store(true)
	if !rt.Lean_is_scalar(raw) {
		runtime.SetFinalizer(owner, releaseFinalizedValue)
	}
	return Value[T]{owner: owner}
}

func NewValue[T, G any](codec Codec[G], v G, path string) (Value[T], error) {
	if codec.Check != nil {
		var validation ValidationError
		codec.Check(&validation, v)
		if len(validation.Issues) != 0 {
			validation.Prefix(0, path)
			return Value[T]{}, &validation
		}
	}
	return WrapValue[T](codec.ToLean(v)), nil
}

func ReadValue[T, G any](codec Codec[G], v Value[T]) G {
	LockValues()
	defer UnlockValues()
	v.owner.check()
	return codec.FromLean(v.owner.raw)
}

func OwnValueField(v rt.V, i int) rt.V {
	field := rt.Lean_ctor_get(v, i)
	rt.Lean_inc(field)
	return field
}

func SplitValue[A, B any](v ValueInput[PairType[A, B]]) (Value[A], Value[B]) {
	LockValues()
	defer UnlockValues()
	inputs := [1]ValueUse{v.Use()}
	AcquireValueInputs(inputs[:])
	raw := inputs[0].Lean()
	defer rt.Lean_dec(raw)
	return WrapValue[A](OwnValueField(raw, 0)), WrapValue[B](OwnValueField(raw, 1))
}
