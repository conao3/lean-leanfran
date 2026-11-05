/-!
# Models of `clojure.core`

Each Clojure function is a Lean function in the namespace `Clj`. A function
that Clojure applies to several kinds of values goes through a type class whose
instances are the types on which Lean can state what Clojure does: `Sub` has an
`Int` instance and no `Nat` one, because `(- 3 5)` is `-2`.

The models describe the values a Clojure function returns. Where Clojure throws
(`ArithmeticException` on `Long` overflow or division by zero, an index out of
range), the model returns some value, and lean-clj's theorems are about the
calls that return.
-/

namespace Clj

/-! ## Truthiness and `nil` -/

class Truthy (α : Type u) where
  truthy : α → Bool

export Truthy (truthy)

instance (priority := low) : Truthy α := ⟨fun _ => true⟩
instance : Truthy Bool := ⟨id⟩
instance : Truthy (Option α) := ⟨Option.isSome⟩

@[simp] theorem truthy_bool (b : Bool) : truthy b = b := rfl
@[simp] theorem truthy_none : truthy (none : Option α) = false := rfl
@[simp] theorem truthy_some (a : α) : truthy (some a) = true := rfl

class IsNil (α : Type u) where
  isNil : α → Bool

instance (priority := low) : IsNil α := ⟨fun _ => false⟩
instance : IsNil (Option α) := ⟨Option.isNone⟩

def «nil?» [IsNil α] (x : α) : Bool := IsNil.isNil x
def «some?» [IsNil α] (x : α) : Bool := !IsNil.isNil x
def not [Truthy α] (x : α) : Bool := !truthy x

@[simp] theorem nil?_option (x : Option α) : «nil?» x = x.isNone := rfl
@[simp] theorem some?_option (x : Option α) : «some?» x = x.isSome := by
  cases x <;> rfl
@[simp] theorem not_eq [Truthy α] (x : α) : not x = !truthy x := rfl

/-! ## Equality -/

def eq [BEq α] (a b : α) : Bool := a == b
def notEq [BEq α] (a b : α) : Bool := !(a == b)

@[simp] theorem eq_eq [BEq α] (a b : α) : eq a b = (a == b) := rfl
@[simp] theorem notEq_eq [BEq α] (a b : α) : notEq a b = !(a == b) := rfl

/-! ## Integers

`Arith` covers the operations whose Clojure result on non-negative integers is
a non-negative integer. `Sub` (`-`, `dec`) is for `Int` only. -/

class Arith (α : Type) where
  add : α → α → α
  mul : α → α → α
  inc : α → α
  quot : α → α → α
  rem : α → α → α
  mod : α → α → α
  lt : α → α → Bool
  le : α → α → Bool
  max : α → α → α
  min : α → α → α
  zero? : α → Bool
  pos? : α → Bool
  neg? : α → Bool
  even? : α → Bool

instance : Arith Nat where
  add := Nat.add
  mul := Nat.mul
  inc n := n + 1
  quot := Nat.div
  rem := Nat.mod
  mod := Nat.mod
  lt a b := decide (a < b)
  le a b := decide (a ≤ b)
  max := Nat.max
  min := Nat.min
  zero? n := n == 0
  pos? n := n != 0
  neg? _ := false
  even? n := n % 2 == 0

instance : Arith Int where
  add := Int.add
  mul := Int.mul
  inc n := n + 1
  quot := Int.tdiv
  rem := Int.tmod
  mod := Int.fmod
  lt a b := decide (a < b)
  le a b := decide (a ≤ b)
  max := Max.max
  min := Min.min
  zero? n := n == 0
  pos? n := decide (0 < n)
  neg? n := decide (n < 0)
  even? n := n % 2 == 0

class Sub (α : Type) where
  sub : α → α → α
  neg : α → α
  dec : α → α

instance : Sub Int where
  sub := Int.sub
  neg := Int.neg
  dec n := n - 1

export Arith (add mul inc quot rem mod lt le max min zero? pos? neg? even?)
export Sub (sub neg dec)

def gt [Arith α] (a b : α) : Bool := lt b a
def ge [Arith α] (a b : α) : Bool := le b a
def odd? [Arith α] (n : α) : Bool := !even? n

section
variable (a b : Nat)
@[simp] theorem add_nat : add a b = a + b := rfl
@[simp] theorem mul_nat : mul a b = a * b := rfl
@[simp] theorem inc_nat : inc a = a + 1 := rfl
@[simp] theorem quot_nat : quot a b = a / b := rfl
@[simp] theorem rem_nat : rem a b = a % b := rfl
@[simp] theorem mod_nat : mod a b = a % b := rfl
@[simp] theorem lt_nat : lt a b = decide (a < b) := rfl
@[simp] theorem le_nat : le a b = decide (a ≤ b) := rfl
@[simp] theorem max_nat : max a b = Max.max a b := rfl
@[simp] theorem min_nat : min a b = Min.min a b := rfl
@[simp] theorem zero?_nat : zero? a = (a == 0) := rfl
@[simp] theorem pos?_nat : pos? a = (a != 0) := rfl
@[simp] theorem neg?_nat : neg? a = false := rfl
@[simp] theorem even?_nat : even? a = (a % 2 == 0) := rfl
end

