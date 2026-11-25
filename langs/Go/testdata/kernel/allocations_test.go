package kernel

import (
	"fmt"
	"math/big"
	"sync"
	"testing"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/rt"
)

func TestCommandAllocations(t *testing.T) {
	snapshot := initialValue(100)
	actor := Value.NewActor(Actor{CanWrite: true})
	command := checked(Value.NewCommand(CommandAdd{Amount: 1}))
	defer func() { snapshot.Close() }()
	defer actor.Close()
	defer command.Close()
	allocations := testing.AllocsPerRun(1_000, func() {
		if _, err := handleStep(&snapshot, actor, command); err != nil {
			t.Fatal(err)
		}
	})
	if allocations > 6 {
		t.Fatalf("100 rows: %g allocations per command, want at most 6", allocations)
	}
	t.Logf("100 rows: %g allocations per command", allocations)
}

func BenchmarkCommand(b *testing.B) {
	actor := Actor{CanWrite: true}
	command := CommandAdd{Amount: 1}
	for _, rows := range []int64{10, 100, 1_000} {
		b.Run(fmt.Sprintf("public/%d", rows), func(b *testing.B) {
			snapshot := checked(Initial(big.NewInt(rows)))
			b.ReportAllocs()
			for b.Loop() {
				if _, err := publicStep(&snapshot, actor, command); err != nil {
					b.Fatal(err)
				}
			}
		})
		b.Run(fmt.Sprintf("handle/%d", rows), func(b *testing.B) {
			snapshot := initialValue(rows)
			valueActor := Value.NewActor(actor)
			valueCommand := checked(Value.NewCommand(command))
			defer func() { snapshot.Close() }()
			defer valueActor.Close()
			defer valueCommand.Close()
			b.ReportAllocs()
			for b.Loop() {
				if _, err := handleStep(&snapshot, valueActor, valueCommand); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
	b.Run("server-mutex/100", func(b *testing.B) {
		snapshot := initialValue(100)
		valueActor := Value.NewActor(actor)
		valueCommand := checked(Value.NewCommand(command))
		defer func() { snapshot.Close() }()
		defer valueActor.Close()
		defer valueCommand.Close()
		var mu sync.Mutex
		b.ReportAllocs()
		for b.Loop() {
			mu.Lock()
			_, err := handleStep(&snapshot, valueActor, valueCommand)
			mu.Unlock()
			if err != nil {
				b.Fatal(err)
			}
		}
	})
	b.Run("convert-command/100", func(b *testing.B) {
		snapshot := initialValue(100)
		valueActor := Value.NewActor(actor)
		defer func() { snapshot.Close() }()
		defer valueActor.Close()
		b.ReportAllocs()
		for b.Loop() {
			valueCommand := checked(Value.NewCommand(command))
			_, err := handleStep(&snapshot, valueActor, valueCommand)
			valueCommand.Close()
			if err != nil {
				b.Fatal(err)
			}
		}
	})
}

func BenchmarkLastRowCommand(b *testing.B) {
	for _, rows := range []int64{1, 100, 1_000, 10_000} {
		b.Run(fmt.Sprint(rows), func(b *testing.B) {
			snapshot := initialValue(rows)
			actor := Value.NewActor(Actor{Tenant: uint64(rows - 1), CanWrite: true})
			command := checked(Value.NewCommand(CommandSet{Amount: 1}))
			defer func() { snapshot.Close() }()
			defer actor.Close()
			defer command.Close()
			b.ReportAllocs()
			for b.Loop() {
				if _, err := handleStep(&snapshot, actor, command); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}

func TestLastRowCommandAllocations(t *testing.T) {
	for _, rows := range []int64{1, 100, 1_000, 10_000} {
		t.Run(fmt.Sprint(rows), func(t *testing.T) {
			snapshot := initialValue(rows)
			actor := Value.NewActor(Actor{Tenant: uint64(rows - 1), CanWrite: true})
			command := checked(Value.NewCommand(CommandSet{Amount: 7}))
			defer func() { snapshot.Close() }()
			defer actor.Close()
			defer command.Close()
			allocations := testing.AllocsPerRun(100, func() {
				if reply, err := handleStep(&snapshot, actor, command); err != nil || reply != 7 {
					t.Fatalf("reply = %d, err = %v", reply, err)
				}
			})
			if allocations > 6 {
				t.Fatalf("%d rows: %g allocations per command, want at most 6", rows, allocations)
			}
			result := Value.ReadSnapshot(snapshot)
			if result.Rows[rows-1].Amount != 7 || result.Revision != 101 {
				t.Fatalf("amount = %d, revision = %d", result.Rows[rows-1].Amount, result.Revision)
			}
			t.Logf("%d rows: %g allocations per command", rows, allocations)
		})
	}
}

func BenchmarkScopedLastRowCommand(b *testing.B) {
	for _, rows := range []int64{1, 100, 1_000, 10_000} {
		b.Run(fmt.Sprint(rows), func(b *testing.B) {
			snapshot := initialValue(rows)
			actor := Value.NewActor(Actor{Tenant: uint64(rows - 1), CanWrite: true})
			command := checked(Value.NewCommand(CommandSet{Amount: 1}))
			defer func() { snapshot.Close() }()
			defer actor.Close()
			defer command.Close()
			b.ReportAllocs()
			for b.Loop() {
				leanfran.WithValues(func(scope *leanfran.ValueScope) {
					writes, reply, err := Handle.In(scope).Transition(actor.Borrow(), snapshot.Borrow(), command.Borrow())
					if err != nil {
						b.Fatal(err)
					}
					_ = Value.In(scope).ReadUInt64(reply)
					reply.CloseIn(scope)
					snapshot = Handle.In(scope).Apply(snapshot.Take(), writes.Take())
				})
			}
		})
	}
}

func scopedCommand(snapshot *leanfran.Value[Snapshot], actor Actor, command Command) (uint64, error) {
	var reply uint64
	var err error
	leanfran.WithValues(func(scope *leanfran.ValueScope) {
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

func TestScopedCommandAllocations(t *testing.T) {
	snapshot := initialValue(1)
	defer func() { snapshot.Close() }()
	var command Command = CommandSet{Amount: 7}
	actor := Actor{CanWrite: true}
	allocations := testing.AllocsPerRun(1_000, func() {
		if reply, err := scopedCommand(&snapshot, actor, command); err != nil || reply != 7 {
			t.Fatalf("reply = %d, err = %v", reply, err)
		}
	})
	if allocations > 7 {
		t.Fatalf("%g allocations per scoped command, want at most 7", allocations)
	}
	t.Logf("%g allocations per scoped command", allocations)
}

func BenchmarkScopedCommand(b *testing.B) {
	snapshot := initialValue(1)
	defer func() { snapshot.Close() }()
	var command Command = CommandSet{Amount: 7}
	actor := Actor{CanWrite: true}
	b.ReportAllocs()
	for b.Loop() {
		if _, err := scopedCommand(&snapshot, actor, command); err != nil {
			b.Fatal(err)
		}
	}
}

func rawSnapshot(rows int64) (leanfran.Value[Snapshot], rt.V) {
	snapshot := initialValue(rows)
	inputs := [1]leanfran.ValueUse{snapshot.Borrow().Use()}
	op := leanfran.BeginValueOperation(nil, inputs[:])
	defer op.End()
	op.Acquire(inputs[:])
	return snapshot, inputs[0].Lean()
}

func TestWalkAllocations(t *testing.T) {
	snapshot, raw := rawSnapshot(10_000)
	defer snapshot.Close()
	defer rt.Lean_dec(raw)
	allocations := testing.AllocsPerRun(100, func() {
		if l_Kernel_hasRow(raw, 10_000) != 0 || l_Kernel_hasRow(raw, 9_999) != 1 {
			t.Fatal("hasRow")
		}
	})
	if allocations != 0 {
		t.Fatalf("%g allocations per walk of 10,000 rows, want 0", allocations)
	}
}

func BenchmarkWalk(b *testing.B) {
	for _, rows := range []int64{1_000, 10_000} {
		b.Run(fmt.Sprint(rows), func(b *testing.B) {
			snapshot, raw := rawSnapshot(rows)
			defer snapshot.Close()
			defer rt.Lean_dec(raw)
			b.ReportAllocs()
			for b.Loop() {
				if l_Kernel_hasRow(raw, uint64(rows)) != 0 {
					b.Fatal("hasRow")
				}
			}
			b.ReportMetric(float64(b.Elapsed().Nanoseconds())/float64(b.N)/float64(rows), "ns/row")
		})
	}
}
