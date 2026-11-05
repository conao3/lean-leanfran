(ns lean-clj.core-test
  (:refer-clojure :exclude [double])
  (:require
    [clojure.java.io :as io]
    [clojure.java.shell]
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
  (let [src (lean/source *ns* 'wrong '[(theorem bad [] (= (+ 1 1) 3) (by decide))] true)
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
        src (lean/source *ns* 'arith2 '[(def triple [n Nat] Nat (* 3 n))] true)]
    (t/is (seq (.listFiles cache)))
    (t/is (= (lean/expand 'lean-clj.core-test 'arith2 {} src)
             (lean/expand 'lean-clj.core-test 'arith2 {} src)))))


(t/deftest module-names-are-lean-module-names
  (t/is (= "LeanCljEmbed.Demo.WordCount.Arith" (lean/module-name 'demo.word-count 'arith)))
  (t/is (= "LeanCljEmbed.Check.SortedMemberQMARK" (lean/module-name 'check 'sorted-member?))))


(t/deftest module-names-keep-inner-capitals
  (t/is (= "LeanCljEmbed.My.FooBarNs.CacheB" (lean/module-name 'my.FooBar-ns 'cacheB))))


(lean/deflean shared-types
              (structure Point [x Int y Int]))


(lean/deflean uses-shared {:use [shared-types]}
              (def norm1
                [p Point] Int
                (+ (.x p) (.y p))))


(t/deftest blocks-share-definitions-through-use
  (t/is (= 7 (norm1 {:x 3 :y 4})))
  (t/is (= "LeanCljEmbed.LeanClj.CoreTest.UsesShared.norm1" (:lean/name (meta #'norm1))))
  (t/is (= "LeanCljEmbed.LeanClj.CoreTest.UsesShared" (:lean/module (meta #'norm1)))))


(t/deftest the-cache-follows-imported-blocks
  (let [a (lean/source *ns* 'cache-a '[(def k [] Nat 1)] true)
        a' (lean/source *ns* 'cache-a '[(def k [] Nat 10)] true)
        b (lean/source *ns* 'cache-b '[(def k2 [] Nat (+ k 1))] true)
        opts (lean/options (the-ns 'lean-clj.core-test) {:use '[cache-a]} [])
        run (fn []
              (let [forms (lean/expand 'lean-clj.core-test 'cache-b opts b)]
                (binding [*ns* (create-ns 'lean-clj.core-test.cache)]
                  (refer-clojure)
                  (doseq [f forms] (eval f))
                  ((ns-resolve 'lean-clj.core-test.cache 'k2)))))]
    (lean/expand 'lean-clj.core-test 'cache-a {} a)
    (t/is (= 2 (run)))
    (lean/expand 'lean-clj.core-test 'cache-a {} a')
    (t/is (= 11 (run)))))


(t/deftest lean-errors-point-at-the-clojure-file
  (let [e (try
            (eval '(lean-clj.core/deflean bad-line
                                          (def ok [] Nat 1)
                                          (theorem bad [] (= (+ 1 1) 3) (by decide))))
            nil
            (catch clojure.lang.Compiler$CompilerException e (ex-cause e)))]
    (t/is (re-find #"NO_SOURCE_\w+:\d+: deflean bad-line:3:" (ex-message e)))))


(t/deftest unexportable-definitions-are-reported
  (let [err (java.io.StringWriter.)]
    (binding [*err* err]
      (eval '(lean-clj.core/deflean poly-skip
                                    (def ^:private unused [] Nat 0)
                                    (def my-member
                                      [(implicit α Type) (inst (BEq α)) x α xs (List α)] Bool
                                      (.contains xs x)))))
    (t/is (re-find #"deflean poly-skip: skipped .*myMember" (str err)))))


(t/deftest the-cli-generates-a-lake-project
  (let [out "test-out/project"
        {:keys [exit err]} (clojure.java.shell/sh "lean-clj" "project" "generate"
                                                  "--lake-dir" "samples/roman-numerals/lean"
                                                  "--namespace-prefix" "gen"
                                                  "--output-dir" out)]
    (t/is (zero? exit) err)
    (load-file (str out "/gen/roman.clj"))
    (t/is (= "MCMXCIV" ((resolve 'gen.roman/to-roman) 1994)))))
