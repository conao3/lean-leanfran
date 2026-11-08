import Aeneas

/-! # Laws of Rust's traits over Aeneas's models

Aeneas turns a trait bound of a Rust function into an explicit argument: the structure of the
trait's methods (`core.cmp.Ord T`). The classes here state that such a structure agrees with a
Lean type class (`OrdModel ord` with `[LinearOrder T]`), so that one proof of an obligation of a
generic function holds for every type. The `@[step]` lemmas rewrite the methods, and the
instances prove the classes for Aeneas's instances of the scalars, `Bool`, `()`, `Vec`, `Box`
and arrays. -/

open Aeneas Aeneas.Std Result

namespace LeanRust

universe u

/-- `partial_cmp` of a preorder. -/
def partialCompare {T : Type u} [Preorder T] [DecidableRel (α := T) (· ≤ ·)] (a b : T) : Option Ordering :=
  if a ≤ b then (if b ≤ a then some .eq else some .lt) else if b ≤ a then some .gt else none

theorem partialCompare_eq_compare {T : Type u} [LinearOrder T] (a b : T) :
    partialCompare a b = some (compare a b) := by
  unfold partialCompare
  rcases lt_trichotomy a b with h | rfl | h
  · simp [h.le, not_le.mpr h, compare_lt_iff_lt.mpr h]
  · simp
  · simp [h.le, not_le.mpr h, compare_gt_iff_gt.mpr h]

/-- `PartialEq`: `eq` and `ne` decide equality. -/
class PartialEqModel {T : Type u} [DecidableEq T] (inst : core.cmp.PartialEq T T) : Prop where
  eq_ok : ∀ a b, inst.eq a b = ok (decide (a = b))
  ne_ok : ∀ a b, inst.ne a b = ok (!decide (a = b))

/-- `PartialOrd`: the comparisons decide the preorder, `partial_cmp` is `partialCompare`, and `eq`
    holds for the elements below each other. -/
class PartialOrdModel {T : Type u} [Preorder T] [DecidableRel (α := T) (· ≤ ·)]
    (inst : core.cmp.PartialOrd T T) : Prop where
  partial_cmp_ok : ∀ a b, inst.partial_cmp a b = ok (partialCompare a b)
  lt_ok : ∀ a b, inst.lt a b = ok (decide (a ≤ b ∧ ¬b ≤ a))
  le_ok : ∀ a b, inst.le a b = ok (decide (a ≤ b))
  gt_ok : ∀ a b, inst.gt a b = ok (decide (b ≤ a ∧ ¬a ≤ b))
  ge_ok : ∀ a b, inst.ge a b = ok (decide (b ≤ a))
  eq_ok : ∀ a b, inst.partialEqInst.eq a b = ok (decide (a ≤ b ∧ b ≤ a))

/-- `Ord`: `cmp` is `compare` of the linear order, `max` and `min` are `max` and `min`, and the
    `PartialOrd` and `Eq` instances it contains are models. -/
class OrdModel {T : Type u} [LinearOrder T] (inst : core.cmp.Ord T) : Prop where
  cmp_ok : ∀ a b, inst.cmp a b = ok (compare a b)
  max_ok : ∀ a b, inst.max a b = ok (max a b)
  min_ok : ∀ a b, inst.min a b = ok (min a b)
  partialOrd : PartialOrdModel inst.partialOrdInst
  partialEq : PartialEqModel inst.eqInst.partialEqInst

/-- `Clone`: `clone` returns the value. -/
class CloneModel {T : Type u} (inst : core.clone.Clone T) : Prop where
  clone_ok : ∀ a, inst.clone a = ok a

/-- `Default`: `default` is `default` of `Inhabited`. -/
class DefaultModel {T : Type u} [Inhabited T] (inst : core.default.Default T) : Prop where
  default_ok : inst.default = ok default

/-! ## `step` lemmas -/

section Step

variable {T : Type u}

theorem spec_of_eq_ok {α : Type u} {m : Result α} {v : α} (h : m = ok v) : m ⦃ r => r = v ⦄ := by
  rw [h]; simp [WP.spec_ok]

