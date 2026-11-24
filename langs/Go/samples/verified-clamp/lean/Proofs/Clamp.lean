import LeanGoModel.B6578616d706c652e636f6d2f76657269666965642d636c616d70

open LeanGoEmbed.B6578616d706c652e636f6d2f76657269666965642d636c616d70
namespace LeanGoModel.B6578616d706c652e636f6d2f76657269666965642d636c616d70

theorem Clamp.proof.refines : Clamp.obligation.refines := by
  intro x lo hi h
  simp only [ordered, decide_eq_true_eq] at h
  simp only [Clamp, clampSpec, Id.run, pure, Pure.pure, Int64.min_def, Int64.max_def,
    decide_eq_true_eq]
  repeat' split
  all_goals simp_all only [Int64.lt_iff_toInt_lt, Int64.le_iff_toInt_le, ← Int64.toInt_inj] <;> omega

theorem Clamp.proof.in_range : Clamp.obligation.in_range := by
  intro x lo hi h
  simp only [ordered, decide_eq_true_eq] at h
  simp only [Clamp, inRange, Id.run, pure, Pure.pure, Bool.and_eq_true, decide_eq_true_eq]
  split <;> try split
  all_goals simp_all only [Int64.lt_iff_toInt_lt, Int64.le_iff_toInt_le]
  all_goals constructor <;> first | exact True.intro | omega

end LeanGoModel.B6578616d706c652e636f6d2f76657269666965642d636c616d70
