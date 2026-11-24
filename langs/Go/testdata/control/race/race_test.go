package race

import (
	"sync"
	"testing"

	"github.com/conao3/leanfran-go/rt"
)

func TestGeneratedGoroutines(t *testing.T) {
	render := func() string {
		result := L_LeanGoTest_ControlRace_render(rt.Lean_mk_string("Go"))
		defer rt.Lean_dec(result)
		return rt.String(result)
	}
	want := render()
	if want != "先:猫Go" {
		t.Fatalf("serial call returned %q", want)
	}

	const workers = 8
	const callsPerWorker = 1000
	start := make(chan struct{})
	var work sync.WaitGroup
	for range workers {
		work.Go(func() {
			<-start
			for range callsPerWorker {
				if got := render(); got != want {
					t.Errorf("concurrent call returned %q, want %q", got, want)
					return
				}
			}
		})
	}
	close(start)
	work.Wait()
	t.Logf("%d goroutines called the generated function %d times each", workers, callsPerWorker)
}
