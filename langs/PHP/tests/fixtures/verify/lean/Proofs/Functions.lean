import LeanPhpModel.App

open LeanPhpEmbed.App.Calc
namespace LeanPhpModel.App

theorem increment.proof.refines : increment.obligation.refines := by
  intro a h
  simp_all [increment, nextFits, nextSpec, Php.add, Php.checked]

end LeanPhpModel.App
