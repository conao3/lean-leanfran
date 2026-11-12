(ns words.main
  "Print the most frequent words of standard input."
  (:gen-class)
  (:require
    [words.count :as wc]))


(def usage
  "usage: word-count text list-top-words [--limit <n>] < input.txt\n")


(defn- run
  [args]
  (let [[command subcommand & params] args
        opts (apply hash-map params)
        limit (parse-long (get opts "--limit" "10"))]
    (cond
      (= ["help"] args) (do (print usage) 0)
      (and (= ["text" "list-top-words"] [command subcommand])
           (even? (count params))
           (= #{} (disj (set (keys opts)) "--limit"))
           limit)
      (do (doseq [[word n] (wc/top-words limit (slurp *in*))]
            (println (str n "\t" word)))
          0)
      :else (do (binding [*out* *err*] (print usage)) 252))))


(defn -main
  [& args]
  (let [code (run args)]
    (flush)
    (System/exit code)))
