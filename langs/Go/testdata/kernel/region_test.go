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

func regionThroughput(goroutines int, duration time.Duration) float64 {
	var total atomic.Int64
	var stop atomic.Bool
	var ready, workers sync.WaitGroup
	start := make(chan struct{})
	for user := range goroutines {
		ready.Add(1)
		workers.Go(func() {
			region := leanfran.NewRegion()
			snapshot := regionSnapshot(region, 1)
			defer func() { snapshot.Close() }()
			actor := Actor{CanWrite: true}
			command := CommandSet{Amount: uint64(user)}
			ready.Done()
			<-start
			n := int64(0)
			for !stop.Load() {
				for range 64 {
					if _, err := regionCommand(region, &snapshot, actor, command); err != nil {
						panic(err)
					}
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

func TestRegionThroughput(t *testing.T) {
	procs := min(runtime.GOMAXPROCS(0), 8)
	if procs < 2 {
		t.Skip("needs 2 or more Ps")
	}
	floor := max(1.5, 0.4*float64(procs))
	if s := os.Getenv("LEANFRAN_REGION_SPEEDUP"); s != "" {
		floor = checked(strconv.ParseFloat(s, 64))
	}
	var ratio float64
	for attempt := range 3 {
		one := regionThroughput(1, time.Second)
		eight := regionThroughput(8, time.Second)
		ratio = eight / one
		t.Logf("attempt %d: 1 goroutine %.0f commands/s, 8 goroutines %.0f commands/s, ratio %.2f (floor %.2f, GOMAXPROCS %d)",
			attempt, one, eight, ratio, floor, runtime.GOMAXPROCS(0))
		if ratio >= floor {
			return
		}
	}
	t.Fatalf("8 goroutines in separate Regions ran %.2f times the commands of 1 goroutine, want %.2f or more", ratio, floor)
}
