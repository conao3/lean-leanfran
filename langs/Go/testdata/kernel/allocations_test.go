package kernel

import (
	"fmt"
	"math/big"
	"sync"
	"testing"

	"github.com/conao3/leanfran-go"
)

func TestCommandAllocations(t *testing.T) {
	snapshot := initialValue(100)
	actor := NewValue_Actor(Actor{CanWrite: true})
	command := checked(NewValue_Command(CommandAdd{Amount: 1}))
	defer func() { snapshot.Close() }()
	defer actor.Close()
	defer command.Close()
	allocations := testing.AllocsPerRun(1_000, func() {
		if _, err := handleStep(&snapshot, actor, command); err != nil {
			t.Fatal(err)
		}
	})
	if allocations > 8 {
		t.Fatalf("100 rows: %g allocations per command, want at most 8", allocations)
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
			valueActor := NewValue_Actor(actor)
			valueCommand := checked(NewValue_Command(command))
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
		valueActor := NewValue_Actor(actor)
		valueCommand := checked(NewValue_Command(command))
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
		valueActor := NewValue_Actor(actor)
		defer func() { snapshot.Close() }()
		defer valueActor.Close()
		b.ReportAllocs()
		for b.Loop() {
			valueCommand := checked(NewValue_Command(command))
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
			actor := NewValue_Actor(Actor{Tenant: uint64(rows - 1), CanWrite: true})
			command := checked(NewValue_Command(CommandSet{Amount: 1}))
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
			actor := NewValue_Actor(Actor{Tenant: uint64(rows - 1), CanWrite: true})
			command := checked(NewValue_Command(CommandSet{Amount: 7}))
			defer func() { snapshot.Close() }()
			defer actor.Close()
			defer command.Close()
			allocations := testing.AllocsPerRun(100, func() {
				if reply, err := handleStep(&snapshot, actor, command); err != nil || reply != 7 {
					t.Fatalf("reply = %d, err = %v", reply, err)
				}
			})
			if allocations > 10 {
				t.Fatalf("%d rows: %g allocations per command, want at most 10", rows, allocations)
			}
			result := ReadValue_Snapshot(snapshot)
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
			actor := NewValue_Actor(Actor{Tenant: uint64(rows - 1), CanWrite: true})
			command := checked(NewValue_Command(CommandSet{Amount: 1}))
			defer func() { snapshot.Close() }()
			defer actor.Close()
			defer command.Close()
			b.ReportAllocs()
			for b.Loop() {
				leanfran.WithValues(func(scope *leanfran.ValueScope) {
					writes, reply, err := HandleIn_Transition(scope, actor.Borrow(), snapshot.Borrow(), command.Borrow())
					if err != nil {
						b.Fatal(err)
					}
					_ = ReadValueIn_UInt64(scope, reply)
					reply.CloseIn(scope)
					snapshot = HandleIn_Apply(scope, snapshot.Take(), writes.Take())
				})
			}
		})
	}
}
