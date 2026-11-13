(ns inventory.core
  "Stock kept in a Clojure map from item names to quantities, with Lean
  proofs about how restocking and taking out change it."
  (:require
    [leanfran.core :refer [deflean]]
    [leanfran.typed :as lt]))


(lt/defn restock
  "Add `n` of `item` to the stock."
  [stock (Map String Int) item String n Int]
  (Map String Int)
  (update stock item (fn [q] (+ (or q 0) n))))


(lt/defn take-out
  "Take `n` of `item` out of the stock, or nil when there are fewer."
  [stock (Map String Int) item String n Int]
  (Option (Map String Int))
  (let [q (get stock item 0)]
    (when (<= n q)
      (assoc stock item (- q n)))))


(lt/defn fill-order
  "Take out every line of an order `[[item n] ...]`, or nil when one is short."
  [stock (Map String Int) lines (List (Prod String Int))]
  (Option (Map String Int))
  (if-let [[item n] (first lines)]
    (when-let [s (take-out stock item n)]
      (fill-order s (rest lines)))
    stock))


(deflean proofs
  (clojure fill-order restock)

  (theorem restock-adds [s (Map String Int) i String n Int]
           (= (Clj.get (restock s i n) i) (some (+ (Option.getD (Clj.get s i) 0) n)))
           (by (simp [restock Clj.update Clj.Update.update])
               (on-all (cases (Clj.Map.get s i)) simp)))

  (theorem restock-keeps-others [s (Map String Int) i String j String n Int h (not= i j)]
           (= (Clj.get (restock s i n) j) (Clj.get s j))
           (by (simp [restock Clj.update Clj.Update.update h])))

  (theorem take-out-short [s (Map String Int) i String n Int h (< (Option.getD (Clj.get s i) 0) n)]
           (= (take-out s i n) none)
           (by (simp only [take-out]) (on-all split simp-all omega)))

  (theorem take-out-takes [s (Map String Int) i String n Int h (<= n (Option.getD (Clj.get s i) 0))]
           (= (.bind (take-out s i n) (fn [t] (Clj.get t i))) (some (- (Option.getD (Clj.get s i) 0) n)))
           (by (simp only [take-out]) (on-all split simp-all))))
