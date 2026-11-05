(ns lean-clj.poly-test
  "Polymorphic functions, several arities, and rest arguments."
  (:require
    [clojure.test :as t]
    [lean-clj.core :as lean]
    [lean-clj.typed :as lt]
    [lean-clj.types :as types]))


(lt/defn member?
  [(implicit α Type) (inst (BEq α)) x α xs (List α)]
  Bool
  (if-let [y (first xs)]
    (or (= x y) (member? x (rest xs)))
    false))


(lt/defn clamp
  ([x Int] Int (clamp x 0 100))
  ([x Int lo Int hi Int] Int (max lo (min hi x))))


(lt/defn total
  [base Int & more (List Int)]
  Int
  (reduce + base more))


(lt/defn uses-member
  [xs (List String)]
  Bool
  (member? "a" xs))


(lean/deflean proofs
              (clojure member? clamp total uses-member)

              (theorem member-nil [(implicit α Type) (inst (BEq α)) x α] (= (member? x []) false)
                       (by (simp [member?])))

              (theorem clamp-default [x Int] (= (clamp.arity1 x) (clamp.arity3 x 0 100))
                       (by (simp [clamp.arity1])))

              (theorem total-nil [b Int] (= (total b []) b)
                       (by (simp [total Clj.reduce_eq]))))


(lean/deflean generic
              (def first-or
                [(implicit α Type) xs (List α) d α] α
                (.getD (.head? xs) d))

              (export first-or {:at {α Int}})
              (export first-or {:at {α String} :as first-or-string}))


(t/deftest calls-run-as-clojure
  (t/is (true? (member? 2 [1 2 3])))
  (t/is (= 100 (clamp 300)))
  (t/is (= 6 (total 1 2 3)))
  (t/is (= 1 (total 1)))
  (t/is (true? (uses-member ["b" "a"]))))


(t/deftest checks-per-arity-and-instantiation
  (t/is (:pass? (lt/check #'member? {:seed 2})))
  (t/is (:pass? (lt/check #'member? {:seed 2 :at '{α String}})))
  (t/is (:pass? (lt/check #'clamp {:seed 2})))
  (t/is (:pass? (lt/check #'total {:seed 2})))
  (t/is (:pass? (lt/check #'uses-member {:seed 2}))))


(t/deftest exported-instances
  (t/is (= 1 (first-or-int [1 2] 0)))
  (t/is (= 0 (first-or-int [] 0)))
  (t/is (= "x" (first-or-string [] "x"))))


(t/deftest schemas-per-arity
  (t/is (= [:function [:=> [:cat 'integer?] 'integer?] [:=> [:cat 'integer? 'integer? 'integer?] 'integer?]]
           (types/fn-schema #'clamp)))
  (t/is (= [:=> [:cat 'integer? [:* 'integer?]] 'integer?] (types/fn-schema #'total)))
  (t/is (= [:=> [:cat :any [:sequential :any]] :boolean] (types/fn-schema #'member?)))
  (let [cfg (get-in (types/kondo-config [(the-ns 'lean-clj.poly-test)])
                    [:linters :type-mismatch :namespaces 'lean-clj.poly-test])]
    (t/is (= #{1 3} (set (keys (:arities (get cfg 'clamp))))))
    (t/is (= 1 (get-in cfg ['total :arities :varargs :min-arity])))))
