(ns leanfran.verify-test
  (:require
    [clojure.test :as t]
    [leanfran.core :as lean]
    [leanfran.typed :as lt]))


(lt/defn insert-sorted
  [x Int xs (List Int)]
  (List Int)
  (if-let [y (first xs)]
    (if (<= x y)
      (cons x xs)
      (cons y (insert-sorted x (rest xs))))
    (list x)))


(lt/defn sort-ints
  [xs (Array Int)]
  (List Int)
  (reduce (fn [acc x] (insert-sorted x acc)) () xs))


(lt/defn sum-to-fast
  [n Nat]
  Nat
  (quot (* n (inc n)) 2))


(lt/defn count-below
  [n Nat]
  Nat
  (lt/loop ^{:termination-by (- n i)} [i Nat 0 acc Nat 0]
    (if (< i n) (recur (inc i) (+ acc i)) acc)))


(lean/deflean sorting
              (clojure sort-ints count-below)

              (theorem insert-sorted-length [x Int xs (List Int)]
                       (= (.length (insert-sorted x xs)) (+ (.length xs) 1))
                       (by (on-all (fun-induction insert-sorted x xs) simp-all grind)))

              (def sorted-length
                [xs (Array Int)] Nat
                (.length (sort-ints xs))))


(lean/deflean sums
              (clojure sum-to-fast)

              (def sum-to
                [n Nat] Nat
                (match n
                  0 0
                  (+ k 1) (+ (sum-to k) (+ k 1))))

              (theorem two-sum-to [n Nat] (= (* 2 (sum-to n)) (* n (+ n 1)))
                       (by (on-all (induction n) (simp only [sum-to Nat.mul_add Nat.add_mul] at *) omega)))

              (theorem sum-to-fast-eq [n Nat] (= (sum-to-fast n) (sum-to n))
                       (by (simp only [sum-to-fast Clj.quot_nat Clj.mul_nat Clj.inc_nat])
                           "have := twoSumTo n"
                           omega))

              (theorem ^{:attrs [csimp]} sum-to-eq [] (= (the (-> Nat Nat) sum-to) sum-to-fast)
                       (by (funext n) (exact (.symm (sum-to-fast-eq n)))))

              (def sum-twice
                [n Nat] Nat
                (+ (sum-to n) (sum-to n))))


(t/deftest models-are-not-public
  (t/is (= '(1 2 3) (sort-ints [3 1 2])))
  (t/is (= 3 (sorted-length [3 1 2])))
  (t/is (= 10 (count-below 5))))


(t/deftest lean-calls-the-clojure-function
  (with-redefs [sort-ints (fn [_] '(7))]
    (t/is (= 1 (sorted-length [3 1 2])))))


(t/deftest csimp-runs-the-clojure-implementation
  (t/is (= 5000050000 (sum-to 100000)))
  (t/is (= 110 (sum-twice 10)))
  (with-redefs [sum-to-fast (fn [_] 100)]
    (t/is (= 100 (sum-to 3)))
    (t/is (= 200 (sum-twice 3)))))


(t/deftest helpers-stay-private
  (t/is (nil? (resolve 'count-below-loop1)))
  (t/is (nil? (resolve 'count-below.loop1))))
