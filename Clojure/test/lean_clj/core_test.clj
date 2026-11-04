(ns lean-clj.core-test
  (:refer-clojure :exclude [double])
  (:require
    [clojure.java.io :as io]
    [clojure.test :as t]
    [lean-clj.core :as lean]))


(lean/deflean arith
              "def double (n : Nat) : Nat := n + n

   theorem double_eq (n : Nat) : double n = 2 * n := by
     unfold double; omega

   def isPrime (n : Nat) : Bool :=
     n ≥ 2 && (List.range (n - 2)).all fun i => n % (i + 2) != 0

   structure Account where
     owner : String
     balance : Nat
     frozen : Bool

   def deposit (a : Account) (amount : Nat) : Account :=
     if a.frozen then a else { a with balance := a.balance + amount }

   theorem deposit_frozen (a : Account) (n : Nat) (h : a.frozen = true) :
       deposit a n = a := by
     simp [deposit, h]

   inductive Suit where
     | hearts | spades
     deriving Repr

   def flip : Suit → Suit
     | .hearts => .spades
     | .spades => .hearts

   def primesBelow (n : Nat) : List Nat := (List.range n).filter isPrime")


(lean/deflean collections
              {:imports ["Std.Data.HashMap"]}
              "def histogram (xs : List String) : List (String × Nat) :=
     let m : Std.HashMap String Nat := xs.foldl (fun m x => m.insert x (m.getD x 0 + 1)) {}
     (m.toArray.qsort (fun a b => a.1 < b.1)).toList

   def safeDiv (a b : Nat) : Option Nat := if b == 0 then none else some (a / b)")


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


(t/deftest deflean-imports
  (t/is (= [["a" 2] ["b" 1]] (vec (histogram ["b" "a" "a"]))))
  (t/is (= 3 (safe-div 7 2)))
  (t/is (nil? (safe-div 7 0))))


(t/deftest deflean-rejects-a-wrong-proof
  (let [e (try
            (lean/expand 'lean-clj.core-test 'wrong {} "theorem bad : 1 + 1 = 3 := by decide")
            nil
            (catch clojure.lang.ExceptionInfo e e))]
    (t/is (some? e))
    (t/is (re-find #"Lean rejected deflean wrong" (ex-message e)))
    (t/is (re-find #"deflean wrong:1:" (ex-message e)))))


(t/deftest deflean-caches-generated-code
  (let [cache (io/file lean/*workspace* "cache")]
    (t/is (seq (.listFiles cache)))
    (t/is (= (lean/expand 'lean-clj.core-test 'arith2 {} "def triple (n : Nat) : Nat := 3 * n")
             (lean/expand 'lean-clj.core-test 'arith2 {} "def triple (n : Nat) : Nat := 3 * n")))))
