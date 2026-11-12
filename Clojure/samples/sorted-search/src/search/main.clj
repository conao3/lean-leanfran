(ns search.main
  (:require
    [lean-clj.typed :as lt]
    [search.core :as search]))


(defn -main
  [& _]
  (prn (search/sorted-member? 5 '(1 3 5 7)))
  (prn (search/sorted-member? 4 '(1 3 5 7)))
  (prn (search/sorted-member? 1 '(2 1)))
  (println "check" (:pass? (lt/check #'search/sorted-member? {:seed 1}))))
