(ns inventory.main
  (:require
    [inventory.core :as inv]
    [leanfran.typed :as lt]))


(defn -main
  [& _]
  (let [stock (-> {} (inv/restock "apple" 5) (inv/restock "pear" 2))]
    (prn (into (sorted-map) stock))
    (prn (into (sorted-map) (inv/take-out stock "apple" 3)))
    (prn (inv/take-out stock "pear" 3))
    (prn (into (sorted-map) (inv/fill-order stock [["apple" 1] ["pear" 2]])))
    (prn (inv/fill-order stock [["apple" 1] ["kiwi" 1]])))
  (doseq [v [#'inv/restock #'inv/take-out #'inv/fill-order]]
    (println (str (symbol v)) (:pass? (lt/check v {:seed 1})))))