section
variable (a b : Int)
@[simp] theorem add_int : add a b = a + b := rfl
@[simp] theorem mul_int : mul a b = a * b := rfl
@[simp] theorem inc_int : inc a = a + 1 := rfl
@[simp] theorem quot_int : quot a b = a.tdiv b := rfl
@[simp] theorem rem_int : rem a b = a.tmod b := rfl
@[simp] theorem mod_int : mod a b = a.fmod b := rfl
@[simp] theorem lt_int : lt a b = decide (a < b) := rfl
@[simp] theorem le_int : le a b = decide (a ≤ b) := rfl
@[simp] theorem max_int : max a b = Max.max a b := rfl
@[simp] theorem min_int : min a b = Min.min a b := rfl
@[simp] theorem zero?_int : zero? a = (a == 0) := rfl
@[simp] theorem pos?_int : pos? a = decide (0 < a) := rfl
@[simp] theorem neg?_int : neg? a = decide (a < 0) := rfl
@[simp] theorem even?_int : even? a = (a % 2 == 0) := rfl
@[simp] theorem sub_int : sub a b = a - b := rfl
@[simp] theorem neg_int : neg a = -a := rfl
@[simp] theorem dec_int : dec a = a - 1 := rfl
end

@[simp] theorem gt_eq [Arith α] (a b : α) : gt a b = lt b a := rfl
@[simp] theorem ge_eq [Arith α] (a b : α) : ge a b = le b a := rfl
@[simp] theorem odd?_eq [Arith α] (a : α) : odd? a = !even? a := rfl

/-! ## Sequences

Clojure's sequence functions take any collection. `Seqable` gives the elements
of a `List` or an `Array` in order, and the functions return what Clojure
returns: a seq (`List`) from `map`, a vector (`Array`) from `vec`. -/

class Seqable (c : Type u) (α : outParam (Type u)) where
  toList : c → List α

export Seqable (toList)

instance : Seqable (List α) α := ⟨id⟩
instance : Seqable (Array α) α := ⟨Array.toList⟩

@[simp] theorem toList_list (xs : List α) : toList xs = xs := rfl
@[simp] theorem toList_array (xs : Array α) : toList xs = xs.toList := rfl

variable [Seqable c α]

def first (x : c) : Option α := (toList x).head?
def rest (x : c) : List α := (toList x).tail
def next (x : c) : Option (List α) :=
  match (toList x).tail with
  | [] => none
  | t => some t
def seq (x : c) : Option (List α) :=
  match toList x with
  | [] => none
  | xs => some xs
def count (x : c) : Nat := (toList x).length
def «empty?» (x : c) : Bool := (toList x).isEmpty
def map (f : α → β) (x : c) : List β := (toList x).map f
def filter [Truthy β] (p : α → β) (x : c) : List α := (toList x).filter fun a => truthy (p a)
def remove [Truthy β] (p : α → β) (x : c) : List α := (toList x).filter fun a => !truthy (p a)
def reduce (f : β → α → β) (init : β) (x : c) : β := (toList x).foldl f init
def take (n : Nat) (x : c) : List α := (toList x).take n
def drop (n : Nat) (x : c) : List α := (toList x).drop n
def reverse (x : c) : List α := (toList x).reverse
def vec (x : c) : Array α := (toList x).toArray
def cons (a : α) (x : c) : List α := a :: toList x
def concat [Seqable d α] (x : c) (y : d) : List α := toList x ++ toList y
def nth [Inhabited α] (x : c) (i : Nat) : α := (toList x)[i]?.getD default
def nth3 (x : c) (i : Nat) (notFound : α) : α := (toList x)[i]?.getD notFound

@[simp] theorem first_eq (x : c) : first x = (toList x).head? := rfl
@[simp] theorem rest_eq (x : c) : rest x = (toList x).tail := rfl
@[simp] theorem count_eq (x : c) : count x = (toList x).length := rfl
@[simp] theorem empty?_eq (x : c) : «empty?» x = (toList x).isEmpty := rfl
@[simp] theorem map_eq (f : α → β) (x : c) : map f x = (toList x).map f := rfl
@[simp] theorem filter_eq [Truthy β] (p : α → β) (x : c) :
    filter p x = (toList x).filter fun a => truthy (p a) := rfl
@[simp] theorem remove_eq [Truthy β] (p : α → β) (x : c) :
    remove p x = (toList x).filter fun a => !truthy (p a) := rfl
@[simp] theorem reduce_eq (f : β → α → β) (init : β) (x : c) :
    reduce f init x = (toList x).foldl f init := rfl
