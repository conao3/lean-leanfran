package kernel

import (
	"bytes"
	"errors"
	"fmt"
	"math"
	"math/big"
	"math/rand/v2"
	"os"
	"os/exec"
	"strings"
	"sync"
	"testing"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/rt"
)

func checked[T any](value T, err error) T {
	if err != nil {
		panic(err)
	}
	return value
}

func initialValue(size int64) leanfran.Value[Snapshot] {
	n := checked(Value.NewNat(big.NewInt(size)))
	return Handle.Initial(n.Take())
}

func handleStep(snapshot *leanfran.Value[Snapshot], actor leanfran.Value[Actor], command leanfran.Value[Command]) (uint64, error) {
	writes, reply, err := Handle.Transition(actor.Borrow(), snapshot.Borrow(), command.Borrow())
	if err != nil {
		return 0, err
	}
	next := Handle.Apply(snapshot.Take(), writes.Take())
	*snapshot = next
	result := Value.ReadUInt64(reply)
	reply.Close()
	return result, nil
}

func publicStep(snapshot *Snapshot, actor Actor, command Command) (uint64, error) {
	result, err := Transition(actor, *snapshot, command)
	if err != nil {
		return 0, err
	}
	next, err := Apply(*snapshot, result.Fst)
	*snapshot = next
	return result.Snd, err
}

func renderReply(reply uint64, err error) string {
	if err == nil {
		return fmt.Sprintf("ok %d", reply)
	}
	var leanError *leanfran.ExceptError[Error]
	if !errors.As(err, &leanError) {
		panic(err)
	}
	return "error " + ErrorRender(leanError.Value)
}

func renderRows(snapshot Snapshot) string {
	var out strings.Builder
	fmt.Fprintf(&out, "%d;", snapshot.Revision)
	for i, row := range snapshot.Rows {
		if i > 0 {
			out.WriteByte(';')
		}
		fmt.Fprintf(&out, "%d,%d,", row.Id, row.Amount)
		if row.Limit == nil {
			out.WriteByte('-')
		} else {
			fmt.Fprint(&out, *row.Limit)
		}
		fmt.Fprintf(&out, ", %s", ModeRender(row.Mode))
	}
	return out.String()
}

func seededCommands(run func(Actor, Command, string, uint64)) {
	random := rand.New(rand.NewPCG(20261124, 3958))
	actor := Actor{CanWrite: true}
	run(actor, CommandRead{}, "read", 0)
	run(actor, CommandLimit{Value: new(uint64(0))}, "limit", 0)
	run(actor, CommandSet{Amount: math.MaxUint64}, "set", math.MaxUint64)
	run(actor, CommandLimit{}, "unlimit", 0)
	run(Actor{}, CommandAdd{Amount: 1}, "add", 1)
	run(Actor{CanWrite: true, Tenant: 99}, CommandSet{Amount: 7}, "set", 7)
	for range 4994 {
		actor := Actor{CanWrite: random.IntN(5) != 0}
		if random.IntN(17) == 0 {
			actor.Tenant = math.MaxUint64
		}
		arg := random.Uint64()
		switch random.IntN(6) {
		case 0:
			run(actor, CommandRead{}, "read", 0)
		case 1:
			run(actor, CommandAdd{Amount: arg}, "add", arg)
		case 2:
			run(actor, CommandSet{Amount: arg}, "set", arg)
		case 3:
			run(actor, CommandLimit{Value: &arg}, "limit", arg)
		case 4:
			run(actor, CommandLimit{}, "unlimit", 0)
		case 5:
			run(actor, CommandPause{}, "pause", 0)
		}
	}
}

