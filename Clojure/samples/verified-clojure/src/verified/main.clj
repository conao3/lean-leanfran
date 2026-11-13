(ns verified.main
  (:require
    [leanfran.typed :as lt]
    [verified.sort :as sort]
    [verified.sum :as sum]))


(defn -main
  [& _]
  (prn (sort/sort-ints [5 3 9 1 3]))
  (prn (sum/sum-to 1000000))
  (doseq [v [#'sort/insert-sorted #'sort/sort-ints #'sum/sum-to-fast]]
    (println (str (symbol v)) (:pass? (lt/check v {:seed 1})))))
