import Clj.Attr

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

@[simp, clj_simp] theorem truthy_bool (b : Bool) : truthy b = b := rfl
@[simp, clj_simp] theorem truthy_none : truthy (none : Option α) = false := rfl
@[simp, clj_simp] theorem truthy_some (a : α) : truthy (some a) = true := rfl
@[simp, clj_simp] theorem truthy_nat (a : Nat) : truthy a = true := rfl
@[simp, clj_simp] theorem truthy_int (a : Int) : truthy a = true := rfl
@[simp, clj_simp] theorem truthy_string (a : String) : truthy a = true := rfl
@[simp, clj_simp] theorem truthy_char (a : Char) : truthy a = true := rfl
@[simp, clj_simp] theorem truthy_list (a : List α) : truthy a = true := rfl
@[simp, clj_simp] theorem truthy_array (a : Array α) : truthy a = true := rfl

class IsNil (α : Type u) where
  isNil : α → Bool

instance (priority := low) : IsNil α := ⟨fun _ => false⟩
instance : IsNil (Option α) := ⟨Option.isNone⟩

def «nil?» [IsNil α] (x : α) : Bool := IsNil.isNil x
def «some?» [IsNil α] (x : α) : Bool := !IsNil.isNil x
def not [Truthy α] (x : α) : Bool := !truthy x

@[simp, clj_simp] theorem nil?_option (x : Option α) : «nil?» x = x.isNone := rfl
@[simp, clj_simp] theorem some?_option (x : Option α) : «some?» x = x.isSome := by
  cases x <;> rfl
@[simp, clj_simp] theorem not_eq [Truthy α] (x : α) : not x = !truthy x := rfl

/-- The value of `x` where it is truthy: the element of `some`, and other
    values as they are. A Clojure local tested by `if` stands for this in the
    branch where it is truthy. -/
class Unwrap (α : Type u) (β : outParam (Type u)) [Truthy α] where
  unwrap : (x : α) → truthy x = true → β

instance (priority := low) [Truthy α] : Unwrap α α := ⟨fun x _ => x⟩
instance : Unwrap (Option α) α := ⟨fun x h => x.get (by simpa [Truthy.truthy] using h)⟩

@[simp, clj_simp] theorem unwrap_some (a : α) (h : truthy (some a) = true) : Unwrap.unwrap (some a) h = a := rfl

/-! ## Equality -/

def eq [BEq α] (a b : α) : Bool := a == b
def notEq [BEq α] (a b : α) : Bool := !(a == b)

@[simp, clj_simp] theorem eq_eq [BEq α] (a b : α) : eq a b = (a == b) := rfl
@[simp, clj_simp] theorem notEq_eq [BEq α] (a b : α) : notEq a b = !(a == b) := rfl

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

/-- Truncation of a quotient toward zero, as `quot` on doubles. -/
def truncF (x : Float) : Float := if x < 0 then x.ceil else x.floor

/-- `Float` follows IEEE 754 as Java's doubles do. `even?` on a double throws
    in Clojure, so its model value is outside what the theorems cover. -/
instance : Arith Float where
  add := Float.add
  mul := Float.mul
  inc x := x + 1
  quot a b := truncF (a / b)
  rem a b := a - b * truncF (a / b)
  mod a b :=
    let m := a - b * truncF (a / b)
    if m == 0 || decide (0 < a) == decide (0 < b) then m else m + b
  lt a b := decide (a < b)
  le a b := decide (a ≤ b)
  max a b := if a < b then b else a
  min a b := if b < a then b else a
  zero? x := x == 0
  pos? x := decide (0 < x)
  neg? x := decide (x < 0)
  even? _ := false

instance : Sub Float where
  sub := Float.sub
  neg := Float.neg
  dec x := x - 1

/-- `/` on doubles. On integers Clojure returns ratios, which have no model. -/
class Div (α : Type) where
  div : α → α → α

instance : Div Float := ⟨Float.div⟩

def div [Div α] (a b : α) : α := Div.div a b

export Arith (add mul inc quot rem mod lt le max min zero? pos? neg? even?)
export Sub (sub neg dec)

def gt [Arith α] (a b : α) : Bool := lt b a
def ge [Arith α] (a b : α) : Bool := le b a
def odd? [Arith α] (n : α) : Bool := !even? n

