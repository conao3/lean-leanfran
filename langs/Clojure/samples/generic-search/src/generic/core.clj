(ns generic.core
  "A membership test for any element type, a function with two arities, and
  one with rest arguments, written in Clojure and proved in Lean."
  (:require
    [leanfran.core :refer [deflean]]
    [leanfran.typed :as lt]))


(lt/defn member?
  "Whether `x` is in `xs`, for any element type with equality."
  [(implicit α Type) (inst (BEq α)) x α xs (List α)]
  Bool
  (if-some [y (first xs)]
    (or (= x y) (member? x (rest xs)))
    false))


(lt/defn clamp
  "`x` within `[lo, hi]`, or within `[0, 100]`."
  ([x Int] Int (clamp x 0 100))
  ([x Int lo Int hi Int] Int (max lo (min hi x))))


(lt/defn total
  "The sum of all arguments."
  [x Int & more (List Int)]
  Int
  (reduce + x more))


(deflean proofs
  (clojure member? clamp total)

  (theorem member-head [(implicit α Type) (inst (BEq α)) (inst (LawfulBEq α)) (inst (Clj.Truthy α)) x α xs (List α)]
           (= (member? x (cons x xs)) true)
           (by (rw [member?]) simp))

  (theorem member-nil [(implicit α Type) (inst (BEq α)) (inst (Clj.Truthy α)) x α]
           (= (member? x []) false)
           (by (simp [member?])))

  (theorem clamp-in-range [x Int lo Int hi Int h (<= lo hi)]
           (and (<= lo (clamp.arity3 x lo hi)) (<= (clamp.arity3 x lo hi) hi))
           (by (simp [clamp.arity3]) omega))

  (theorem total-nil [x Int] (= (total x []) x)
           (by (simp [total]))))
