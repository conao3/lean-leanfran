package kernel

import (
	"math"
	"math/big"
	"os"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/rt"
)

func regionSnapshot(region *leanfran.Region, rows int64) leanfran.Value[Snapshot] {
	var snapshot leanfran.Value[Snapshot]
	region.WithValues(func(scope *leanfran.ValueScope) {
		n := checked(Value.In(scope).NewNat(big.NewInt(rows)))
		snapshot = Handle.In(scope).Initial(n.Take())
	})
	return snapshot
}

func regionCommand(region *leanfran.Region, snapshot *leanfran.Value[Snapshot], actor Actor, command Command) (uint64, error) {
	var reply uint64
	var err error
	region.WithValues(func(scope *leanfran.ValueScope) {
		values, handle := Value.In(scope), Handle.In(scope)
		who := values.NewActor(actor)
		what, checkErr := values.NewCommand(command)
		if checkErr != nil {
			err = checkErr
			return
		}
		writes, result, callErr := handle.Transition(who.Take(), snapshot.Borrow(), what.Take())
		if callErr != nil {
			err = callErr
			return
		}
		reply = values.ReadUInt64(result)
		result.CloseIn(scope)
		*snapshot = handle.Apply(snapshot.Take(), writes.Take())
	})
	return reply, err
}

func plainCommand(snapshot *leanfran.Value[Snapshot], actor Actor, command Command) (uint64, error) {
	who := Value.NewActor(actor)
	what := checked(Value.NewCommand(command))
	writes, result, err := Handle.Transition(who.Take(), snapshot.Borrow(), what.Take())
	if err != nil {
		return 0, err
	}
	reply := Value.ReadUInt64(result)
	result.Close()
	*snapshot = Handle.Apply(snapshot.Take(), writes.Take())
	return reply, nil
}

func TestRegionsConcurrent(t *testing.T) {
	const calls = 200
	var workers sync.WaitGroup
	for user := range uint64(8) {
		workers.Go(func() {
			region := leanfran.NewRegion()
			snapshot := regionSnapshot(region, 4)
			defer func() { snapshot.Close() }()
			if snapshot.Region() != region {
				t.Error("the snapshot is outside its Region")
			}
			actor := Actor{CanWrite: true, Tenant: 3 * (user % 2)}
			for i := range uint64(calls) {
				step := regionCommand
				if i%2 == 1 {
					step = func(_ *leanfran.Region, s *leanfran.Value[Snapshot], a Actor, c Command) (uint64, error) {
						return plainCommand(s, a, c)
					}
				}
				reply, err := step(region, &snapshot, actor, CommandSet{Amount: i + 1})
				if err != nil {
					t.Error(err)
					return
				}
				if reply != i+1 {
					t.Errorf("user %d: reply = %d, want %d", user, reply, i+1)
					return
				}
				if snapshot.Region() != region || !snapshot.IsExclusive() {
					t.Errorf("user %d: snapshot left its Region or is shared", user)
					return
				}
			}
			if got := Value.ReadSnapshot(snapshot).Rows[3*(user%2)].Amount; got != calls {
				t.Errorf("user %d: amount = %d, want %d", user, got, calls)
			}
		})
	}
	workers.Wait()
}

func TestRegionSharedValue(t *testing.T) {
	region := leanfran.NewRegion()
	snapshot := regionSnapshot(region, 100)
	defer snapshot.Close()
	var workers sync.WaitGroup
	for user := range uint64(2) {
		workers.Go(func() {
			actor := Value.NewActor(Actor{Tenant: 10 * user})
			defer actor.Close()
			read := checked(Value.NewCommand(CommandRead{}))
			defer read.Close()
			for range 500 {
				writes, reply, err := Handle.Transition(actor.Borrow(), snapshot.Borrow(), read.Borrow())
				if err != nil {
					t.Error(err)
					return
				}
				if got := Value.ReadUInt64(reply); got != math.MaxUint64-10*user {
					t.Errorf("reply = %d", got)
				}
				reply.Close()
				writes.Close()
			}
			if actor.Region() != region {
				t.Error("a Value built from Go did not join the Region of its first call")
			}
		})
	}
	workers.Wait()
	if !snapshot.IsExclusive() {
		t.Error("the snapshot is still shared")
	}
}