/-- `m ⦃ r => r = v ⦄` is `m = ok v`. -/
theorem eq_ok_of_spec {α : Type u} {m : Result α} {v : α} (h : m ⦃ r => r = v ⦄) : m = ok v := by
  cases m with
  | ret r => simp_all [WP.spec_ok]
  | vis i k => simp [WP.spec_vis] at h
  | div => simp [WP.spec_div] at h

@[step] theorem PartialEqModel.eq_spec [DecidableEq T] (inst : core.cmp.PartialEq T T) [PartialEqModel inst]
    (a b : T) : inst.eq a b ⦃ r => r = decide (a = b) ⦄ :=
  spec_of_eq_ok (PartialEqModel.eq_ok a b)

@[step] theorem PartialEqModel.ne_spec [DecidableEq T] (inst : core.cmp.PartialEq T T) [PartialEqModel inst]
    (a b : T) : inst.ne a b ⦃ r => r = !decide (a = b) ⦄ :=
  spec_of_eq_ok (PartialEqModel.ne_ok a b)

section Preorder

variable [Preorder T] [DecidableRel (α := T) (· ≤ ·)] (inst : core.cmp.PartialOrd T T) [PartialOrdModel inst]

@[step] theorem PartialOrdModel.partial_cmp_spec (a b : T) :
    inst.partial_cmp a b ⦃ r => r = partialCompare a b ⦄ :=
  spec_of_eq_ok (PartialOrdModel.partial_cmp_ok a b)

@[step] theorem PartialOrdModel.lt_spec (a b : T) : inst.lt a b ⦃ r => r = decide (a ≤ b ∧ ¬b ≤ a) ⦄ :=
  spec_of_eq_ok (PartialOrdModel.lt_ok a b)

@[step] theorem PartialOrdModel.le_spec (a b : T) : inst.le a b ⦃ r => r = decide (a ≤ b) ⦄ :=
  spec_of_eq_ok (PartialOrdModel.le_ok a b)

@[step] theorem PartialOrdModel.gt_spec (a b : T) : inst.gt a b ⦃ r => r = decide (b ≤ a ∧ ¬a ≤ b) ⦄ :=
  spec_of_eq_ok (PartialOrdModel.gt_ok a b)

@[step] theorem PartialOrdModel.ge_spec (a b : T) : inst.ge a b ⦃ r => r = decide (b ≤ a) ⦄ :=
  spec_of_eq_ok (PartialOrdModel.ge_ok a b)

@[step] theorem PartialOrdModel.eq_spec (a b : T) :
    inst.partialEqInst.eq a b ⦃ r => r = decide (a ≤ b ∧ b ≤ a) ⦄ :=
  spec_of_eq_ok (PartialOrdModel.eq_ok a b)

end Preorder

section Linear

variable [LinearOrder T] (inst : core.cmp.Ord T) [h : OrdModel inst]

@[step] theorem OrdModel.cmp_spec (a b : T) : inst.cmp a b ⦃ r => r = compare a b ⦄ :=
  spec_of_eq_ok (OrdModel.cmp_ok a b)

@[step] theorem OrdModel.max_spec (a b : T) : inst.max a b ⦃ r => r = max a b ⦄ :=
  spec_of_eq_ok (OrdModel.max_ok a b)

@[step] theorem OrdModel.min_spec (a b : T) : inst.min a b ⦃ r => r = min a b ⦄ :=
  spec_of_eq_ok (OrdModel.min_ok a b)

@[step] theorem OrdModel.core_max_spec (a b : T) : core.cmp.max inst a b ⦃ r => r = max a b ⦄ :=
  spec_of_eq_ok (OrdModel.max_ok a b)

@[step] theorem OrdModel.core_min_spec (a b : T) : core.cmp.min inst a b ⦃ r => r = min a b ⦄ :=
  spec_of_eq_ok (OrdModel.min_ok a b)

@[step] theorem OrdModel.partial_cmp_spec (a b : T) :
    inst.partialOrdInst.partial_cmp a b ⦃ r => r = some (compare a b) ⦄ := by
  have := h.partialOrd
  rw [PartialOrdModel.partial_cmp_ok, partialCompare_eq_compare]
  simp [WP.spec_ok]

@[step] theorem OrdModel.lt_spec (a b : T) : inst.partialOrdInst.lt a b ⦃ r => r = decide (a < b) ⦄ := by
  have := h.partialOrd
  rw [PartialOrdModel.lt_ok]
  simp only [WP.spec_ok]
  exact decide_eq_decide.mpr lt_iff_le_not_ge.symm

