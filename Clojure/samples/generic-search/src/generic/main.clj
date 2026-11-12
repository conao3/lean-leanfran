(ns generic.main
  (:require
    [generic.core :as s]
    [lean-clj.typed :as lt]))


(defn -main
  [& _]
  (prn (s/member? 3 [1 2 3]) (s/member? "z" ["a" "b"]))
  (prn (s/clamp 250) (s/clamp 5 10 20))
  (prn (s/total 1) (s/total 1 2 3))
  (println "member? at Int" (:pass? (lt/check #'s/member? {:seed 1})))
  (println "member? at String" (:pass? (lt/check #'s/member? {:seed 1 :at '{α String}})))
  (println "clamp" (:pass? (lt/check #'s/clamp {:seed 1})))
  (println "total" (:pass? (lt/check #'s/total {:seed 1}))))
