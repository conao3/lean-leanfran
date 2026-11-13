(ns hooks.leanfran
  (:require
    [clj-kondo.hooks-api :as api]
    [clojure.string :as str]))


(defn- camel
  [s]
  (if (str/includes? s "-")
    (let [[head & tail] (str/split s #"-")]
      (apply str head (map str/capitalize tail)))
    s))


(defn- kebab
  [s]
  (-> s
      (str/replace #"([a-z0-9])([A-Z])" "$1-$2")
      (str/replace #"([A-Z]+)([A-Z][a-z])" "$1-$2")
      str/lower-case))


(defn- public-name
  [lean-name]
  (str/join "-" (map (comp kebab camel) (str/split lean-name #"\."))))


(defn- names-in-source
  [src]
  (->> (re-seq #"(?m)^\s*(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|partial|noncomputable|unsafe)\s+)*(?:def|abbrev)\s+([^\s(:{\[]+)" src)
       (map second)))


(defn- names-in-form
  [prefix form]
  (cond
    (string? form) (map #(str prefix %) (names-in-source form))
    (seq? form) (case (first form)
                  (def abbrev) [(str prefix (second form))]
                  export (let [[_ f {:keys [at as]}] form]
                           [(str prefix (or as (str f "-" (str/join "-" (map #(str/lower-case (str %)) (vals (merge {'α 'Int} at)))))))])
                  mutual (mapcat #(names-in-form prefix %) (rest form))
                  namespace (mapcat #(names-in-form (str prefix (second form) ".") %) (nnext form))
                  nil)
    :else nil))


(defn deflean
  [{:keys [node]}]
  (let [[_ block & args] (:children node)
        body (if (and (seq args) (api/map-node? (first args))) (rest args) args)
        names (->> body
                   (mapcat #(names-in-form "" (api/sexpr %)))
                   (map public-name)
                   distinct)]
    {:node (api/list-node
             (list* (api/token-node 'do)
                    (api/list-node [(api/token-node 'declare) block])
                    (for [n names]
                      (api/list-node [(api/token-node 'declare) (api/token-node (symbol n))]))))}))


(defn- clojure-args
  "The Clojure parameters of a binder vector node: names before their types,
  `&` and the rest name, without the type-parameter lists."
  [bs]
  (loop [cs (:children bs) acc []]
    (if-let [c (first cs)]
      (cond
        (api/list-node? c) (recur (rest cs) acc)
        (= '& (api/sexpr c)) (recur (drop 3 cs) (conj acc c (second cs)))
        :else (recur (drop 2 cs) (conj acc c)))
      (api/vector-node acc))))


(defn typed-defn
  [{:keys [node]}]
  (let [[_ nm & more] (:children node)
        [doc more] (if (api/string-node? (first more)) [(first more) (rest more)] [nil more])
        arities (if (api/vector-node? (first more)) [more] (map :children more))]
    {:node (api/list-node
             (concat [(api/token-node 'clojure.core/defn) (api/token-node (with-meta (api/sexpr nm) nil))]
                     (when doc [doc])
                     (for [[bs _ret & body] arities]
                       (api/list-node (cons (clojure-args bs) body)))))}))


(defn typed-loop
  [{:keys [node]}]
  (let [[_ bs & body] (:children node)]
    {:node (api/list-node
             (list* (api/token-node 'clojure.core/loop)
                    (api/vector-node (mapcat (fn [[n _ v]] [n v]) (partition 3 (:children bs))))
                    body))}))


(defn typed-letfn
  [{:keys [node]}]
  (let [[_ fns & body] (:children node)]
    {:node (api/list-node
             (list* (api/token-node 'clojure.core/letfn)
                    (api/vector-node
                      (for [f (:children fns)
                            :let [[nm bs _ & fbody] (:children f)]]
                        (api/list-node (list* nm (api/vector-node (take-nth 2 (:children bs))) fbody))))
                    body))}))
