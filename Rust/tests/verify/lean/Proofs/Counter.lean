import LeanRustGen.Obligation.lean_rust_verify_test.counter
open Aeneas Aeneas.Std Result

namespace lean_rust_verify_test.counter

theorem Counter.reset.proof.refines : Counter.reset.obligation.refines := by
  intro self
  unfold Counter.reset _root_.counters.reset
  rfl

end lean_rust_verify_test.counter
