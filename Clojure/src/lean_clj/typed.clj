(ns lean-clj.typed
  "Clojure functions with Lean signatures.

    (lean-clj.typed/defn insert-sorted [x Int xs (List Int)] (List Int)
      ...)

  The function is an ordinary Clojure function. Its signature and body are
  kept in the var's `:lean/sig` metadata, from which `(clojure insert-sorted)`
  in a `deflean` block renders a Lean model of the function to prove things
  about."
  (:refer-clojure :exclude [defn loop letfn])
  (:require
    [clojure.test.check :as tc]
    [clojure.test.check.generators :as gen]
    [clojure.test.check.properties :as prop]
    [clojure.walk]
    [lean-clj.core :as core]
    [lean-clj.types :as types]))


(set! *warn-on-reflection* true)


(def ^:private termination-keys
  [:termination-by :decreasing-by])


(clojure.core/defn- arity
  "One arity `[binders] R body` of a `defn`, checked."
  [nm [bs ret & body]]
  (when-not (vector? bs)
    (throw (ex-info (str "lean-clj.typed: " nm " needs a binder vector [x T ...] and a Lean return type") {:name nm})))
  (let [{:keys [params]} (types/binder-parts bs)]
    (when-not (every? #(or (symbol? %) (vector? %) (map? %)) (map first params))
      (throw (ex-info (str "lean-clj.typed: " nm " takes names or destructuring forms as parameters") {:name nm :binders bs}))))
  (when-not (= 1 (count body))
    (throw (ex-info (str "lean-clj.typed: " nm " needs exactly one body form per arity") {:name nm :body body})))
  {:binders bs :ret ret :body (first body)})


(defmacro defn
  "Define a function with a Lean signature: `[x T y U] R` as in `deflean`.

    (defn name docstring? [x T ...] R body)
    (defn name docstring? ([x T] R body) ([x T y U] R body) ...)

  Binders take `(implicit α Type)` and `(inst (BEq α))` for a polymorphic
  function, and `& xs (List T)` last for the rest arguments.
  `:termination-by` and `:decreasing-by` metadata on the name give Lean the
  termination argument of a recursive function."
  [nm & more]
  (let [[doc more] (if (string? (first more)) [(first more) (rest more)] [nil more])
        arities (if (vector? (first more)) [(arity nm more)] (mapv #(arity nm %) more))
        sig (merge {:arities arities
                    :ns (ns-name *ns*)
                    :name nm
                    :file *file*
                    :line (:line (meta &form))}
                   (select-keys (meta nm) termination-keys))
        nm' (vary-meta nm #(-> (apply dissoc % termination-keys)
                               (assoc :lean/sig (list 'quote sig))))]
    `(clojure.core/defn ~nm' ~@(when doc [doc])
       ~@(for [{:keys [binders body]} arities]
           (list (:args (types/binder-parts binders)) body)))))


(defmacro loop
  "`clojure.core/loop` whose bindings carry Lean types: `[i T init ...]`.
  `:termination-by` and `:decreasing-by` metadata on the vector give Lean the
  termination argument."
  [bindings & body]
  (when-not (and (vector? bindings) (zero? (rem (count bindings) 3)) (every? symbol? (take-nth 3 bindings)))
    (throw (ex-info "lean-clj.typed: loop needs bindings [name Type init ...]" {:bindings bindings})))
  `(clojure.core/loop ~(vec (mapcat (fn [[n _ v]] [n v]) (partition 3 bindings))) ~@body))


(clojure.core/defn- module-prefix
  "The prefix of the deflean modules of the Clojure namespace `ns`."
  [ns]
  (let [m (core/module-name ns 'x)]
    (subs m 0 (dec (count m)))))


(clojure.core/defn- substitute
  [at t]
  (clojure.walk/postwalk #(if (and (symbol? %) (contains? at %)) (get at %) %) t))


(clojure.core/defn- instantiation
  "The types of the type variables of the arity `a`: `at`, with `Int` for the
  ones it leaves out."
  [a at]
  (merge (zipmap (:type-vars (types/binder-parts (:binders a))) (repeat 'Int)) at))


(clojure.core/defn- model-fns
  "The Lean models of the arities of the function `v`, compiled to Clojure in
  a namespace of their own, instantiated at the types `at`: one function per
  arity, taking the arguments of that arity."
  [v at]
  (let [{:keys [ns name arities]} (:lean/sig (meta v))
        model-ns (symbol (str "lean-clj.check." ns "." name))
        model-ns-obj (create-ns model-ns)
        insts (mapv #(instantiation % at) arities)
        wrappers (vec (for [[i a] (map-indexed vector arities)
                            :let [{:keys [params rest]} (types/binder-parts (:binders a))
                                  s (partial substitute (insts i))
                                  model (if (= 1 (count arities)) name (symbol (str name ".arity" (count params))))
                                  xs (map #(symbol (str "a" %)) (range (count params)))
                                  r (when rest 'arest)]]
                        (list 'def (symbol (str "check-arity" i))
                              (vec (concat (mapcat (fn [x [_ t]] [x (s t)]) xs params)
                                           (when rest [r (s (second rest))])))
                              (s (:ret a))
                              (list* model (concat xs (when rest [r]))))))
        body [(list 'clojure (symbol (str ns) (str name)))]
        modules (->> (tree-seq coll? seq (mapv (fn [a i] (substitute i [(:binders a) (:ret a)])) arities insts))
                     (filter symbol?)
                     (keep #(try (types/module-of %) (catch clojure.lang.ExceptionInfo _ nil)))
                     distinct
                     vec)
        {:keys [source] :as r} (core/render (the-ns ns) 'model (concat body wrappers) false)
        forms (core/expand model-ns 'model
                           (update (core/options model-ns-obj {:imports modules :opens modules} body)
                                   :imports #(vec (distinct (concat % (:modules r)))))
                           source)]
    (binding [*ns* model-ns-obj]
      (refer-clojure)
      (doseq [f forms] (eval f)))
    (mapv #(deref (ns-resolve model-ns (symbol (str "check-arity" %)))) (range (count arities)))))


(declare check*)


(clojure.core/defn check
  "Compare the `lean-clj.typed/defn` function `v` with its Lean model on
  inputs generated from the signature, as `clojure.test.check/quick-check`,
  arity by arity. A call where the Clojure function throws is outside what the
  model describes and passes; a result that is not a value of the return type
  fails. The result is that of the first arity that fails, or of the last.

  Options: `:num-tests` (100), `:seed`, `:gens`, a map from parameter names
  to generators that replace the ones of their types, `:at`, the types of the
  type variables of a polymorphic function (`{α Int}`, `Int` for the ones it
  leaves out), and `:big-ints?`, to generate integers beyond `Long` (which
  recursion on a `Nat` would take that many steps to finish)."
  ([v] (check v {}))
  ([v opts]
   (binding [types/*preferred-module-prefix* (module-prefix (:ns (:lean/sig (meta v))))]
     (check* v opts))))


(clojure.core/defn- check*
  [v {:keys [num-tests seed gens big-ints? at] :or {num-tests 100}}]
  (let [arities (:arities (:lean/sig (meta v)))
        models (model-fns v at)
        f @v]
    (clojure.core/loop [i 0 last-result nil]
      (if (= i (count arities))
        last-result
        (let [a (arities i)
              inst (instantiation a at)
              {:keys [params rest]} (types/binder-parts (:binders a))
              ps (cond-> params rest (conj rest))
              g (binding [types/*big-ints* (boolean big-ints?)]
                  (mapv (fn [[p t]] (or (get gens p) (types/gen (substitute inst t)))) ps))
              ret (substitute inst (:ret a))
              model (models i)
              call (fn [h args] (if rest (apply h (concat (butlast args) (last args))) (apply h args)))
              r (apply tc/quick-check num-tests
                       (prop/for-all [args (apply gen/tuple g)]
                                     (let [expected (apply model args)
                                           actual (try (call f args) (catch Exception _ ::threw))]
                                       (or (= ::threw actual)
                                           (and (types/valid? ret actual) (= expected actual)))))
                       (when seed [:seed seed]))]
          (if (:pass? r) (recur (inc i) r) r))))))


(defmacro letfn
  "`clojure.core/letfn` whose functions carry Lean signatures:
  `[(f [x T ...] R body) ...]`. A function may call the ones before it, and
  itself through `recur` or by name."
  [fns & body]
  `(clojure.core/letfn ~(vec (for [[nm bs _ & fbody] fns] (list* nm (vec (take-nth 2 bs)) fbody))) ~@body))