func TestKernelOracle(t *testing.T) {
	oracle := os.Getenv("LEANFRAN_KERNEL_ORACLE")
	if oracle == "" {
		t.Fatal("set LEANFRAN_KERNEL_ORACLE to the native Lean oracle")
	}
	goSnapshot := checked(Initial(big.NewInt(100)))
	valueSnapshot := initialValue(100)
	defer func() { valueSnapshot.Close() }()
	var input bytes.Buffer
	publicLines := make([]string, 0, 5001)
	seededCommands(func(actor Actor, command Command, op string, arg uint64) {
		permission := 0
		if actor.CanWrite {
			permission = 1
		}
		fmt.Fprintf(&input, "%d %d %s %d\n", permission, actor.Tenant, op, arg)
		goReply := renderReply(publicStep(&goSnapshot, actor, command))
		valueActor := Value.NewActor(actor)
		valueCommand := checked(Value.NewCommand(command))
		valueReply := renderReply(handleStep(&valueSnapshot, valueActor, valueCommand))
		valueActor.Close()
		valueCommand.Close()
		if goReply != valueReply {
			t.Fatalf("command %d: Go = %q, handle = %q", len(publicLines)+1, goReply, valueReply)
		}
		publicLines = append(publicLines, goReply)
	})
	publicRows := renderRows(goSnapshot)
	if got := renderRows(Value.ReadSnapshot(valueSnapshot)); got != publicRows {
		t.Fatal("Go snapshot and handle snapshot differ")
	}
	publicLines = append(publicLines, publicRows)
	cmd := exec.Command(oracle)
	cmd.Stdin = &input
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("C oracle: %v\n%s", err, output)
	}
	native := strings.Split(strings.TrimSuffix(string(output), "\n"), "\n")
	if len(native) != len(publicLines) {
		t.Fatalf("C oracle emitted %d lines, want %d", len(native), len(publicLines))
	}
	for i, got := range native {
		if got != publicLines[i] {
			t.Fatalf("C oracle line %d: got %q, Go/handle = %q", i+1, got, publicLines[i])
		}
	}
}

func TestConcurrentValues(t *testing.T) {
	const calls = 200
	snapshot := initialValue(100)
	actor := Value.NewActor(Actor{CanWrite: true})
	command := checked(Value.NewCommand(CommandAdd{Amount: 1}))
	defer actor.Close()
	defer command.Close()

	var mu sync.Mutex
	var group sync.WaitGroup
	for range 8 {
		group.Go(func() {
			for range calls {
				mu.Lock()
				_, err := handleStep(&snapshot, actor, command)
				mu.Unlock()
				if err != nil {
					t.Error(err)
					return
				}
			}
		})
	}
	group.Wait()
	defer snapshot.Close()
	if value := Value.ReadSnapshot(snapshot); value.Revision != 8*calls || value.Rows[0].Amount != 8*calls-1 {
		t.Fatalf("revision %d and amount %d after %d commands", value.Revision, value.Rows[0].Amount, 8*calls)
	}
}

func TestSharedValues(t *testing.T) {
	origin := initialValue(100)
	writes := checked(Value.NewWrites(WritesAmount{Value: 12}))
	defer origin.Close()
	defer writes.Close()
	var group sync.WaitGroup
	for range 8 {
		group.Go(func() {
			for range 100 {
				derived := Handle.Apply(origin.Borrow(), writes.Borrow())
				if snapshot := Value.ReadSnapshot(derived); snapshot.Rows[0].Amount != 12 {
					t.Errorf("derived amount = %d", snapshot.Rows[0].Amount)
				}
				derived.Close()
			}
		})
	}
	group.Wait()
	if got := Value.ReadSnapshot(origin).Rows[0].Amount; got != math.MaxUint64 {
		t.Fatalf("borrowed snapshot mutated: %d", got)
	}
}

func TestValueOwnership(t *testing.T) {
	arg := Value.NewUInt64(21)
	a := arg
	total := Handle.AddValues(arg.Take(), arg.Borrow())
	defer total.Close()
	if got := Value.ReadUInt64(total); got != 42 {
		t.Fatalf("add result = %d", got)
	}
	assertPanic(t, "leanfran: empty Value", func() { Value.ReadUInt64(a) })
	a.Close()
	a = Value.NewUInt64(21)
	defer a.Close()
	assertPanic(t, "leanfran: Value taken twice in one call", func() { Handle.AddValues(a.Take(), a.Take()) })
	assertPanic(t, "leanfran: empty Value", func() {
		Handle.AddValues(a.Take(), leanfran.ValueInput[uint64]{})
	})
	if got := Value.ReadUInt64(a); got != 21 {
		t.Fatalf("unconsumed argument = %d", got)
	}
	first, second := Handle.PairValue(a.Borrow())
	defer first.Close()
	defer second.Close()
	pair := Value.NewPairUInt64UInt64(leanfran.Pair[uint64, uint64]{Fst: 1, Snd: 2})
	left, right := leanfran.SplitValue(pair.Take())
	defer left.Close()
	defer right.Close()
	if Value.ReadUInt64(first) != 21 || Value.ReadUInt64(second) != 21 ||
		Value.ReadUInt64(left) != 1 || Value.ReadUInt64(right) != 2 {
		t.Fatal("unexpected product components")
	}
	assertPanic(t, "leanfran: empty Value", func() { Value.ReadPairUInt64UInt64(pair) })
}