section
variable (a b : Nat)
@[simp, clj_simp] theorem add_nat : add a b = a + b := rfl
@[simp, clj_simp] theorem mul_nat : mul a b = a * b := rfl
@[simp, clj_simp] theorem inc_nat : inc a = a + 1 := rfl
@[simp, clj_simp] theorem quot_nat : quot a b = a / b := rfl
@[simp, clj_simp] theorem rem_nat : rem a b = a % b := rfl
@[simp, clj_simp] theorem mod_nat : mod a b = a % b := rfl
@[simp, clj_simp] theorem lt_nat : lt a b = decide (a < b) := rfl
@[simp, clj_simp] theorem le_nat : le a b = decide (a ≤ b) := rfl
@[simp, clj_simp] theorem max_nat : max a b = Max.max a b := rfl
@[simp, clj_simp] theorem min_nat : min a b = Min.min a b := rfl
@[simp, clj_simp] theorem zero?_nat : zero? a = (a == 0) := rfl
@[simp, clj_simp] theorem pos?_nat : pos? a = (a != 0) := rfl
@[simp, clj_simp] theorem neg?_nat : neg? a = false := rfl
@[simp, clj_simp] theorem even?_nat : even? a = (a % 2 == 0) := rfl
end

section
variable (a b : Int)
@[simp, clj_simp] theorem add_int : add a b = a + b := rfl
@[simp, clj_simp] theorem mul_int : mul a b = a * b := rfl
@[simp, clj_simp] theorem inc_int : inc a = a + 1 := rfl
@[simp, clj_simp] theorem quot_int : quot a b = a.tdiv b := rfl
@[simp, clj_simp] theorem rem_int : rem a b = a.tmod b := rfl
@[simp, clj_simp] theorem mod_int : mod a b = a.fmod b := rfl
@[simp, clj_simp] theorem lt_int : lt a b = decide (a < b) := rfl
@[simp, clj_simp] theorem le_int : le a b = decide (a ≤ b) := rfl
@[simp, clj_simp] theorem max_int : max a b = Max.max a b := rfl
@[simp, clj_simp] theorem min_int : min a b = Min.min a b := rfl
@[simp, clj_simp] theorem zero?_int : zero? a = (a == 0) := rfl
@[simp, clj_simp] theorem pos?_int : pos? a = decide (0 < a) := rfl
@[simp, clj_simp] theorem neg?_int : neg? a = decide (a < 0) := rfl
@[simp, clj_simp] theorem even?_int : even? a = (a % 2 == 0) := rfl
@[simp, clj_simp] theorem sub_int : sub a b = a - b := rfl
@[simp, clj_simp] theorem neg_int : neg a = -a := rfl
@[simp, clj_simp] theorem dec_int : dec a = a - 1 := rfl
end

@[simp, clj_simp] theorem gt_eq [Arith α] (a b : α) : gt a b = lt b a := rfl
@[simp, clj_simp] theorem ge_eq [Arith α] (a b : α) : ge a b = le b a := rfl
@[simp, clj_simp] theorem odd?_eq [Arith α] (a : α) : odd? a = !even? a := rfl

/-! ## Sequences

Clojure's sequence functions take any collection. `Seqable` gives the elements
of a `List` or an `Array` in order, and the functions return what Clojure
returns: a seq (`List`) from `map`, a vector (`Array`) from `vec`. -/

class Seqable (c : Type u) (α : outParam (Type u)) where
  toList : c → List α

export Seqable (toList)

instance : Seqable (List α) α := ⟨id⟩
instance : Seqable (Array α) α := ⟨Array.toList⟩

@[simp, clj_simp] theorem toList_list (xs : List α) : toList xs = xs := rfl
@[simp, clj_simp] theorem toList_array (xs : Array α) : toList xs = xs.toList := rfl

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
def nthrest (x : c) (n : Nat) : List α := (toList x).drop n
def nthnext (x : c) (n : Nat) : Option (List α) :=
  match (toList x).drop n with
  | [] => none
  | t => some t

@[simp, clj_simp] theorem first_eq (x : c) : first x = (toList x).head? := rfl
@[simp, clj_simp] theorem rest_eq (x : c) : rest x = (toList x).tail := rfl
@[simp, clj_simp] theorem count_eq (x : c) : count x = (toList x).length := rfl
@[simp, clj_simp] theorem empty?_eq (x : c) : «empty?» x = (toList x).isEmpty := rfl
@[simp, clj_simp] theorem map_eq (f : α → β) (x : c) : map f x = (toList x).map f := rfl
@[simp, clj_simp] theorem filter_eq [Truthy β] (p : α → β) (x : c) :
    filter p x = (toList x).filter fun a => truthy (p a) := rfl
