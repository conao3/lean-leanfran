import LeanGoModel.B666978747572652e746573742f737461746573

namespace LeanGoModel.B666978747572652e746573742f737461746573

theorem Proved.proof.refines : Proved.obligation.refines := by
  intro n
  exact Int64.add_comm n 1

theorem Sorry.proof.refines : Sorry.obligation.refines := by
  sorry

axiom extra : Axioms.obligation.refines

theorem Axioms.proof.refines : Axioms.obligation.refines := extra

theorem Mismatch.proof.refines : True := trivial

end LeanGoModel.B666978747572652e746573742f737461746573