func assertPanic(t *testing.T, want string, f func()) {
	t.Helper()
	defer func() {
		if value := recover(); value != want {
			t.Errorf("panic = %v, want %q", value, want)
		}
	}()
	f()
}

func TestOpaqueValues(t *testing.T) {
	key := Value.NewUInt64(math.MaxUint64)
	defer key.Close()
	verified := Handle.Verify(key.Borrow())
	revealed := Handle.ReadVerified(verified.Take())
	defer revealed.Close()
	if got := Value.ReadUInt64(revealed); got != math.MaxUint64 {
		t.Fatalf("verified value = %d", got)
	}
	capacity := checked(Value.NewNat(big.NewInt(4)))
	defer capacity.Close()
	cache := Handle.NewCache(capacity.Borrow())
	cache = Handle.InsertCache(cache.Take(), key.Borrow(), key.Borrow())
	defer cache.Close()
	found := Handle.FindCache(cache.Borrow(), key.Borrow())
	defer found.Close()
	if got := Value.ReadOptionUInt64(found); got == nil || *got != math.MaxUint64 {
		t.Fatalf("cache lookup = %v", got)
	}
	entries := Handle.EmptyMap(capacity.Borrow())
	size := Handle.MapSize(entries.Take())
	defer size.Close()
	if got := Value.ReadNat(size).Uint64(); got != 0 {
		t.Fatalf("empty map size = %d", got)
	}
}

func rawValue[T any](v leanfran.Value[T]) rt.V {
	inputs := [1]leanfran.ValueUse{v.Borrow().Use()}
	op := leanfran.BeginValueOperation(nil, inputs[:])
	defer op.End()
	op.Acquire(inputs[:])
	raw := inputs[0].Lean()
	rt.Lean_dec(raw)
	return raw
}

func TestTakeReusesLeanObjects(t *testing.T) {
	n := Value.NewUInt64(math.MaxUint64)
	defer n.Close()
	counter := Value.NewCounter(Counter{Count: 1, Other: 2})
	defer counter.Close()
	before := rawValue(counter)
	changed := Handle.Bump(counter.Take(), n.Borrow())
	defer changed.Close()
	if got := rawValue(changed); got != before || Value.ReadCounter(changed).Count != math.MaxUint64 {
		t.Fatal("Take did not reuse the counter")
	}
	values := Value.NewArrayUInt64([]uint64{1, 2})
	defer values.Close()
	before = rawValue(values)
	updated := Handle.ReplaceLast(values.Take(), n.Borrow())
	defer updated.Close()
	if got := rawValue(updated); got != before || Value.ReadArrayUInt64(updated)[1] != math.MaxUint64 {
		t.Fatal("Take did not reuse the array")
	}
}

func TestInPlaceUpdates(t *testing.T) {
	_lfCodecsOnce.Do(_lfBuildCodecs)
	counter := toCounter(Counter{Other: math.MaxUint64})
	array := rt.Lean_mk_empty_array_with_capacity(rt.Lean_box(1))
	array = rt.Lean_array_push(array, rt.Lean_box(1))
	defer rt.Lean_dec(counter)
	defer rt.Lean_dec(array)
	if got := testing.AllocsPerRun(1_000, func() {
		if updated := l_Kernel_bump(counter, 9); updated != counter {
			t.Fatal("Lean allocated a new counter")
		}
	}); got != 0 {
		t.Fatalf("counter update allocations = %g", got)
	}
	if got := testing.AllocsPerRun(1_000, func() {
		if updated := l_Kernel_replaceLast(array, 9); updated != array {
			t.Fatal("Lean allocated a new array")
		}
	}); got != 0 {
		t.Fatalf("array update allocations = %g", got)
	}
	if fromCounter(counter) != (Counter{Count: 9, Other: math.MaxUint64}) ||
		rt.Lean_unbox(rt.Lean_array_uget(array, 0)) != 9 {
		t.Fatal("in-place update produced the wrong values")
	}
}
