(ns leanfran.translate-more-test
  "Translations that Lean checks: nil punning, keyword functions, loops,
  local functions, calls of functions from Lean, mutual recursion,
  destructuring, and quoted data."
  (:require
    [clojure.string :as str]
    [clojure.test :as t]
    [leanfran.core :as lean]
    [leanfran.typed :as lt]))


(lean/deflean types
              (structure Account [owner String balance Nat nickname (Option String)])

              (def fee
                [n Nat] Nat
                (+ n 1)))


(lt/defn inc-or-zero
  [x (Option Int)]
  Int
  (if x (inc x) 0))


(lt/defn first-or
  [xs (List Int) d Int]
  Int
  (or (first xs) d))


(lt/defn both
  [a Bool b Bool]
  Bool
  (and a b))


(lt/defn owners
  [as (List Account)]
  (List String)
  (map :owner as))


(lt/defn display-name
  [a Account]
  String
  (or (:nickname a) (:owner a)))


(lt/defn sum-below-plus-one
  [n Nat]
  Nat
  (let [k n]
    (inc (lt/loop ^{:termination-by (- k i) :ret Nat} [i Nat 0 acc Nat 0]
           (if (< i k) (recur (inc i) (+ acc i)) acc)))))


(lt/defn twice-fee
  [n Nat]
  Nat
  (lt/letfn [(add-fee [m Nat] Nat (fee m))]
    (add-fee (add-fee n))))


(declare odd-nat?)


(lt/defn ^{:termination-by (.toNat n)} even-nat?
  [n Int]
  Bool
  (if (<= n 0) true (odd-nat? (dec n))))


(lt/defn ^{:termination-by (.toNat n)} odd-nat?
  [n Int]
  Bool
  (if (<= n 0) false (even-nat? (dec n))))


(lt/defn swap-pair
  [[a b] (Prod Int String)]
  (Prod String Int)
  [b a])


(lt/defn balance-of
  [{:keys [balance]} Account]
  Nat
  balance)


(lt/defn head-or-zero
  [xs (List Int)]
  Int
  (let [[a] xs] (or a 0)))


(lt/defn small-primes
  []
  (List Nat)
  '(2 3 5 7))


(lt/defn biggest
  [a Int b Int c Int]
  Int
  (max a b c))


(lean/deflean checks {:use [types]}
              (clojure inc-or-zero first-or both owners display-name sum-below-plus-one twice-fee
                       swap-pair balance-of head-or-zero small-primes biggest)

              (theorem inc-or-zero-some [x Int] (= (inc-or-zero (some x)) (+ x 1))
                       (by (simp [inc-or-zero])))

              (theorem owners-length [as (List Account)] (= (.length (owners as)) (.length as))
                       (by (simp [owners])))

              (theorem swap-swaps [a Int b String] (= (swap-pair (<> a b)) (<> b a))
                       (by (simp [swap-pair]))))


(t/deftest translated-functions-agree-with-their-models
  (doseq [v [#'inc-or-zero #'first-or #'both #'sum-below-plus-one #'twice-fee #'swap-pair
             #'head-or-zero #'biggest #'owners #'display-name #'balance-of]]
    (t/is (:pass? (lt/check v {:seed 3})) (str v))))


(t/deftest mutual-recursion-is-translated
  (t/is (:pass? (lt/check #'even-nat? {:seed 3 :num-tests 30}))))


(t/deftest quoted-data
  (t/is (= '(2 3 5 7) (small-primes))))


(lt/defn total
  [xs (List Int)]
  Int
  (reduce + xs))


(lt/defn total-by-apply
  [xs (Array Int)]
  Int
  (apply + xs))


(lt/defn inc-twice-all
  [xs (List Int)]
  (List Int)
  (map (comp inc inc) xs))


(lt/defn add-to-all
  [n Int xs (List Int)]
  (List Int)
  (map (partial + n) xs))


(lt/defn richest-first
  [as (List Account)]
  (List String)
  (map :owner (reverse (sort-by :balance as))))


(lt/defn shout
  [words (List String)]
  String
  (str/upper-case (str/join " " words)))


(lt/defn csv-fields
  [line String]
  (Array String)
  (mapv str/trim (str/split line #",")))


(t/deftest phase-three-translations-agree
  (doseq [v [#'total #'total-by-apply #'inc-twice-all #'add-to-all #'richest-first #'shout #'csv-fields]]
    (t/is (:pass? (lt/check v {:seed 5})) (str v))))