@[step] theorem OrdModel.le_spec (a b : T) : inst.partialOrdInst.le a b ⦃ r => r = decide (a ≤ b) ⦄ := by
  have := h.partialOrd
  rw [PartialOrdModel.le_ok]
  simp [WP.spec_ok]

@[step] theorem OrdModel.gt_spec (a b : T) : inst.partialOrdInst.gt a b ⦃ r => r = decide (b < a) ⦄ := by
  have := h.partialOrd
  rw [PartialOrdModel.gt_ok]
  simp only [WP.spec_ok]
  exact decide_eq_decide.mpr lt_iff_le_not_ge.symm

@[step] theorem OrdModel.ge_spec (a b : T) : inst.partialOrdInst.ge a b ⦃ r => r = decide (b ≤ a) ⦄ := by
  have := h.partialOrd
  rw [PartialOrdModel.ge_ok]
  simp [WP.spec_ok]

@[step] theorem OrdModel.partial_eq_spec (a b : T) :
    inst.partialOrdInst.partialEqInst.eq a b ⦃ r => r = decide (a = b) ⦄ := by
  have := h.partialOrd
  rw [PartialOrdModel.eq_ok]
  simp [WP.spec_ok, le_antisymm_iff]

@[step] theorem OrdModel.eq_spec (a b : T) :
    inst.eqInst.partialEqInst.eq a b ⦃ r => r = decide (a = b) ⦄ := by
  have := h.partialEq
  exact spec_of_eq_ok (PartialEqModel.eq_ok a b)

@[step] theorem OrdModel.ne_spec (a b : T) :
    inst.eqInst.partialEqInst.ne a b ⦃ r => r = !decide (a = b) ⦄ := by
  have := h.partialEq
  exact spec_of_eq_ok (PartialEqModel.ne_ok a b)

end Linear

@[step] theorem CloneModel.clone_spec (inst : core.clone.Clone T) [CloneModel inst] (a : T) :
    inst.clone a ⦃ r => r = a ⦄ :=
  spec_of_eq_ok (CloneModel.clone_ok a)

@[step] theorem CloneModel.copy_clone_spec (inst : core.marker.Copy T) [CloneModel inst.cloneInst] (a : T) :
    inst.cloneInst.clone a ⦃ r => r = a ⦄ :=
  spec_of_eq_ok (CloneModel.clone_ok a)

@[step] theorem DefaultModel.default_spec [Inhabited T] (inst : core.default.Default T) [DefaultModel inst] :
    inst.default ⦃ r => r = default ⦄ :=
  spec_of_eq_ok DefaultModel.default_ok

end Step

/-! ## Aeneas's instances -/

theorem UScalar.partialCompare_eq {ty : UScalarTy} (a b : UScalar ty) :
    partialCompare a b = some (compare a.val b.val) := by
  rw [partialCompare_eq_compare]
  simp only [compare, compareOfLessAndEq, UScalar.lt_equiv, UScalar.eq_equiv]

theorem IScalar.partialCompare_eq {ty : IScalarTy} (a b : IScalar ty) :
    partialCompare a b = some (compare a.val b.val) := by
  rw [partialCompare_eq_compare]
  simp only [compare, compareOfLessAndEq, IScalar.lt_equiv, IScalar.eq_equiv]

theorem PartialEqModel.of_decidableEq {T : Type u} {d₁ d₂ : DecidableEq T} {inst : core.cmp.PartialEq T T}
    (h : @PartialEqModel T d₁ inst) : @PartialEqModel T d₂ inst := by
  obtain rfl : d₁ = d₂ := Subsingleton.elim _ _
  exact h

open Lean in
/-- The instances of the classes for Aeneas's instances of the scalar type `S` (`U32`), whose
    lemmas are in the namespace `K` (`UScalar`). -/
