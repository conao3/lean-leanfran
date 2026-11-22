import LeanPhpModel.App.Negative

namespace LeanPhpModel.App.Negative

theorem unsafeAdd.proof.refines : unsafeAdd.obligation.refines := by
  intro a b
  simp [unsafeAdd, Php.add, Php.checked, LeanPhpEmbed.App.Calc.addSpec]
  split <;> simp_all

end LeanPhpModel.App.Negative