@[simp, clj_simp] theorem remove_eq [Truthy β] (p : α → β) (x : c) :
    remove p x = (toList x).filter fun a => !truthy (p a) := rfl
@[simp, clj_simp] theorem reduce_eq (f : β → α → β) (init : β) (x : c) :
    reduce f init x = (toList x).foldl f init := rfl
@[simp, clj_simp] theorem take_eq (n : Nat) (x : c) : take n x = (toList x).take n := rfl
@[simp, clj_simp] theorem drop_eq (n : Nat) (x : c) : drop n x = (toList x).drop n := rfl
@[simp, clj_simp] theorem reverse_eq (x : c) : reverse x = (toList x).reverse := rfl
@[simp, clj_simp] theorem vec_eq (x : c) : vec x = (toList x).toArray := rfl
@[simp, clj_simp] theorem cons_eq (a : α) (x : c) : cons a x = a :: toList x := rfl
@[simp, clj_simp] theorem concat_eq [Seqable d α] (x : c) (y : d) : concat x y = toList x ++ toList y := rfl
@[simp, clj_simp] theorem nth3_eq (x : c) (i : Nat) (d : α) : nth3 x i d = (toList x)[i]?.getD d := rfl
@[simp, clj_simp] theorem nthrest_eq (x : c) (n : Nat) : nthrest x n = (toList x).drop n := rfl
@[simp, clj_simp] theorem nthnext_eq (x : c) (n : Nat) :
    nthnext x n = if (toList x).drop n = [] then none else some ((toList x).drop n) := by
  unfold nthnext; split <;> simp_all

@[simp, clj_simp] theorem next_eq (x : c) :
    next x = if (toList x).tail = [] then none else some (toList x).tail := by
  unfold next; split <;> simp_all

@[simp, clj_simp] theorem seq_eq (x : c) :
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

@[grind →] theorem length_pos_of_head? {xs : List α} {a : α} (h : xs.head? = some a) : 0 < xs.length := by
  cases xs <;> simp_all

theorem sizeOf_tail_lt [SizeOf α] {xs : List α} {a : α} (h : xs.head? = some a) : sizeOf xs.tail < sizeOf xs := by
  cases xs with
  | nil => simp at h
  | cons _ t => simp; omega

theorem sizeOf_next_lt [SizeOf α] {xs : List α} {t : List α} (h : next xs = some t) : sizeOf t < sizeOf xs := by
  simp only [next_eq, toList_list] at h
  split at h
  · simp at h
  · cases h
    cases xs with
    | nil => simp_all
    | cons _ t => simp; omega

def range (n : Nat) : List Nat := List.range n
def range2 (a b : Nat) : List Nat := List.range' a (b - a)

@[simp, clj_simp] theorem range_eq (n : Nat) : range n = List.range n := rfl
@[simp, clj_simp] theorem range2_eq (a b : Nat) : range2 a b = List.range' a (b - a) := rfl

/-! ## Collections -/

/-- A two-element vector literal: a pair, or a vector of two elements. -/
class Vec2 (α : Type u) (β : Type v) (γ : Type w) where
  vec2 : α → β → γ

instance : Vec2 α β (α × β) := ⟨Prod.mk⟩
@[default_instance] instance : Vec2 α α (Array α) := ⟨fun a b => #[a, b]⟩

def vec2 [Vec2 α β γ] (a : α) (b : β) : γ := Vec2.vec2 a b

@[simp, clj_simp] theorem vec2_pair (a : α) (b : β) : (vec2 a b : α × β) = (a, b) := rfl
@[simp, clj_simp] theorem vec2_array (a b : α) : (vec2 a b : Array α) = #[a, b] := rfl

/-- Element `i` of a destructured sequential value: the components of a pair,
    and `Option` elements of a list or vector, which Clojure binds to `nil`
    past the end. -/
class Pos (c : Type u) (i : Nat) (β : outParam (Type v)) where
  pos : c → β

instance : Pos (α × β) 0 α := ⟨Prod.fst⟩
instance : Pos (α × β) 1 β := ⟨Prod.snd⟩
instance (priority := low) [Seqable c α] : Pos c i (Option α) := ⟨fun x => (toList x)[i]?⟩

def elem (i : Nat) [Pos c i β] (x : c) : β := Pos.pos (i := i) x

