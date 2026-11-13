import LeanRustGen.Obligation.leanfran_verify_test.counter
open Aeneas Aeneas.Std Result

namespace leanfran_verify_test.counter

theorem Counter.reset.proof.refines : Counter.reset.obligation.refines := by
  intro self
  unfold Counter.reset _root_.counters.reset
  rfl

end leanfran_verify_test.counter