local macro "scalar_models " s:ident k:ident : command => do
  let n := s.getId.toString
  let c (pre : Name) (base : String) := mkIdent (pre ++ Name.mkSimple s!"{base}{n}")
  let sub (i : Ident) (x : Name) := mkIdent (i.getId ++ x)
  let pe := c `Aeneas.Std.core.cmp "PartialEq"
  let po := c `Aeneas.Std.core.cmp "PartialOrd"
  let ord := c `Aeneas.Std.core.cmp "Ord"
  let cl := c `Aeneas.Std.core.clone "Clone"
  let cp := c `Aeneas.Std.core.marker "Copy"
  let df := c `Aeneas.Std.core.default "Default"
  let pei := c `Aeneas.Std.core.cmp.impls "PartialEq"
  let poi := c `Aeneas.Std.core.cmp.impls "PartialOrd"
  let ordi := c `Aeneas.Std.core.cmp.impls "Ord"
  let le := sub k `le_equiv
  let lt := sub k `lt_equiv
  let eq := sub k `eq_equiv
  `(instance : PartialEqModel $pe where
      eq_ok a b := by simp only [$pe:ident, liftFun2, $(sub pei `eq):ident]
      ne_ok a b := by simp only [$pe:ident, liftFun2, $(sub pei `ne):ident]; congr 1
    instance : PartialOrdModel $po where
      partial_cmp_ok a b := by
        simp only [$po:ident, liftFun2, $(sub poi `partial_cmp):ident, $(sub k `partialCompare_eq):ident]
      lt_ok a b := by
        simp only [$po:ident, liftFun2, $(sub poi `lt):ident]
        congr 1; apply decide_eq_decide.mpr; simp only [$le:ident]; omega
      le_ok a b := by simp only [$po:ident, liftFun2, $(sub poi `le):ident]; congr 1
      gt_ok a b := by
        simp only [$po:ident, liftFun2, $(sub poi `gt):ident]
        congr 1; apply decide_eq_decide.mpr; simp only [$le:ident]; omega
      ge_ok a b := by simp only [$po:ident, liftFun2, $(sub poi `ge):ident]; congr 1
      eq_ok a b := by
        simp only [$po:ident, $pe:ident, liftFun2, $(sub pei `eq):ident]
        congr 1; apply decide_eq_decide.mpr; simp only [$le:ident, $eq:ident]; omega
    instance : OrdModel $ord where
      cmp_ok a b := by
        simp only [$ord:ident, liftFun2, $(sub ordi `cmp):ident]
        congr 1
        exact Option.some.inj (($(sub k `partialCompare_eq) a b).symm.trans (partialCompare_eq_compare a b))
      max_ok a b := by
        simp only [$ord:ident, liftFun2, $(sub ordi `max):ident, max_def]
        congr 1; split_ifs <;> simp_all [$le:ident, $lt:ident, $eq:ident] <;> omega
      min_ok a b := by
        simp only [$ord:ident, liftFun2, $(sub ordi `min):ident, min_def]
        congr 1; split_ifs <;> simp_all [$le:ident, $lt:ident, $eq:ident] <;> omega
      partialOrd := by show PartialOrdModel $po; exact inferInstance
      partialEq := PartialEqModel.of_decidableEq (inferInstance : PartialEqModel $pe)
    instance : CloneModel $cl := ⟨fun a => by simp [$cl:ident]⟩
    instance : CloneModel ($cp).cloneInst := ⟨fun a => by simp [$cp:ident, $cl:ident]⟩
    instance : DefaultModel $df := ⟨by simp [$df:ident]; rfl⟩)

scalar_models U8 UScalar
scalar_models U16 UScalar
scalar_models U32 UScalar
scalar_models U64 UScalar
scalar_models U128 UScalar
scalar_models Usize UScalar
scalar_models I8 IScalar
scalar_models I16 IScalar
scalar_models I32 IScalar
scalar_models I64 IScalar
scalar_models I128 IScalar
scalar_models Isize IScalar

instance : PartialEqModel core.cmp.PartialEqBool :=
  ⟨fun a b => by simp [core.cmp.impls.PartialEqBool.eq],
   fun a b => by simp [core.cmp.impls.PartialEqBool.eq]⟩

instance : CloneModel core.clone.CloneBool := ⟨fun a => by simp⟩

instance : CloneModel core.marker.CopyBool.cloneInst := ⟨fun a => by simp⟩

instance : PartialEqModel core.cmp.PartialEqUnit :=
  ⟨fun _ _ => by simp [core.cmp.impls.PartialEqUnit.eq],
   fun _ _ => by simp [core.cmp.impls.PartialEqUnit.ne]⟩

