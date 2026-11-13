(ns verified.sum
  "The sum 0 + 1 + ... + n: a specification in Lean, a closed form in Clojure,
  and a `@[csimp]` proof that they are equal, so that the specification runs as
  the closed form."
  (:require
    [leanfran.core :refer [deflean]]
    [leanfran.typed :as lt]))


(lt/defn sum-to-fast
  "0 + 1 + ... + n in closed form."
  [n Nat]
  Nat
  (quot (* n (inc n)) 2))


(deflean sums
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
           (by (funext n) (exact (.symm (sum-to-fast-eq n))))))
