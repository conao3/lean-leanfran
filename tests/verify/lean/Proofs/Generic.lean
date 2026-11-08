import LeanRustGen.Obligation.lean_rust_verify_test.generic
open Aeneas Aeneas.Std Result

namespace lean_rust_verify_test.generic

theorem max_of.proof.ge : max_of.obligation.ge := by
  intro T _ ord _ copy a b
  unfold max_of
  step*
  · simp_all [_root_.generic_specs.max_ge]
  · simp_all [_root_.generic_specs.max_ge]
    exact le_of_lt (by simpa using ‹_›)

theorem larger.proof.refines.u32 : larger.obligation.refines.u32 := by
  intro a b
  apply LeanRust.eq_ok_of_spec
  unfold larger
  step*
  · simp_all [_root_.generic_specs.larger.inst_U32, _root_.generic_specs.larger,
      core.cmp.impls.PartialOrdU32.gt]
    omega
  · simp_all [_root_.generic_specs.larger.inst_U32, _root_.generic_specs.larger,
      core.cmp.impls.PartialOrdU32.gt]

theorem Pair.swap.proof.refines.u32 : Pair.swap.obligation.refines.u32 := by
  intro self
  simp [Pair.swap, _root_.pairs.swapped]

theorem larger.proof.refines.i64 : larger.obligation.refines.i64 := by
  sorry

end lean_rust_verify_test.generic