instance {T : Type u} (inst : core.clone.Clone T) [CloneModel inst] : CloneModel (core.clone.CloneBox inst) :=
  ⟨fun a => by simp [alloc.boxed.CloneBox.clone, CloneModel.clone_ok]⟩

instance {T : Type u} [DecidableEq T] (inst : core.cmp.PartialEq T T) [PartialEqModel inst] :
    PartialEqModel (core.cmp.PartialEqBox inst) where
  eq_ok a b := by simp [alloc.boxed.PartialEqBox.eq, PartialEqModel.eq_ok]
  ne_ok a b := by simp [alloc.boxed.PartialEqBox.eq, PartialEqModel.eq_ok]


instance {T : Type u} {N : Usize} (inst : core.clone.Clone T) [CloneModel inst] :
    CloneModel (core.clone.CloneArray N inst) where
  clone_ok a := eq_ok_of_spec
    (WP.spec_mono (core.array.CloneArray.clone_spec inst a fun x _ => CloneModel.clone_ok x) fun _ h => h.symm)

theorem allM_ok {α : Type u} (f : α → Result Bool) (g : α → Bool) (hf : ∀ a, f a = ok (g a)) (l : List α) :
    List.allM f l = ok (l.all g) := by
  induction l with
  | nil => rfl
  | cons p l ih =>
    simp only [List.allM, hf, List.all_cons]
    cases g p
    · simp; rfl
    · simpa using ih

theorem anyM_ok {α : Type u} (f : α → Result Bool) (g : α → Bool) (hf : ∀ a, f a = ok (g a)) (l : List α) :
    List.anyM f l = ok (l.any g) := by
  induction l with
  | nil => rfl
  | cons p l ih =>
    simp only [List.anyM, hf, List.any_cons]
    cases g p
    · simpa using ih
    · simp; rfl

instance {T : Type u} (inst : core.clone.Clone T) [CloneModel inst] : CloneModel (core.clone.CloneallocvecVec inst) where
  clone_ok v := by
    have h : Slice.clone inst.clone v.slice = ok v.slice :=
      eq_ok_of_spec (WP.spec_mono (Slice.clone_spec fun x _ => CloneModel.clone_ok x) fun _ h => h.symm)
    simp [alloc.vec.CloneVec.clone, h]

theorem zip_all_eq {T : Type u} [DecidableEq T] (l₁ l₂ : List T) (h : l₁.length = l₂.length) :
    ((l₁.zip l₂).all fun p => decide (p.1 = p.2)) = decide (l₁ = l₂) := by
  induction l₁ generalizing l₂ with
  | nil => cases l₂ <;> simp_all
  | cons a l₁ ih =>
    cases l₂ with
    | nil => simp at h
    | cons b l₂ => simp_all
instance {T : Type u} [DecidableEq T] (inst : core.cmp.PartialEq T T) [PartialEqModel inst] :
    PartialEqModel (core.cmp.PartialEqVec inst) where
  eq_ok a b := by
    simp only [alloc.vec.partial_eq.PartialEqVec.eq]
    split
    · rename_i h
      rw [allM_ok (fun p : T × T => inst.eq p.1 p.2) (fun p => decide (p.1 = p.2)) (fun p => PartialEqModel.eq_ok p.1 p.2),
        zip_all_eq _ _ h]
      exact congrArg ok (decide_eq_decide.mpr (alloc.vec.Vec.eq_iff a b).symm)
    · rename_i h
      exact congrArg ok (by simp only [Bool.false_eq, decide_eq_false_iff_not]; rintro rfl; exact h rfl)
  ne_ok a b := by
    simp only [alloc.vec.partial_eq.PartialEqVec.ne]
    split
    · rename_i h
      rw [anyM_ok (fun p : T × T => inst.ne p.1 p.2) (fun p => !decide (p.1 = p.2)) (fun p => PartialEqModel.ne_ok p.1 p.2),
        List.any_eq_not_all_not]
      simp only [Bool.not_not]
      rw [zip_all_eq _ _ h]
      exact congrArg ok (congrArg (!·) (decide_eq_decide.mpr (alloc.vec.Vec.eq_iff a b).symm))
    · rename_i h
      exact congrArg ok (by simp only [Bool.true_eq, Bool.not_eq_true', decide_eq_false_iff_not]; rintro rfl; exact h rfl)

end LeanRust