func TestMixedRegions(t *testing.T) {
	const mixed = "leanfran: Values from different Regions in one call"
	first, second := leanfran.NewRegion(), leanfran.NewRegion()
	a, b := regionSnapshot(first, 2), regionSnapshot(second, 2)
	defer a.Close()
	defer b.Close()
	command := checked(Value.NewCommand(CommandRead{}))
	defer command.Close()
	joined := Value.NewActor(Actor{})
	defer joined.Close()
	writes, reply, err := Handle.Transition(joined.Borrow(), a.Borrow(), command.Borrow())
	if err != nil {
		t.Fatal(err)
	}
	reply.Close()
	writes.Close()
	if joined.Region() != first || command.Region() != first {
		t.Fatal("the Go values did not join the first Region")
	}
	actor := Value.NewActor(Actor{})
	defer actor.Close()
	assertPanic(t, mixed, func() { Handle.Transition(actor.Borrow(), b.Borrow(), command.Borrow()) })
	fresh := checked(Value.NewCommand(CommandRead{}))
	defer fresh.Close()
	assertPanic(t, mixed, func() { Handle.Transition(joined.Borrow(), b.Borrow(), fresh.Borrow()) })
	first.WithValues(func(scope *leanfran.ValueScope) {
		assertPanic(t, mixed, func() { b.IsExclusiveIn(scope) })
		assertPanic(t, mixed, func() { Value.In(scope).ReadSnapshot(b) })
		assertPanic(t, mixed, func() { Handle.In(scope).Transition(actor.Borrow(), b.Borrow(), fresh.Borrow()) })
	})
	if actor.Region() != nil || fresh.Region() != nil {
		t.Fatal("a failed call moved a Value into a Region")
	}
	if !a.IsExclusive() || !b.IsExclusive() {
		t.Fatal("a failed call kept a reference")
	}
	second.WithValues(func(scope *leanfran.ValueScope) {
		writes, reply, err := Handle.In(scope).Transition(actor.Borrow(), b.Borrow(), checked(Value.In(scope).NewCommand(CommandRead{})).Take())
		if err != nil {
			t.Fatal(err)
		}
		reply.CloseIn(scope)
		writes.CloseIn(scope)
	})
	if actor.Region() != second {
		t.Fatal("the actor did not join the second Region")
	}
}

func TestRegionsRunTogether(t *testing.T) {
	held, other := leanfran.NewRegion(), leanfran.NewRegion()
	snapshot := regionSnapshot(other, 1)
	defer func() { snapshot.Close() }()
	actor := Actor{CanWrite: true}
	for _, hold := range []func(func(*leanfran.ValueScope)){held.WithValues, leanfran.WithValues} {
		entered, release := make(chan struct{}), make(chan struct{})
		go hold(func(*leanfran.ValueScope) {
			close(entered)
			<-release
		})
		<-entered
		done := make(chan error, 1)
		go func() {
			_, err := regionCommand(other, &snapshot, actor, CommandSet{Amount: 1})
			if err == nil {
				_, err = plainCommand(&snapshot, actor, CommandSet{Amount: 2})
			}
			done <- err
		}()
		select {
		case err := <-done:
			if err != nil {
				t.Fatal(err)
			}
		case <-time.After(10 * time.Second):
			t.Fatal("a command in one Region waited for another Region's callback")
		}
		close(release)
	}
}

func TestRegionHoldsItsHandles(t *testing.T) {
	region := leanfran.NewRegion()
	snapshot := regionSnapshot(region, 1)
	defer func() { snapshot.Close() }()
	entered, release := make(chan struct{}), make(chan struct{})
	go region.WithValues(func(*leanfran.ValueScope) {
		close(entered)
		<-release
	})
	<-entered
	done := make(chan error, 1)
	go func() {
		_, err := plainCommand(&snapshot, Actor{CanWrite: true}, CommandSet{Amount: 1})
		done <- err
	}()
	select {
	case <-done:
		t.Fatal("a command ran while its Region's callback held the Region")
	case <-time.After(50 * time.Millisecond):
	}
	close(release)
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("the command did not run after the callback returned")
	}
}

