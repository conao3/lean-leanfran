package kernel

import (
	"fmt"
	"math/big"
	"sync"
	"testing"
)

func TestCommandAllocations(t *testing.T) {
	snapshot := initialValue(100)
	actor := checked(NewActorValue(Actor{CanWrite: true}))
	command := checked(NewCommandValue(CommandAdd{Amount: 1}))
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
			valueActor := checked(NewActorValue(actor))
			valueCommand := checked(NewCommandValue(command))
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
		valueActor := checked(NewActorValue(actor))
		valueCommand := checked(NewCommandValue(command))
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
		valueActor := checked(NewActorValue(actor))
		defer func() { snapshot.Close() }()
		defer valueActor.Close()
		b.ReportAllocs()
		for b.Loop() {
			valueCommand := checked(NewCommandValue(command))
			_, err := handleStep(&snapshot, valueActor, valueCommand)
			valueCommand.Close()
			if err != nil {
				b.Fatal(err)
			}
		}
	})
}