@[simp, clj_simp] theorem elem_fst (p : α × β) : elem 0 p = p.1 := rfl
@[simp, clj_simp] theorem elem_snd (p : α × β) : elem 1 p = p.2 := rfl
@[simp, clj_simp] theorem elem_list (i : Nat) (xs : List α) : elem i xs = xs[i]? := rfl
@[simp, clj_simp] theorem elem_array (i : Nat) (xs : Array α) : elem i xs = xs.toList[i]? := rfl

class Conj (c : Type u) (α : outParam (Type u)) where
  conj : c → α → c

export Conj (conj)

instance : Conj (List α) α := ⟨fun xs a => a :: xs⟩
instance : Conj (Array α) α := ⟨Array.push⟩

@[simp, clj_simp] theorem conj_list (xs : List α) (a : α) : conj xs a = a :: xs := rfl
@[simp, clj_simp] theorem conj_array (xs : Array α) (a : α) : conj xs a = xs.push a := rfl

def into [Conj d α] (to : d) (x : c) : d := (toList x).foldl conj to

@[simp, clj_simp] theorem into_eq [Conj d α] (to : d) (x : c) : into to x = (toList x).foldl conj to := rfl

class Get (c : Type u) (k : Type v) (α : outParam (Type w)) where
  get : c → k → Option α
  contains : c → k → Bool

/-- The index Clojure uses for an integer key of a vector: `intValue`, the low
    32 bits as a signed `int`, with negative indices missing. -/
def intIndex (i : Nat) : Option Nat :=
  let m := i % 2 ^ 32
  if m < 2 ^ 31 then some m else none

@[simp, clj_simp] theorem intIndex_small {i : Nat} (h : i < 2 ^ 31) : intIndex i = some i := by
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

@[simp, clj_simp] theorem get_array {xs : Array α} {i : Nat} (h : i < 2 ^ 31) : get xs i = xs[i]? := by
  simp [get, Get.get, intIndex_small h]
@[simp, clj_simp] theorem contains?_array {xs : Array α} {i : Nat} (h : i < 2 ^ 31) :
    «contains?» xs i = decide (i < xs.size) := by
  simp [«contains?», Get.contains, intIndex_small h]

/-! ## More sequence functions -/

/-- A value as Clojure's `keep` and `some` see it: `nil` for `none`, and other
    values as they are. -/
class Opt (β : Type u) (γ : outParam (Type u)) where
  opt : β → Option γ

instance : Opt (Option γ) γ := ⟨id⟩
instance (priority := low) : Opt β β := ⟨some⟩

@[simp, clj_simp] theorem opt_option (x : Option γ) : Opt.opt x = x := rfl

def someBy [Truthy β] (p : α → β) (x : c) : Option β := ((toList x).map p).find? truthy
def «every?» [Truthy β] (p : α → β) (x : c) : Bool := (toList x).all fun a => truthy (p a)
def «notEvery?» [Truthy β] (p : α → β) (x : c) : Bool := !(toList x).all fun a => truthy (p a)
def «notAny?» [Truthy β] (p : α → β) (x : c) : Bool := !(toList x).any fun a => truthy (p a)
def mapcat [Seqable d β] (f : α → d) (x : c) : List β := (toList x).flatMap fun a => toList (f a)
def keep [Opt β γ] (f : α → β) (x : c) : List γ := (toList x).filterMap fun a => Opt.opt (f a)
def mapIndexed (f : Nat → α → β) (x : c) : List β := ((toList x).zipIdx).map fun (a, i) => f i a
def keepIndexed [Opt β γ] (f : Nat → α → β) (x : c) : List γ :=
  ((toList x).zipIdx).filterMap fun (a, i) => Opt.opt (f i a)
def last (x : c) : Option α := (toList x).getLast?
def butlast (x : c) : Option (List α) :=
  match (toList x).dropLast with
  | [] => none
  | t => some t
def takeWhile [Truthy β] (p : α → β) (x : c) : List α := (toList x).takeWhile fun a => truthy (p a)
def dropWhile [Truthy β] (p : α → β) (x : c) : List α := (toList x).dropWhile fun a => truthy (p a)
def splitAt (n : Nat) (x : c) : List α × List α := ((toList x).take n, (toList x).drop n)
def interpose (sep : α) (x : c) : List α := (toList x).intersperse sep
def interleave [Seqable d α] (x : c) (y : d) : List α :=
  ((toList x).zip (toList y)).flatMap fun (a, b) => [a, b]
