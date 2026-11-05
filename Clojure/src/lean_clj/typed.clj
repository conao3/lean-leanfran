(ns lean-clj.typed
  "Clojure functions with Lean signatures.

    (lean-clj.typed/defn insert-sorted [x Int xs (List Int)] (List Int)
      ...)

  The function is an ordinary Clojure function. Its signature and body are
  kept in the var's `:lean/sig` metadata, from which `(clojure insert-sorted)`
  in a `deflean` block renders a Lean model of the function to prove things
  about."
  (:refer-clojure :exclude [defn loop])
  (:require
    [clojure.test.check :as tc]
    [clojure.test.check.generators :as gen]
    [clojure.test.check.properties :as prop]
    [lean-clj.core :as core]
    [lean-clj.types :as types]))


(set! *warn-on-reflection* true)


(def ^:private termination-keys
  [:termination-by :decreasing-by])


(clojure.core/defn- check-binders
  [nm bs]
  (when-not (and (vector? bs) (even? (count bs)) (every? symbol? (take-nth 2 bs)))
    (throw (ex-info (str "lean-clj.typed: " nm " needs a binder vector [x T ...] of names and Lean types")
                    {:name nm :binders bs}))))


(defmacro defn
  "Define a function with a Lean signature: `[x T y U] R` as in `deflean`.

    (defn name docstring? [x T ...] R body)

  `:termination-by` and `:decreasing-by` metadata on the name give Lean the
  termination argument of a recursive function."
  [nm & more]
  (let [[doc more] (if (string? (first more)) [(first more) (rest more)] [nil more])
        [bs ret & body] more]
    (check-binders nm bs)
    (when-not (= 1 (count body))
      (throw (ex-info (str "lean-clj.typed: " nm " needs exactly one body form") {:name nm :body body})))
    (let [sig (merge {:binders bs
                      :ret ret
                      :body (first body)
                      :ns (ns-name *ns*)
                      :name nm}
                     (select-keys (meta nm) termination-keys))
          nm' (vary-meta nm #(-> (apply dissoc % termination-keys)
                                 (assoc :lean/sig (list 'quote sig))))]
      `(clojure.core/defn ~nm' ~@(when doc [doc]) ~(vec (take-nth 2 bs)) ~@body))))


(defmacro loop
  "`clojure.core/loop` whose bindings carry Lean types: `[i T init ...]`.
  `:termination-by` and `:decreasing-by` metadata on the vector give Lean the
  termination argument."
  [bindings & body]
  (when-not (and (vector? bindings) (zero? (rem (count bindings) 3)) (every? symbol? (take-nth 3 bindings)))
    (throw (ex-info "lean-clj.typed: loop needs bindings [name Type init ...]" {:bindings bindings})))
  `(clojure.core/loop ~(vec (mapcat (fn [[n _ v]] [n v]) (partition 3 bindings))) ~@body))


(clojure.core/defn- model-fn
  "The Lean model of the function `v`, compiled to Clojure in a namespace of
  its own."
  [v]
  (let [{:keys [ns name]} (:lean/sig (meta v))
        model-ns (symbol (str "lean-clj.check." ns "." name))
        body [(list 'clojure (symbol (str ns) (str name)))]
        forms (core/expand model-ns 'model (core/options {} body) (core/source (the-ns ns) body false))]
    (binding [*ns* (create-ns model-ns)]
      (refer-clojure)
      (doseq [f forms] (eval f)))
    @(ns-resolve model-ns name)))


(clojure.core/defn check
  "Compare the `lean-clj.typed/defn` function `v` with its Lean model on
  inputs generated from the signature, as `clojure.test.check/quick-check`.
  A call where the Clojure function throws is outside what the model
  describes and passes; a result that is not a value of the return type
  fails."
  ([v] (check v {}))
  ([v {:keys [num-tests seed] :or {num-tests 100}}]
   (let [{:keys [binders ret]} (:lean/sig (meta v))
         model (model-fn v)
         types (take-nth 2 (rest binders))
         f @v]
     (apply tc/quick-check num-tests
            (prop/for-all [args (apply gen/tuple (map types/gen types))]
                          (let [expected (apply model args)
                                actual (try (apply f args) (catch Exception _ ::threw))]
                            (or (= ::threw actual)
                                (and (types/valid? ret actual) (= expected actual)))))
            (when seed [:seed seed])))))
