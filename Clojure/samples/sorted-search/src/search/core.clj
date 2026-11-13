(ns search.core
  "Membership in a sorted list that stops at the first larger element, proved
  equal to `List.contains` for sorted lists."
  (:require
    [leanfran.core :refer [deflean]]
    [leanfran.typed :as lt]))


(lt/defn sorted-member?
  "Whether `x` is in `xs`, assuming `xs` is sorted in ascending order."
  [x Int xs (List Int)]
  Bool
  (if-let [y (first xs)]
    (cond
      (= x y) true
      (< x y) false
      :else (sorted-member? x (rest xs)))
    false))


(deflean proofs
  (clojure sorted-member?)

  (theorem sorted-member-eq [x Int xs (List Int) h (.Pairwise xs (fn [a b] (<= a b)))]
           (= (sorted-member? x xs) (.contains xs x))
           (by (induction xs)
               (case nil [] (simp [sorted-member?]))
               (case cons [y t ih]
                     (rw [List.pairwise_cons] at h)
                     (rw [sorted-member?])
                     simp
                     "by_cases hxy : x = y <;> by_cases hlt : x < y <;> simp_all <;> grind"))))
