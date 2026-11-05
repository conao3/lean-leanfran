(ns lean-clj.translate
  "Lean models of Clojure functions defined with `lean-clj.typed/defn`.

  `models` turns the `:lean/sig` of each function into `lean-clj.dsl`
  commands: a `def` whose body is the Clojure body written with the models of
  `clojure.core` in `Clj`. Lean infers the types; the translation only follows
  the syntax."
  (:require
    [lean-clj.dsl :as dsl]))


(set! *warn-on-reflection* true)


(defn- fail
  [msg form]
  (throw (ex-info (str "lean-clj.translate: " msg ": " (pr-str form)) {:form form})))


;; clojure.core

(def ^:private fns
  "clojure.core functions that are one model in `Clj`, with the arities the
  model takes."
  {'inc ['Clj.inc 1] 'dec ['Clj.dec 1] 'quot ['Clj.quot 2] 'rem ['Clj.rem 2] 'mod ['Clj.mod 2]
   'max ['Clj.max 2] 'min ['Clj.min 2]
   'zero? ['Clj.zero? 1] 'pos? ['Clj.pos? 1] 'neg? ['Clj.neg? 1] 'even? ['Clj.even? 1] 'odd? ['Clj.odd? 1]
   'not ['Clj.not 1] 'nil? ['Clj.nil? 1] 'some? ['Clj.some? 1] 'not= ['Clj.notEq 2]
   'first ['Clj.first 1] 'rest ['Clj.rest 1] 'next ['Clj.next 1] 'seq ['Clj.seq 1] 'count ['Clj.count 1]
   'empty? ['Clj.empty? 1] 'map ['Clj.map 2] 'filter ['Clj.filter 2] 'remove ['Clj.remove 2]
   'reduce ['Clj.reduce 3] 'take ['Clj.take 2] 'drop ['Clj.drop 2] 'reverse ['Clj.reverse 1]
   'vec ['Clj.vec 1] 'cons ['Clj.cons 2] 'concat ['Clj.concat 2] 'conj ['Clj.conj 2]
   'into ['Clj.into 2] 'get ['Clj.get 2] 'contains? ['Clj.contains? 2]})


(def ^:private folds
  "Variadic arithmetic, folded from the left into the binary model."
  {'+ 'Clj.add '* 'Clj.mul})


(def ^:private chains
  "Variadic comparisons: `(< a b c)` is `(< a b)` and `(< b c)`."
  {'< 'Clj.lt '<= 'Clj.le '> 'Clj.gt '>= 'Clj.ge '= 'Clj.eq})


(defn- value-of-core
  "The model of a clojure.core function used as a value."
  [sym form]
  (or (first (fns sym))
      (folds sym)
      (chains sym)
      ({'- 'Clj.sub 'str 'Clj.str 'range 'Clj.range 'nth 'Clj.nth} sym)
      (fail (str "clojure.core/" sym " has no model in Clj") form)))


;; Context

(defn- fresh!
  [ctx prefix]
  (symbol (str prefix (swap! (:counter ctx) inc))))


(defn- resolve-var
  [ctx sym]
  (when-not (contains? (:locals ctx) sym)
    (let [v (ns-resolve (the-ns (:ns ctx)) sym)]
      (when (var? v) v))))


