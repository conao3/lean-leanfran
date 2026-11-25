package kernel

import (
	"sync"
	"sync/atomic"
	"testing"

	"github.com/conao3/leanfran-go"
)

const mixedRegionsPanic = "leanfran: Values from different Regions in one call"

func TestTakeUnaffiliatedFromTwoRegions(t *testing.T) {
	for trial := range 200 {
		who := Value.NewActor(Actor{CanWrite: true})
		var panics, calls atomic.Int32
		var group sync.WaitGroup
		for range 2 {
			region := leanfran.NewRegion()
			snapshot := regionSnapshot(region, 2)
			group.Go(func() {
				defer snapshot.Close()
				defer func() {
					if r := recover(); r != nil {
						if r != mixedRegionsPanic {
							t.Errorf("trial %d: panic %v", trial, r)
						}
						panics.Add(1)
					}
				}()
				region.WithValues(func(scope *leanfran.ValueScope) {
					what := checked(Value.In(scope).NewCommand(CommandRead{}))
					writes, reply, err := Handle.In(scope).Transition(who.Take(), snapshot.Borrow(), what.Take())
					if err != nil {
						t.Error(err)
						return
					}
					writes.CloseIn(scope)
					reply.CloseIn(scope)
					calls.Add(1)
				})
			})
		}
		group.Wait()
		if panics.Load() != 1 || calls.Load() != 1 {
			t.Fatalf("trial %d: %d calls and %d panics, want 1 and 1", trial, calls.Load(), panics.Load())
		}
	}
}

func TestUnscopedZeroInputCallInRegion(t *testing.T) {
	region, other := leanfran.NewRegion(), leanfran.NewRegion()
	var made leanfran.Value[Snapshot]
	region.WithValues(func(*leanfran.ValueScope) { made = Handle.Starting() })
	if made.Region() != nil {
		t.Fatal("a call without Value inputs put its result in a Region")
	}
	leanfran.WithValues(func(scope *leanfran.ValueScope) {
		defaultMade := Handle.Starting()
		defer defaultMade.CloseIn(scope)
		if defaultMade.Region() != nil {
			t.Fatal("a call without Value inputs put its result in a Region")
		}
	})
	region.WithValues(func(scope *leanfran.ValueScope) {
		values, handle := Value.In(scope), Handle.In(scope)
		what := checked(values.NewCommand(CommandRead{}))
		writes, reply, err := handle.Transition(values.NewActor(Actor{CanWrite: true}).Take(), made.Borrow(), what.Take())
		if err != nil {
			t.Fatal(err)
		}
		writes.CloseIn(scope)
		reply.CloseIn(scope)
	})
	if made.Region() != region {
		t.Fatal("the result did not join the Region of its first call")
	}
	other.WithValues(func(scope *leanfran.ValueScope) {
		assertPanic(t, mixedRegionsPanic, func() { made.IsExclusiveIn(scope) })
	})
	made.Close()
}
