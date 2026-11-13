(ns verified.sort
  "Insertion sort written in Clojure, with Lean proofs that `insert-sorted`
  keeps the elements and the order, and that `sort-ints` returns a sorted list."
  (:require
    [leanfran.core :refer [deflean]]
    [leanfran.typed :as lt]))


(lt/defn insert-sorted
  "Insert `x` into the sorted list `xs`."
  [x Int xs (List Int)]
  (List Int)
  (if-let [y (first xs)]
    (if (<= x y)
      (cons x xs)
      (cons y (insert-sorted x (rest xs))))
    (list x)))


(lt/defn sort-ints
  "The integers of `xs` in ascending order."
  [xs (Array Int)]
  (List Int)
  (reduce (fn [acc x] (insert-sorted x acc)) () xs))


(deflean proofs
  (clojure sort-ints)

  (theorem insert-sorted-nil [x Int] (= (insert-sorted x []) [x])
           (by (simp [insert-sorted])))

  (theorem insert-sorted-cons [x Int y Int t (List Int)]
           (= (insert-sorted x (cons y t)) (if (<= x y) (cons x (cons y t)) (cons y (insert-sorted x t))))
           (by (rw [insert-sorted]) simp))

  (theorem mem-insert-sorted [x Int w Int xs (List Int)]
           (iff (in w (insert-sorted x xs)) (or (= w x) (in w xs)))
           (by (induction xs)
               (case nil [] (simp [insert-sorted-nil]))
               (case cons [y t ih] (rw [insert-sorted-cons]) (on-all split (simp [ih]) grind))))

  (theorem insert-sorted-sorted [x Int xs (List Int) h (.Pairwise xs (fn [a b] (<= a b)))]
           (.Pairwise (insert-sorted x xs) (fn [a b] (<= a b)))
           (by (induction xs)
               (case nil [] (simp [insert-sorted-nil]))
               (case cons [y t ih]
                     (rw [insert-sorted-cons])
                     (rw [List.pairwise_cons] at h)
                     split
                     (case isTrue [hxy]
                           (refine (List.Pairwise.cons ?_ (List.Pairwise.cons (.1 h) (.2 h))))
                           (intro a ha)
                           "rcases List.mem_cons.mp ha with rfl | ha"
                           (case inl [] (exact hxy))
                           (case inr [] (exact (Int.le_trans hxy (.1 h a ha)))))
                     (case isFalse [hxy]
                           (refine (List.Pairwise.cons ?_ (ih (.2 h))))
                           (intro a ha)
                           "rcases (memInsertSorted x a t).mp ha with rfl | ha"
                           (case inl [] omega)
                           (case inr [] (exact (.1 h a ha)))))))

  (theorem sort-ints-sorted [xs (Array Int)] (.Pairwise (sort-ints xs) (fn [a b] (<= a b)))
           (by (simp only [sort-ints Clj.reduce_eq Clj.toList_array])
               "suffices ∀ (l acc : List Int), acc.Pairwise (· ≤ ·) → (l.foldl (fun acc x => insertSorted x acc) acc).Pairwise (· ≤ ·) from this _ _ List.Pairwise.nil"
               (intro l)
               (induction l)
               (case nil [] simp)
               (case cons [a l ih] (intro acc h) (exact (ih _ (insert-sorted-sorted a acc h)))))))