@[simp] theorem take_eq (n : Nat) (x : c) : take n x = (toList x).take n := rfl
@[simp] theorem drop_eq (n : Nat) (x : c) : drop n x = (toList x).drop n := rfl
@[simp] theorem reverse_eq (x : c) : reverse x = (toList x).reverse := rfl
@[simp] theorem vec_eq (x : c) : vec x = (toList x).toArray := rfl
@[simp] theorem cons_eq (a : α) (x : c) : cons a x = a :: toList x := rfl
@[simp] theorem concat_eq [Seqable d α] (x : c) (y : d) : concat x y = toList x ++ toList y := rfl
@[simp] theorem nth3_eq (x : c) (i : Nat) (d : α) : nth3 x i d = (toList x)[i]?.getD d := rfl

@[simp] theorem next_eq (x : c) :
    next x = if (toList x).tail = [] then none else some (toList x).tail := by
  unfold next; split <;> simp_all

@[simp] theorem seq_eq (x : c) :
    seq x = if toList x = [] then none else some (toList x) := by
  unfold seq; split <;> simp_all

theorem count_rest_lt {x : c} {a : α} (h : first x = some a) : count (rest x) < count x := by
  simp only [first_eq, count_eq, rest_eq, toList_list] at *
  cases hx : toList x with
  | nil => simp [hx] at h
  | cons _ t => simp

theorem count_next_lt {x : c} {t : List α} (h : next x = some t) : count t < count x := by
  simp only [next_eq, count_eq, toList_list] at *
  split at h
  · simp at h
  · cases h
    cases hx : toList x with
    | nil => simp_all
    | cons _ t => simp

def range (n : Nat) : List Nat := List.range n
def range2 (a b : Nat) : List Nat := List.range' a (b - a)

@[simp] theorem range_eq (n : Nat) : range n = List.range n := rfl
@[simp] theorem range2_eq (a b : Nat) : range2 a b = List.range' a (b - a) := rfl

/-! ## Collections -/

class Conj (c : Type u) (α : outParam (Type u)) where
  conj : c → α → c

export Conj (conj)

instance : Conj (List α) α := ⟨fun xs a => a :: xs⟩
instance : Conj (Array α) α := ⟨Array.push⟩

@[simp] theorem conj_list (xs : List α) (a : α) : conj xs a = a :: xs := rfl
@[simp] theorem conj_array (xs : Array α) (a : α) : conj xs a = xs.push a := rfl

def into [Conj d α] (to : d) (x : c) : d := (toList x).foldl conj to

@[simp] theorem into_eq [Conj d α] (to : d) (x : c) : into to x = (toList x).foldl conj to := rfl

class Get (c : Type u) (k : Type v) (α : outParam (Type w)) where
  get : c → k → Option α
  contains : c → k → Bool

/-- The index Clojure uses for an integer key of a vector: `intValue`, the low
    32 bits as a signed `int`, with negative indices missing. -/
def intIndex (i : Nat) : Option Nat :=
  let m := i % 2 ^ 32
  if m < 2 ^ 31 then some m else none

@[simp] theorem intIndex_small {i : Nat} (h : i < 2 ^ 31) : intIndex i = some i := by
  unfold intIndex
  have : i % 2 ^ 32 = i := Nat.mod_eq_of_lt (by omega)
  simp [this, h]

instance : Get (Array α) Nat α where
  get xs i := (intIndex i).bind fun m => xs[m]?
  contains xs i := match intIndex i with
    | some m => decide (m < xs.size)
    | none => false

def get [Get c' k β] (x : c') (i : k) : Option β := Get.get x i
def «contains?» [Get c' k β] (x : c') (i : k) : Bool := Get.contains x i

@[simp] theorem get_array {xs : Array α} {i : Nat} (h : i < 2 ^ 31) : get xs i = xs[i]? := by
  simp [get, Get.get, intIndex_small h]
@[simp] theorem contains?_array {xs : Array α} {i : Nat} (h : i < 2 ^ 31) :
    «contains?» xs i = decide (i < xs.size) := by
  simp [«contains?», Get.contains, intIndex_small h]

/-! ## Strings -/

class Str (α : Type u) where
  str : α → String

instance : Str String := ⟨id⟩
instance : Str Nat := ⟨toString⟩
instance : Str Int := ⟨toString⟩
instance : Str Bool := ⟨fun b => if b then "true" else "false"⟩
instance : Str Char := ⟨String.singleton⟩
instance [Str α] : Str (Option α) := ⟨fun | none => "" | some a => Str.str a⟩

def str [Str α] (x : α) : String := Str.str x

@[simp] theorem str_string (s : String) : str s = s := rfl

end Clj

/-- Termination of recursion on `(rest xs)` or `(next xs)` under
    `(if-let [y (first xs)] ...)` and `(if-let [t (next xs)] ...)`. -/
macro_rules
  | `(tactic| decreasing_trivial) =>
    `(tactic| (have := Clj.count_rest_lt ‹Clj.first _ = some _›; simp_all <;> omega))
macro_rules
  | `(tactic| decreasing_trivial) =>
    `(tactic| (have := Clj.count_next_lt ‹Clj.next _ = some _›; simp_all <;> omega))
macro_rules
  | `(tactic| decreasing_trivial) => `(tactic| (simp_all <;> omega))