def distinct [BEq α] (x : c) : List α := (toList x).eraseDups
def mapv (f : α → β) (x : c) : Array β := ((toList x).map f).toArray
def filterv [Truthy β] (p : α → β) (x : c) : Array α := ((toList x).filter fun a => truthy (p a)).toArray
def reduce1 [Inhabited α] (f : α → α → α) (x : c) : α :=
  match toList x with
  | [] => default
  | a :: t => t.foldl f a

/-- Chunks of `n` elements; `partition` drops a shorter last chunk. Clojure
    does not return for `n = 0`. -/
def chunks (n : Nat) : List α → List (List α)
  | [] => []
  | xs@(_ :: _) => if _h : n = 0 then [] else xs.take n :: chunks n (xs.drop n)
termination_by xs => xs.length
decreasing_by simp_all; omega

def partitionAll (n : Nat) (x : c) : List (List α) := chunks n (toList x)
def partition (n : Nat) (x : c) : List (List α) := (chunks n (toList x)).filter fun p => p.length == n

@[simp, clj_simp] theorem someBy_eq [Truthy β] (p : α → β) (x : c) : someBy p x = ((toList x).map p).find? truthy := rfl
@[simp, clj_simp] theorem every?_eq [Truthy β] (p : α → β) (x : c) : «every?» p x = (toList x).all fun a => truthy (p a) := rfl
@[simp, clj_simp] theorem mapcat_eq [Seqable d β] (f : α → d) (x : c) : mapcat f x = (toList x).flatMap fun a => toList (f a) := rfl
@[simp, clj_simp] theorem keep_eq [Opt β γ] (f : α → β) (x : c) : keep f x = (toList x).filterMap fun a => Opt.opt (f a) := rfl
@[simp, clj_simp] theorem last_eq (x : c) : last x = (toList x).getLast? := rfl
@[simp, clj_simp] theorem takeWhile_eq [Truthy β] (p : α → β) (x : c) : takeWhile p x = (toList x).takeWhile fun a => truthy (p a) := rfl
@[simp, clj_simp] theorem dropWhile_eq [Truthy β] (p : α → β) (x : c) : dropWhile p x = (toList x).dropWhile fun a => truthy (p a) := rfl
@[simp, clj_simp] theorem splitAt_eq (n : Nat) (x : c) : splitAt n x = ((toList x).take n, (toList x).drop n) := rfl
@[simp, clj_simp] theorem distinct_eq [BEq α] (x : c) : distinct x = (toList x).eraseDups := rfl
@[simp, clj_simp] theorem mapv_eq (f : α → β) (x : c) : mapv f x = ((toList x).map f).toArray := rfl

/-- Clojure's `compare` on the types whose order Lean states the same way. -/
class Compare (α : Type u) where
  lt : α → α → Bool

instance : Compare Nat := ⟨fun a b => decide (a < b)⟩
instance : Compare Int := ⟨fun a b => decide (a < b)⟩
instance : Compare Bool := ⟨fun a b => !a && b⟩
instance : Compare Char := ⟨fun a b => decide (a < b)⟩
instance : Compare String := ⟨fun a b => decide (a < b)⟩

/-- `sort` is stable, as Clojure's: equal elements keep their order. -/
def sort [Compare α] (x : c) : List α := (toList x).mergeSort fun a b => !Compare.lt b a
def sortBy [Compare β] (k : α → β) (x : c) : List α := (toList x).mergeSort fun a b => !Compare.lt (k b) (k a)
def maxKey [Compare β] (k : α → β) (a b : α) : α := if Compare.lt (k b) (k a) then a else b
def minKey [Compare β] (k : α → β) (a b : α) : α := if Compare.lt (k a) (k b) then a else b

/-- `not-empty`: the collection, or `nil` when it is empty. -/
def notEmpty (x : c) : Option c := if (toList x).isEmpty then none else some x

class Empty (c : Type u) where
  empty : c → c

instance : Empty (List α) := ⟨fun _ => []⟩
instance : Empty (Array α) := ⟨fun _ => #[]⟩

def empty [Empty c'] (x : c') : c' := Empty.empty x

def subvec (v : Array α) (start stop : Nat) : Array α := v.extract start stop

/-! ## Strings -/

class Str (α : Type u) where
  str : α → String

/-- Clojure's `pr-str`: how `str` prints the elements of a vector. -/
class Pr (α : Type u) where
  pr : α → String

def escapeChar : Char → String
  | '"' => "\\\""
  | '\\' => "\\\\"
  | '\n' => "\\n"
  | '\t' => "\\t"
  | '\r' => "\\r"
  | c => String.singleton c

