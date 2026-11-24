package kernel

import (
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/rt"
)

func TestValueScope(t *testing.T) {
	var saved *leanfran.ValueScope
	var counter leanfran.Value[Counter]
	scalar := Value.NewUInt64(9)
	defer scalar.Close()
	if scalar.IsExclusive() {
		t.Fatal("scalar reports exclusive ownership")
	}
	assertPanic(t, "scope callback panic", func() {
		leanfran.WithValues(func(scope *leanfran.ValueScope) {
			saved = scope
			counter = Value.In(scope).NewCounter(Counter{Count: 1})
			if !counter.IsExclusiveIn(scope) {
				t.Fatal("new counter is shared")
			}
			alias := counter
			counter = Handle.In(scope).Bump(counter.Take(), scalar.Borrow())
			assertPanic(t, "leanfran: empty Value", func() { alias.IsExclusiveIn(scope) })
			if !counter.IsExclusiveIn(scope) || Value.In(scope).ReadCounter(counter).Count != 9 {
				t.Fatal("counter update failed")
			}
			pair := Value.In(scope).NewPairUInt64UInt64(leanfran.Pair[uint64, uint64]{Fst: 1, Snd: 2})
			left, right := leanfran.SplitValueIn(scope, pair.Take())
			if Value.In(scope).ReadUInt64(left) != 1 || Value.In(scope).ReadUInt64(right) != 2 {
				t.Fatal("unexpected split values")
			}
			left.CloseIn(scope)
			right.CloseIn(scope)
			panic("scope callback panic")
		})
	})
	defer counter.Close()
	if !counter.IsExclusive() || Value.ReadCounter(counter).Count != 9 {
		t.Fatal("counter escaped the callback with the wrong value or ownership")
	}
	assertPanic(t, "leanfran: inactive ValueScope", func() { counter.CloseIn(saved) })
}

func TestValueScopeConcurrent(t *testing.T) {
	const calls = 100
	snapshot := initialValue(100)
	defer func() { snapshot.Close() }()
	var workers sync.WaitGroup
	for user := range uint64(8) {
		workers.Go(func() {
			actor := Value.NewActor(Actor{CanWrite: true, Tenant: 3 * user})
			defer actor.Close()
			command := checked(Value.NewCommand(CommandSet{Amount: 1 + user}))
			defer command.Close()
			for range calls {
				leanfran.WithValues(func(scope *leanfran.ValueScope) {
					writes, reply, err := Handle.In(scope).Transition(actor.Borrow(), snapshot.Borrow(), command.Borrow())
					if err != nil {
						t.Error(err)
						return
					}
					if got := Value.In(scope).ReadUInt64(reply); got != 1+user {
						t.Errorf("reply = %d, want %d", got, 1+user)
					}
					reply.CloseIn(scope)
					if !snapshot.IsExclusiveIn(scope) {
						t.Error("snapshot is shared")
					}
					snapshot = Handle.In(scope).Apply(snapshot.Take(), writes.Take())
				})
			}
		})
	}
	workers.Wait()
	result := Value.ReadSnapshot(snapshot)
	if result.Revision != 8*calls {
		t.Fatalf("revision = %d, want %d", result.Revision, 8*calls)
	}
	for user := range uint64(8) {
		if got := result.Rows[3*user].Amount; got != 1+user {
			t.Errorf("user %d amount = %d, want %d", user, got, 1+user)
		}
	}
}

func TestValueScopeCleanup(t *testing.T) {
	for _, scoped := range []bool{false, true} {
		raw := rt.Lean_alloc_ctor(0, 0, 0)
		rt.Lean_inc(raw)
		kept := leanfran.WrapValue[Counter](raw)
		if scoped {
			leanfran.WithValues(func(scope *leanfran.ValueScope) {
				_ = leanfran.WrapValueIn[Counter](scope, raw)
			})
		} else {
			_ = leanfran.WrapValue[Counter](raw)
		}
		deadline := time.Now().Add(5 * time.Second)
		for !kept.IsExclusive() && time.Now().Before(deadline) {
			runtime.GC()
			time.Sleep(time.Millisecond)
		}
		if !kept.IsExclusive() {
			t.Errorf("scoped=%v: GC did not release the second Lean reference", scoped)
		}
		kept.Close()
	}
}
