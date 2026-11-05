(ns lean-clj.typed-test
  (:require
    [clojure.test :as t]
    [clojure.test.check.generators :as gen]
    [lean-clj.typed :as lt]
    [lean-clj.types :as types]))


(lt/defn ^{:termination-by (count xs)} sum-list
  "Sum of a list."
  [xs (List Int)]
  Int
  (if-let [x (first xs)]
    (+ x (sum-list (rest xs)))
    0))


(lt/defn count-up
  [n Nat]
  Nat
  (lt/loop [i Nat 0 acc Nat 0]
    (if (< i n) (recur (inc i) (+ acc i)) acc)))


(t/deftest defn-runs-as-clojure
  (t/is (= 6 (sum-list '(1 2 3))))
  (t/is (= 10 (count-up 5)))
  (t/is (= "Sum of a list." (:doc (meta #'sum-list)))))


(t/deftest defn-records-the-signature
  (let [sig (:lean/sig (meta #'sum-list))]
    (t/is (= '[xs (List Int)] (:binders sig)))
    (t/is (= 'Int (:ret sig)))
    (t/is (= 'lean-clj.typed-test (:ns sig)))
    (t/is (= '(count xs) (:termination-by sig)))
    (t/is (= '(if-let [x (first xs)] (+ x (sum-list (rest xs))) 0) (:body sig))))
  (t/is (not (contains? (meta #'sum-list) :termination-by))))


(t/deftest defn-rejects-a-malformed-signature
  (t/is (thrown? clojure.lang.Compiler$CompilerException
          (eval '(lean-clj.typed/defn bad
                   [x]
                   Int x)))))


(t/deftest generators-follow-the-type
  (types/register-commands! '[(structure Account [owner String balance Nat])
                              (namespace Cards (inductive Suit hearts spades (deriving Repr)))])
  (let [sample #(gen/sample (types/gen %) 50)]
    (t/is (every? #(and (integer? %) (not (neg? %))) (sample 'Nat)))
    (t/is (some #(instance? clojure.lang.BigInt %) (gen/sample (types/gen 'Nat) 300)))
    (t/is (every? list? (sample '(List Int))))
    (t/is (every? vector? (sample '(Array Bool))))
    (t/is (every? #(or (nil? %) (string? %)) (sample '(Option String))))
    (t/is (every? #(and (vector? %) (= 2 (count %))) (sample '(Prod Nat Char))))
    (t/is (every? #(and (= #{:owner :balance} (set (keys %))) (string? (:owner %))) (sample 'Account)))
    (t/is (every? #{:hearts :spades} (sample 'Suit)))
    (t/is (thrown? clojure.lang.ExceptionInfo (types/gen '(Option (Option Nat)))))
    (t/is (thrown? clojure.lang.ExceptionInfo (types/gen 'Unknown)))))


(t/deftest kebab-matches-the-generated-names
  (t/is (= "owner-name" (types/kebab "ownerName")))
  (t/is (= "http-server" (types/kebab "HTTPServer")))
  (t/is (= "x1-y" (types/kebab "x1Y"))))


(lt/defn clamp
  [lo Int hi Int x Int]
  Int
  (max lo (min hi x)))


(lt/defn wrong-kind
  [xs (List Int)]
  (Array Int)
  (map inc xs))


(t/deftest check-compares-the-function-with-its-model
  (t/is (:pass? (lt/check #'clamp {:seed 1})))
  (with-redefs [clamp (fn [_ _ x] x)]
    (t/is (not (:pass? (lt/check #'clamp {:seed 1})))))
  (t/is (thrown-with-msg? clojure.lang.ExceptionInfo #"Lean rejected" (lt/check #'wrong-kind))))