instance : Pr String := ⟨fun s => "\"" ++ String.join (s.toList.map escapeChar) ++ "\""⟩
/-- Clojure prints a `BigInt` with `N`. The models take an integer in the
    `Long` range to be a `Long`, as the values lean-clj passes are. -/
def prInt (n : Int) : String :=
  if -9223372036854775808 ≤ n ∧ n ≤ 9223372036854775807 then toString n else toString n ++ "N"

instance : Pr Nat := ⟨fun n => prInt n⟩
instance : Pr Int := ⟨prInt⟩
instance : Pr Bool := ⟨fun b => if b then "true" else "false"⟩
instance [Pr α] : Pr (Option α) := ⟨fun | none => "nil" | some a => Pr.pr a⟩
instance [Pr α] : Pr (Array α) := ⟨fun xs => "[" ++ " ".intercalate (xs.toList.map Pr.pr) ++ "]"⟩

instance : Str String := ⟨id⟩
instance : Str Nat := ⟨toString⟩
instance : Str Int := ⟨toString⟩
instance : Str Bool := ⟨fun b => if b then "true" else "false"⟩
instance : Str Char := ⟨String.singleton⟩
instance [Str α] : Str (Option α) := ⟨fun | none => "" | some a => Str.str a⟩
instance [Pr α] : Str (Array α) := ⟨Pr.pr⟩

def str [Str α] (x : α) : String := Str.str x

@[simp, clj_simp] theorem str_string (s : String) : str s = s := rfl

instance : Seqable String Char := ⟨String.toList⟩

@[simp, clj_simp] theorem toList_string (s : String) : toList s = s.toList := rfl

/-- `subs` by character index. Clojure indexes UTF-16 code units, which agree
    with characters in the Basic Multilingual Plane. -/
def subs (s : String) (start stop : Nat) : String := String.ofList ((s.toList.drop start).take (stop - start))
def subsFrom (s : String) (start : Nat) : String := String.ofList (s.toList.drop start)

namespace Str'

/-- `Character/isWhitespace` on the ASCII range, as `clojure.string` uses it. -/
def isWhitespace (c : Char) : Bool :=
  c == ' ' || (c.toNat ≥ 9 && c.toNat ≤ 13) || (c.toNat ≥ 28 && c.toNat ≤ 31)

/-- `clojure.string`'s case conversion on ASCII letters. Java also converts
    letters beyond ASCII, which these models leave as they are. -/
def upperCase (s : String) : String := String.ofList (s.toList.map Char.toUpper)
def lowerCase (s : String) : String := String.ofList (s.toList.map Char.toLower)
def trim (s : String) : String :=
  String.ofList (((s.toList.dropWhile isWhitespace).reverse.dropWhile isWhitespace).reverse)
def triml (s : String) : String := String.ofList (s.toList.dropWhile isWhitespace)
def trimr (s : String) : String := String.ofList ((s.toList.reverse.dropWhile isWhitespace).reverse)
def blank? (s : Option String) : Bool :=
  match s with
  | none => true
  | some s => s.toList.all isWhitespace
def startsWith? (s pre : String) : Bool := pre.toList.isPrefixOf s.toList
def endsWith? (s suf : String) : Bool := suf.toList.isSuffixOf s.toList
def includes? (s sub : String) : Bool := (s.splitOn sub).length > 1 || sub.isEmpty
def join (sep : String) [Str α] (x : c) : String := sep.intercalate ((toList x).map Str.str)
def join1 [Str α] (x : c) : String := String.join ((toList x).map Str.str)
/-- `split` on a regular expression of plain characters, which removes the
    trailing empty strings as Java's `String.split` does. -/
def split (s sep : String) : Array String :=
  if s.isEmpty then #[""]
  else ((s.splitOn sep).reverse.dropWhile String.isEmpty).reverse.toArray
def replace (s match_ replacement : String) : String :=
  if match_.isEmpty then String.join (s.toList.map fun c => replacement ++ c.toString) ++ replacement
  else replacement.intercalate (s.splitOn match_)

end Str'

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
  | `(tactic| decreasing_trivial) =>
    `(tactic| (simp only [Clj.first_eq, Clj.rest_eq, Clj.toList_list] at *; exact Clj.sizeOf_tail_lt ‹_›))
macro_rules
  | `(tactic| decreasing_trivial) => `(tactic| exact Clj.sizeOf_next_lt ‹_›)
macro_rules
  | `(tactic| decreasing_trivial) => `(tactic| (simp_all <;> omega))