(defn- core-var?
  [^clojure.lang.Var v]
  (= 'clojure.core (ns-name (.ns v))))


(defn- typed-var?
  [v]
  (contains? (meta v) :lean/sig))


(defn- var-is?
  [ctx sym target]
  (when (symbol? sym)
    (when-let [v (resolve-var ctx sym)]
      (= v (resolve target)))))


(declare tr)


(defn- tr-all
  [ctx forms]
  (mapv #(tr ctx %) forms))


(defn- truthy
  [ctx c]
  (list '= (list 'Clj.truthy (tr ctx c)) true))


(defn- tr-if
  [ctx c t e]
  (list 'if (fresh! ctx "_h") (truthy ctx c) (tr ctx t) (tr ctx e)))


(defn- tr-cond
  [ctx clauses form]
  (when (odd? (count clauses)) (fail "cond needs test/expression pairs" form))
  (let [[c e & more] clauses]
    (cond
      (nil? c) (fail "cond needs an :else clause, since the model returns a value" form)
      (or (keyword? c) (true? c)) (tr ctx e)
      :else (list 'if (fresh! ctx "_h") (truthy ctx c) (tr ctx e) (tr-cond ctx more form)))))


(defn- binding-pair
  [[x v] form]
  (when-not (symbol? x) (fail "destructuring is outside the translated subset" form))
  [x v])


(defn- tr-if-some
  "`if-let` checks that the value is truthy and `if-some` that it is not nil;
  on `Option α` both take the `some` branch, and `if-let` also checks the
  element."
  [ctx truthy? [bs t e] form]
  (when-not (and (vector? bs) (= 2 (count bs))) (fail "needs one binding" form))
  (let [[x v] (binding-pair bs form)
        inner (assoc ctx :locals (assoc (:locals ctx) x nil))
        then (tr inner t)
        else (tr ctx e)]
    (list 'match-eq (fresh! ctx "_h") (tr ctx v)
          (list 'some x) (if truthy? (list 'if (list 'Clj.truthy x) then else) then)
          'none else)))


(defn- tr-let
  [ctx [bs body] form]
  (when-not (and (vector? bs) (even? (count bs))) (fail "let needs a binding vector" form))
  (loop [pairs (partition 2 bs) ctx ctx acc []]
    (if-let [[x v] (first pairs)]
      (let [[x v] (binding-pair [x v] form)]
        (recur (rest pairs) (update ctx :locals assoc x nil) (conj acc x (tr ctx v))))
      (list 'let acc (tr ctx body)))))


(defn- tr-fn
  [ctx [params & body] form]
  (when-not (and (vector? params) (every? symbol? params) (not-any? #{'&} params) (= 1 (count body)))
    (fail "fn needs one arity of plain parameters and one body form" form))
  (list 'fn params (tr (-> ctx
                           (update :locals merge (zipmap params (repeat nil)))
                           (dissoc :recur))
                       (first body))))


(defn- tr-case
  [ctx [x & clauses] form]
  (let [default? (odd? (count clauses))
        pairs (partition 2 clauses)
        pattern #(cond (keyword? %) (symbol (str "." (name %)))
                       (or (number? %) (string? %) (char? %) (boolean? %)) %
                       :else (fail "case takes keyword and literal constants" form))]
    (list* 'match (tr ctx x)
           (concat (mapcat (fn [[p e]] [(pattern p) (tr ctx e)]) pairs)
                   (when default? ['_ (tr ctx (last clauses))])))))


(defn- tr-loop
  "A `lean-clj.typed/loop` becomes a top-level helper taking the function's
  parameters and the loop variables; `recur` calls it."
  [ctx [bindings body] form]
  (let [triples (partition 3 bindings)
        vars (map first triples)
        shadowed (set vars)
        params (remove (fn [[x _]] (shadowed x)) (:params ctx))
        helper (symbol (str (:name ctx) ".loop" (swap! (:counter ctx) inc)))
        helper-binders (vec (concat (mapcat identity params) (mapcat (fn [[x t _]] [x t]) triples)))
        outer (map first params)
        inner (-> ctx
                  (assoc :locals (merge (zipmap outer (map second params)) (zipmap vars (map second triples))))
                  (assoc :recur {:helper helper :outer outer :arity (count vars)})
                  (assoc :params (concat params (map (fn [[x t _]] [x t]) triples))))
        m (meta bindings)
        body' (tr inner body)]
    (doseq [x (keys (:locals ctx))]
      (when (and (nil? (get (:locals ctx) x)) (not (shadowed x)) (some #{x} (flatten (seq body'))))
        (fail (str "a loop refers to " x ", which is bound outside it; make it a loop variable") form)))
    (swap! (:helpers ctx) conj
           (list 'def (with-meta helper (select-keys m [:termination-by :decreasing-by]))
                 helper-binders (:ret ctx) body'))
    (list* helper (concat outer (map #(tr ctx (nth % 2)) triples)))))


(defn- tr-recur
  [ctx args form]
  (let [{:keys [helper outer arity]} (:recur ctx)]
    (cond
      (nil? (:recur ctx)) (fail "recur outside a loop or function body" form)
      (not= arity (count args)) (fail "recur with the wrong number of arguments" form)
      :else (list* helper (concat outer (tr-all ctx args))))))


(defn- tr-call
  [ctx [head & args :as form]]
  (let [v (when (symbol? head) (resolve-var ctx head))
        sym (when v (.sym ^clojure.lang.Var v))
        n (count args)]
    (cond
      (keyword? head)
      (if (= 1 n)
        (list (symbol (str "." (name head))) (tr ctx (first args)))
        (fail "keyword lookup with a default is outside the translated subset" form))

      (and v (typed-var? v))
      (do (swap! (:deps ctx) conj v)
          (list* (:name (:lean/sig (meta v))) (tr-all ctx args)))

      (and v (core-var? v))
      (cond
        (folds sym) (if (zero? n)
                      (fail "needs at least one argument" form)
                      (reduce (fn [acc x] (list (folds sym) acc x)) (tr-all ctx args)))
        (chains sym) (if (< n 2)
                       (fail "needs at least two arguments" form)
                       (let [xs (tr-all ctx args)]
                         (reduce (fn [acc x] (list '&& acc x))
                                 (map (fn [[a b]] (list (chains sym) a b)) (partition 2 1 xs)))))
        (= '- sym) (case n
                     0 (fail "needs at least one argument" form)
                     1 (list 'Clj.neg (tr ctx (first args)))
                     (reduce (fn [acc x] (list 'Clj.sub acc x)) (tr-all ctx args)))
        (= 'str sym) (if (zero? n)
                       ""
                       (reduce (fn [acc x] (list '++ acc x)) (map #(list 'Clj.str %) (tr-all ctx args))))
        (= 'list sym) (tr-all ctx args)
        (= 'vector sym) (list* 'array (tr-all ctx args))
        (= 'range sym) (case n
                         1 (list 'Clj.range (tr ctx (first args)))
                         2 (list 'Clj.range2 (tr ctx (first args)) (tr ctx (second args)))
                         (fail "range takes one or two arguments" form))
        (= 'nth sym) (case n
                       2 (list* 'Clj.nth (tr-all ctx args))
                       3 (list* 'Clj.nth3 (tr-all ctx args))
                       (fail "nth takes two or three arguments" form))
        (= 'assoc sym) (let [[m & kvs] args]
                         (when-not (and (seq kvs) (even? (count kvs)) (every? keyword? (take-nth 2 kvs)))
                           (fail "assoc takes keyword keys of a structure" form))
                         (list 'with (tr ctx m) (into {} (map (fn [[k x]] [k (tr ctx x)]) (partition 2 kvs)))))
        (= 'update sym) (let [[m k f & more] args]
                          (when-not (keyword? k) (fail "update takes a keyword key of a structure" form))
                          (let [m' (tr ctx m)]
                            (list 'with m' {k (list* (tr ctx f) (list (symbol (str "." (name k))) m') (tr-all ctx more))})))
        (fns sym) (let [[model arity] (fns sym)]
                    (if (= arity n)
                      (list* model (tr-all ctx args))
                      (fail (str "the model of " sym " takes " arity " arguments") form)))
        :else (fail (str "clojure.core/" sym " has no model in Clj") form))

      v (fail (str head " is neither a lean-clj.typed/defn function nor modelled in Clj") form)

      (contains? (:locals ctx) head) (list* head (tr-all ctx args))

      (seq? head) (list* (tr ctx head) (tr-all ctx args))

      :else (fail "cannot translate the call" form))))


(defn- macro-var?
  [ctx sym]
  (when (symbol? sym)
    (when-let [v (resolve-var ctx sym)]
      (:macro (meta v)))))


(defn- tr-seq
  [ctx [head & args :as form]]
  (let [is? #(var-is? ctx head %)]
    (cond
      (= 'if head) (case (count args)
                     3 (apply tr-if ctx args)
                     2 (tr-if ctx (first args) (second args) nil)
                     (fail "if takes two or three forms" form))
      (= 'do head) (if (= 1 (count args)) (tr ctx (first args)) (fail "do with several forms" form))
      (= 'recur head) (tr-recur ctx args form)
      (= 'quote head) (fail "quoted data is outside the translated subset" form)
      (is? 'clojure.core/when) (if (= 2 (count args)) (tr-if ctx (first args) (second args) nil) (fail "when with several forms" form))
      (is? 'clojure.core/when-not) (if (= 2 (count args)) (tr-if ctx (first args) nil (second args)) (fail "when-not with several forms" form))
      (is? 'clojure.core/cond) (tr-cond ctx args form)
      (is? 'clojure.core/if-let) (tr-if-some ctx true [(first args) (second args) (nth args 2 nil)] form)
      (is? 'clojure.core/when-let) (tr-if-some ctx true [(first args) (second args) nil] form)
      (is? 'clojure.core/if-some) (tr-if-some ctx false [(first args) (second args) (nth args 2 nil)] form)
      (is? 'clojure.core/when-some) (tr-if-some ctx false [(first args) (second args) nil] form)
      (is? 'clojure.core/and) (reduce (fn [acc x] (list '&& acc x)) (map #(list 'Clj.truthy (tr ctx %)) args))
      (is? 'clojure.core/or) (reduce (fn [acc x] (list '|| acc x)) (map #(list 'Clj.truthy (tr ctx %)) args))
      (is? 'clojure.core/let) (tr-let ctx args form)
      (is? 'clojure.core/fn) (tr-fn ctx args form)
      (is? 'clojure.core/case) (tr-case ctx args form)
      (is? 'lean-clj.typed/loop) (tr-loop ctx args form)
      (is? 'clojure.core/loop) (fail "use lean-clj.typed/loop, whose bindings carry Lean types" form)
      (macro-var? ctx head) (tr ctx (binding [*ns* (the-ns (:ns ctx))] (macroexpand-1 form)))
      :else (tr-call ctx form))))


(defn- tr
  [ctx x]
  (cond
    (nil? x) 'none
    (seq? x) (if (empty? x) [] (tr-seq ctx x))
    (keyword? x) (symbol (str "." (name x)))
    (symbol? x) (cond
                  (contains? (:locals ctx) x) x
                  :else (let [v (resolve-var ctx x)]
                          (cond
                            (nil? v) (fail "unresolved symbol" x)
                            (typed-var? v) (do (swap! (:deps ctx) conj v) (:name (:lean/sig (meta v))))
                            (core-var? v) (value-of-core (.sym ^clojure.lang.Var v) x)
                            :else (fail (str x " is neither a lean-clj.typed/defn function nor modelled in Clj") x))))
    (or (string? x) (char? x) (boolean? x) (integer? x)) x
    :else (fail "outside the translated subset" x)))


;; Models

(defn- extern-name
  [{:keys [ns name]}]
  (str "clj:" ns "/" name))


(defn- model-of
  "Commands of the model of the function `v` and the functions it calls."
  [v extern?]
  (let [{:keys [binders ret body name] :as sig} (:lean/sig (meta v))
        params (map vec (partition 2 binders))
        ctx {:ns (:ns sig)
             :name name
             :ret ret
             :params params
             :locals (into {} params)
             :recur {:helper name :outer [] :arity (count params)}
             :counter (atom 0)
             :helpers (atom [])
             :deps (atom #{})}
        body' (tr ctx body)
        m (cond-> (select-keys sig [:termination-by :decreasing-by])
            extern? (assoc :attrs [(str "extern \"" (extern-name sig) "\"")]))]
    {:commands (conj @(:helpers ctx) (list 'def (with-meta name m) binders ret body'))
     :deps (disj @(:deps ctx) v)}))


(defn models
  "`lean-clj.dsl` commands of the Lean models of the `lean-clj.typed/defn`
  vars `vs` and of the functions they call, callees first. With `extern?`, each
  model is `@[extern]` to its Clojure var, so that compiled Lean calls the
  Clojure function."
  [vs extern?]
  (let [done (atom #{})
        out (atom [])
        visit (fn visit
                [v path]
                (when (contains? path v)
                  (throw (ex-info (str "lean-clj.translate: mutual recursion through " v " is outside the translated subset")
                                  {:var v})))
                (when-not (contains? @done v)
                  (when-not (typed-var? v)
                    (throw (ex-info (str "lean-clj.translate: " v " is not defined with lean-clj.typed/defn") {:var v})))
                  (let [{:keys [commands deps]} (model-of v extern?)]
                    (doseq [d (sort-by str deps)] (visit d (conj path v)))
                    (swap! done conj v)
                    (swap! out into commands))))]
    (doseq [v vs] (visit v #{}))
    (let [names (map #(:name (:lean/sig (meta %))) @done)]
      (when-not (apply distinct? (map str names))
        (throw (ex-info "lean-clj.translate: two translated functions share a name" {:names names}))))
    @out))


(defn clojure-command?
  "Whether `x` is the deflean command `(clojure f ...)`."
  [x]
  (and (seq? x) (= 'clojure (first x))))


(defn render-command
  "Lean source of `(clojure f ...)` in the namespace `ns`: the models of the
  named functions and of the functions they call, `@[extern]` to the Clojure
  vars."
  [ns [_ & syms :as cmd] extern?]
  (let [vs (mapv (fn [s]
                   (or (when (symbol? s) (ns-resolve ns s))
                       (throw (ex-info (str "lean-clj.translate: cannot resolve " s " in " (pr-str cmd)) {:command cmd}))))
                 syms)]
    (dsl/render (models vs extern?))))
