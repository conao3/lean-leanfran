(ns lean-clj.core-model-test
  "Each model in `Clj` against the `clojure.core` function it describes, on
  the same generated inputs. A call where Clojure throws is outside what the
  models describe and counts as agreeing."
  (:require
    [clojure.test :as t]
    [clojure.test.check :as tc]
    [clojure.test.check.generators :as gen]
    [clojure.test.check.properties :as prop]
    [lean-clj.core :as lean]
    [lean-clj.types :as types]))


(defmacro ^:private defmodels
  "A deflean block of `(def name binders ret body)` and `models`, the table of
  each generated function next to the Clojure function and argument types."
  [block & entries]
  `(do (lean/deflean ~block {:imports ["Clj"]}
                     ~@(for [[nm bs ret body] entries] (list 'def nm bs ret body)))
       (def ~'models
         ~(vec (for [[nm bs _ _ f gens] entries]
                 {:name (list 'quote nm)
                  :model nm
                  :clj f
                  :types (list 'quote (vec (take-nth 2 (rest bs))))
                  :gens gens})))))


(def ^:private small-nat (gen/choose 0 40))


(declare models)


#_{:clj-kondo/ignore [:unresolved-symbol :unresolved-var]}


(defmodels core-model
  (add-int [a Int b Int] Int (Clj.add a b) +)
  (add-nat [a Nat b Nat] Nat (Clj.add a b) +)
  (sub-int [a Int b Int] Int (Clj.sub a b) -)
  (neg-int [a Int] Int (Clj.neg a) -)
  (mul-int [a Int b Int] Int (Clj.mul a b) *)
  (inc-nat [a Nat] Nat (Clj.inc a) inc)
  (dec-int [a Int] Int (Clj.dec a) dec)
  (quot-int [a Int b Int] Int (Clj.quot a b) quot)
  (rem-int [a Int b Int] Int (Clj.rem a b) rem)
  (mod-int [a Int b Int] Int (Clj.mod a b) mod)
  (quot-nat [a Nat b Nat] Nat (Clj.quot a b) quot)
  (mod-nat [a Nat b Nat] Nat (Clj.mod a b) mod)
  (lt-int [a Int b Int] Bool (Clj.lt a b) <)
  (le-int [a Int b Int] Bool (Clj.le a b) <=)
  (gt-nat [a Nat b Nat] Bool (Clj.gt a b) >)
  (ge-nat [a Nat b Nat] Bool (Clj.ge a b) >=)
  (max-int [a Int b Int] Int (Clj.max a b) max)
  (min-nat [a Nat b Nat] Nat (Clj.min a b) min)
  (zero-int [a Int] Bool (Clj.zero? a) zero?)
  (pos-int [a Int] Bool (Clj.pos? a) pos?)
  (negative-int [a Int] Bool (Clj.neg? a) neg?)
  (pos-nat [a Nat] Bool (Clj.pos? a) pos?)
  (even-int [a Int] Bool (Clj.even? a) even?)
  (odd-int [a Int] Bool (Clj.odd? a) odd?)
  (eq-list [a (List Int) b (List Int)] Bool (Clj.eq a b) =)
  (eq-string [a String b String] Bool (Clj.eq a b) =)
  (not-eq-int [a Int b Int] Bool (Clj.notEq a b) not=)
  (not-option [a (Option Int)] Bool (Clj.not a) not)
  (not-bool [a Bool] Bool (Clj.not a) not)
  (not-int [a Int] Bool (Clj.not a) not)
  (nil-option [a (Option Int)] Bool (Clj.nil? a) nil?)
  (some-option [a (Option Int)] Bool (Clj.some? a) some?)
  (nil-int [a Int] Bool (Clj.nil? a) nil?)
  (first-list [xs (List Int)] (Option Int) (Clj.first xs) first)
  (first-array [xs (Array Int)] (Option Int) (Clj.first xs) first)
  (rest-array [xs (Array Int)] (List Int) (Clj.rest xs) rest)
  (next-list [xs (List Int)] (Option (List Int)) (Clj.next xs) next)
  (seq-array [xs (Array Int)] (Option (List Int)) (Clj.seq xs) seq)
  (count-array [xs (Array Int)] Nat (Clj.count xs) count)
  (count-list [xs (List Bool)] Nat (Clj.count xs) count)
  (empty-list [xs (List Int)] Bool (Clj.empty? xs) empty?)
  (map-inc [xs (Array Int)] (List Int) (Clj.map (fn [x] (Clj.inc x)) xs) #(map inc %))
  (filter-even [xs (List Int)] (List Int) (Clj.filter (fn [x] (Clj.even? x)) xs) #(filter even? %))
  (filter-option [xs (List (Option Int))] (List (Option Int)) (Clj.filter (fn [x] x) xs) #(filter identity %))
  (remove-even [xs (Array Int)] (List Int) (Clj.remove (fn [x] (Clj.even? x)) xs) #(remove even? %))
  (reduce-add [xs (Array Int)] Int (Clj.reduce (fn [acc x] (Clj.add acc x)) 0 xs) #(reduce + 0 %))
  (take-list [n Nat xs (List Int)] (List Int) (Clj.take n xs) take)
  (drop-array [n Nat xs (Array Int)] (List Int) (Clj.drop n xs) drop)
  (reverse-array [xs (Array Int)] (List Int) (Clj.reverse xs) reverse)
  (vec-list [xs (List Int)] (Array Int) (Clj.vec xs) vec)
  (cons-array [x Int xs (Array Int)] (List Int) (Clj.cons x xs) cons)
  (concat-list-array [xs (List Int) ys (Array Int)] (List Int) (Clj.concat xs ys) concat)
  (nth-list [xs (List Int) i Nat] Int (Clj.nth xs i) nth)
  (nth3-array [xs (Array Int) i Nat d Int] Int (Clj.nth3 xs i d) nth)
  (range-nat [n Nat] (List Nat) (Clj.range n) range [small-nat])
  (range2-nat [a Nat b Nat] (List Nat) (Clj.range2 a b) range [small-nat small-nat])
  (conj-list [xs (List Int) x Int] (List Int) (Clj.conj xs x) conj)
  (conj-array [xs (Array Int) x Int] (Array Int) (Clj.conj xs x) conj)
  (into-vector [to (Array Int) xs (List Int)] (Array Int) (Clj.into to xs) into)
  (into-list [to (List Int) xs (Array Int)] (List Int) (Clj.into to xs) into)
  (get-array [xs (Array Int) i Nat] (Option Int) (Clj.get xs i) get)
  (contains-array [xs (Array Int) i Nat] Bool (Clj.contains? xs i) contains?)
  (str-int [a Int] String (Clj.str a) str)
  (str-bool [a Bool] String (Clj.str a) str)
  (str-char [a Char] String (Clj.str a) str)
  (str-option [a (Option String)] String (Clj.str a) str))


(defn- agrees?
  [model clj args]
  (let [expected (apply model args)]
    (try
      (= (apply clj args) expected)
      (catch Exception _ true))))


(t/deftest models-agree-with-clojure-core
  (doseq [{:keys [name model clj types gens]} models]
    (let [g (apply gen/tuple (or gens (map types/gen types)))
          r (tc/quick-check 200 (prop/for-all [args g] (agrees? model clj args)) :seed 42)]
      (t/is (:pass? r) (str name " disagrees on " (pr-str (-> r :shrunk :smallest)))))))
