(ns lean-clj.core-test
  (:refer-clojure :exclude [double])
  (:require
    [clojure.java.io :as io]
    [clojure.test :as t]
    [lean-clj.core :as lean]))


(lean/deflean arith
              (def double
                [n Nat] Nat
                (+ n n))

              (theorem double_eq [n Nat] (= (double n) (* 2 n))
                       (by (unfold double) omega))

              (def is-prime
                [n Nat] Bool
                (&& (>= n 2)
                    (.all (List.range (- n 2)) (fn [i] (!= (% n (+ i 2)) 0)))))

              (structure Account [owner String balance Nat frozen Bool])

              (def deposit
                [a Account amount Nat] Account
                (if (.frozen a) a (with a {:balance (+ (.balance a) amount)})))

              (theorem deposit_frozen [a Account n Nat h (= (.frozen a) true)]
                       (= (deposit a n) a)
                       (by (simp [deposit h])))

              (inductive Suit hearts spades (deriving Repr))

              (def flip
                [s Suit] Suit
                (match s
                  .hearts .spades
                  .spades .hearts))

              (def primes-below
                [n Nat] (List Nat)
                (.filter (List.range n) is-prime)))


(lean/deflean collections
              {:imports ["Std.Data.HashMap"]}
              (def histogram
                [xs (List String)] (List (Prod String Nat))
                (let [m (the (Std.HashMap String Nat)
                             (.foldl xs (fn [m x] (.insert m x (+ (.getD m x 0) 1))) {}))]
                  (.toList (.qsort (.toArray m) (fn [a b] (< (.fst a) (.fst b)))))))

              "def safeDiv (a b : Nat) : Option Nat :=
     if b == 0 then none else some (a / b)")


(t/deftest deflean-defines-functions
  (t/is (= 42 (double 21)))
  (t/is (true? (is-prime 97)))
  (t/is (false? (is-prime 91)))
  (t/is (= '(2 3 5 7 11 13) (primes-below 15)))
  (t/is (= 123456789012345678901234567890N (double 61728394506172839450617283945N))))


(t/deftest deflean-marshals-structures-and-enums
  (t/is (= {:owner "ann" :balance 15 :frozen false}
           (deposit {:owner "ann" :balance 10 :frozen false} 5)))
  (t/is (= {:owner "bob" :balance 10 :frozen true}
           (deposit {:owner "bob" :balance 10 :frozen true} 5)))
  (t/is (= :spades (flip :hearts))))


(t/deftest deflean-mixes-forms-and-lean-source
  (t/is (= [["a" 2] ["b" 1]] (vec (histogram ["b" "a" "a"]))))
  (t/is (= 3 (safe-div 7 2)))
  (t/is (nil? (safe-div 7 0))))


(t/deftest deflean-rejects-a-wrong-proof
  (let [src (lean/source '[(theorem bad [] (= (+ 1 1) 3) (by decide))])
        e (try
            (lean/expand 'lean-clj.core-test 'wrong {} src)
            nil
            (catch clojure.lang.ExceptionInfo e e))]
    (t/is (some? e))
    (t/is (re-find #"Lean rejected deflean wrong" (ex-message e)))
    (t/is (re-find #"deflean wrong:1:" (ex-message e)))
    (t/is (re-find #"1 \| theorem bad : \(\(1 \+ 1\) = 3\)" (ex-message e)))))


(t/deftest deflean-caches-generated-code
  (let [cache (io/file lean/*workspace* "cache")
        src (lean/source '[(def triple [n Nat] Nat (* 3 n))])]
    (t/is (seq (.listFiles cache)))
    (t/is (= (lean/expand 'lean-clj.core-test 'arith2 {} src)
             (lean/expand 'lean-clj.core-test 'arith2 {} src)))))


(t/deftest module-names-are-lean-module-names
  (t/is (= "LeanCljEmbed.Demo.WordCount.Arith" (lean/module-name 'demo.word-count 'arith)))
  (t/is (= "LeanCljEmbed.Check.SortedMemberQmark" (lean/module-name 'check 'sorted-member?))))
