(ns lean-clj.values-test
  "Sum types, Except, maps, sets, and Fin passed between Clojure and Lean,
  and translated Clojure code on maps and sets."
  (:require
    [clojure.test :as t]
    [clojure.test.check.generators :as gen]
    [lean-clj.core :as lean]
    [lean-clj.typed :as lt]
    [lean-clj.types :as types]
    [malli.core :as m]))


(lean/deflean shapes {:imports ["Clj"]}
              (inductive Shape (circle [r Nat]) (rect [w Nat h Nat]) dot (deriving Repr BEq))

              (def area
                [s Shape] Nat
                (match s
                  (.circle r) (* 3 (* r r))
                  (.rect w h) (* w h)
                  .dot 0))

              (def grow
                [s Shape] Shape
                (match s
                  (.circle r) (Shape.circle (+ r 1))
                  (.rect w h) (Shape.rect (+ w 1) (+ h 1))
                  .dot .dot))

              (def safe-div
                [a Nat b Nat] (Except String Nat)
                (if (= b 0) (Except.error "division by zero") (Except.ok (/ a b))))

              (def tally
                [xs (List String)] (Clj.Map String Nat)
                (Clj.frequencies xs))

              (def evens
                [xs (List Nat)] (Clj.Set Nat)
                (Clj.toSet (.filter xs (fn [x] (== (% x 2) 0)))))

              (def wrap
                [i (Fin 10)] Nat
                (.val i)))


(t/deftest sum-types-are-tagged-maps
  (t/is (= 12 (area {:tag :circle :r 2})))
  (t/is (= 6 (area {:tag :rect :w 2 :h 3})))
  (t/is (= 0 (area {:tag :dot})))
  (t/is (= {:tag :rect :w 3 :h 4} (grow {:tag :rect :w 2 :h 3})))
  (t/is (= {:tag :dot} (grow {:tag :dot})))
  (t/is (= {:tag :error :value "division by zero"} (safe-div 1 0)))
  (t/is (= {:tag :ok :value 3} (safe-div 7 2))))


(t/deftest maps-sets-and-fin
  (t/is (= {"a" 2 "b" 1} (tally ["a" "b" "a"])))
  (t/is (= #{0 2} (evens [0 1 2 3])))
  (t/is (= 7 (wrap 7))))


(t/deftest the-type-library-knows-sum-types
  (let [shapes (gen/sample (types/gen 'Shape) 40)]
    (t/is (every? #(types/valid? 'Shape %) shapes))
    (t/is (every? #(m/validate (types/malli-schema 'Shape) %) shapes))
    (t/is (= (map area shapes) (map area shapes))))
  (t/is (not (types/valid? 'Shape {:tag :circle})))
  (t/is (every? #(types/valid? '(Map String Nat) %) (gen/sample (types/gen '(Map String Nat)) 20)))
  (t/is (every? #(m/validate (types/malli-schema '(Set Int)) %) (gen/sample (types/gen '(Set Int)) 20)))
  (t/is (= :map (types/kondo-type 'Shape)))
  (t/is (every? #(< -1 % 10) (gen/sample (types/gen '(Fin 10)) 30))))


(lt/defn word-counts
  [words (List String)]
  (Map String Nat)
  (reduce (fn [acc w] (update acc w (fnil inc 0))) {} words))


(lt/defn add-tag
  [tags (Set String) t String]
  (Set String)
  (if (contains? tags t) tags (conj tags t)))


(lt/defn inventory-total
  [stock (Map String Nat) items (List String)]
  Nat
  (reduce + (map (fn [i] (get stock i 0)) items)))


(t/deftest translated-code-on-maps-and-sets
  (doseq [v [#'word-counts #'add-tag #'inventory-total]]
    (t/is (:pass? (lt/check v {:seed 7})) (str v))))