func unlockedCommand(snapshot rt.V, actor Actor, command Command) rt.V {
	_lfCodecsOnce.Do(_lfBuildCodecs)
	who, what := _lfCodecActor.ToLean(actor), _lfCodecCommand.ToLean(command)
	rt.Lean_inc(snapshot)
	result := l_Kernel_transition(who, snapshot, what)
	rt.Lean_dec(who)
	rt.Lean_dec(what)
	if rt.Lean_obj_tag(result) == 0 {
		panic("transition failed")
	}
	writes := leanfran.OwnValueField(rt.Lean_ctor_get(result, 0), 0)
	rt.Lean_dec(result)
	return l_Kernel_apply(snapshot, writes)
}

func throughput(goroutines int, duration time.Duration, worker func(user int) func()) float64 {
	var total atomic.Int64
	var stop atomic.Bool
	var ready, workers sync.WaitGroup
	start := make(chan struct{})
	for user := range goroutines {
		ready.Add(1)
		workers.Go(func() {
			step := worker(user)
			ready.Done()
			<-start
			n := int64(0)
			for !stop.Load() {
				for range 64 {
					step()
				}
				n += 64
			}
			total.Add(n)
		})
	}
	ready.Wait()
	began := time.Now()
	close(start)
	time.Sleep(duration)
	stop.Store(true)
	workers.Wait()
	return float64(total.Load()) / time.Since(began).Seconds()
}

func regionWorker(user int) func() {
	region := leanfran.NewRegion()
	snapshot := regionSnapshot(region, 1)
	actor := Actor{CanWrite: true}
	command := CommandSet{Amount: uint64(user)}
	return func() {
		if _, err := regionCommand(region, &snapshot, actor, command); err != nil {
			panic(err)
		}
	}
}

func unlockedWorker(user int) func() {
	n := checked(Value.NewNat(big.NewInt(1)))
	snapshot := Handle.Initial(n.Take())
	inputs := [1]leanfran.ValueUse{snapshot.Take().Use()}
	op := leanfran.BeginValueOperation(nil, inputs[:])
	op.Acquire(inputs[:])
	op.End()
	raw := inputs[0].Lean()
	actor := Actor{CanWrite: true}
	command := CommandSet{Amount: uint64(user)}
	return func() { raw = unlockedCommand(raw, actor, command) }
}

func TestRegionThroughput(t *testing.T) {
	share := 0.6
	if s := os.Getenv("LEANFRAN_REGION_SHARE"); s != "" {
		share = checked(strconv.ParseFloat(s, 64))
	}
	var ratio, control float64
	for attempt := range 3 {
		one := throughput(1, time.Second, regionWorker)
		eight := throughput(8, time.Second, regionWorker)
		unlockedOne := throughput(1, time.Second, unlockedWorker)
		unlockedEight := throughput(8, time.Second, unlockedWorker)
		ratio, control = eight/one, unlockedEight/unlockedOne
		t.Logf("attempt %d: Regions %.0f / %.0f commands/s (1 / 8 goroutines, ratio %.2f); without a lock %.0f / %.0f commands/s (ratio %.2f); GOMAXPROCS %d",
			attempt, one, eight, ratio, unlockedOne, unlockedEight, control, runtime.GOMAXPROCS(0))
		if ratio >= share*control {
			if control < 1.5 {
				t.Logf("the commands without a lock ran %.2f times as fast on 8 goroutines, too little to tell the Regions from one lock", control)
			}
			return
		}
	}
	t.Fatalf("8 goroutines in separate Regions ran %.2f times the commands of 1 goroutine, want %.2f or more (%.2f of %.2f without a lock)",
		ratio, share*control, share, control)
}
