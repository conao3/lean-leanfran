package fixture

import (
	"testing"

	"github.com/conao3/leanfran-go/rt"
)

func checkPanic(t *testing.T, call func() rt.V, want string) {
	t.Helper()
	defer func() {
		value := recover()
		failure, ok := value.(*rt.InternalPanic)
		if !ok || failure.Message != want || failure.Error() != want {
			t.Fatalf("panic = %#v, want *rt.InternalPanic with message %q", value, want)
		}
	}()
	call()
}

func TestRecoverAndContinue(t *testing.T) {
	checkPanic(t, func() rt.V { return L_LeanGoTest_Panic_unreachable(0) }, "unreachable code has been reached")
	checkPanic(t, func() rt.V { return L_LeanGoTest_Panic_unreadableRef(rt.NatFromUint64(1)) }, "null reference read")
	if got := rt.NatString(L_LeanGoTest_Panic_increment(rt.NatFromUint64(41))); got != "42" {
		t.Fatalf("increment after recovery = %s, want 42", got)
	}
	if got := rt.NatString(L_LeanGoTest_Panic_leanPanic(rt.Lean_mk_string("Lean panic fixture"))); got != "0" {
		t.Fatalf("Lean panic default = %s, want 0", got)
	}
}
