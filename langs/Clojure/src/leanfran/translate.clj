(ns leanfran.translate
  "Lean models of Clojure functions defined with `leanfran.typed/defn`.

  `models` turns the `:lean/sig` of each function into `leanfran.dsl`
  commands: a `def` whose body is the Clojure body written with the models of
  `clojure.core` in `Clj`. Lean infers the types; the translation only follows
  the syntax."
  (:require
    [clojure.string :as str]
    [leanfran.dsl :as dsl]
    [leanfran.types :as types]))


(set! *warn-on-reflection* true)


(def ^:private ^:dynamic *where*
  "The `leanfran.typed/defn` being translated: `{:file :line :name}`."
  nil)


(defn- fail
  [msg form]
  (let [{:keys [file line name]} *where*]
    (throw (ex-info (str (when file (str file ":" line ": ")) "leanfran.translate: "
                         (when name (str "in " name ": ")) msg ": " (pr-str form))
                    {:form form :where *where*}))))


;; clojure.core

(def ^:private fns
  "clojure.core functions that are one model in `Clj`: the model, the
  arities it takes, and the argument positions that take a function, where a
  keyword stands for its lookup function."
  {'inc {:model 'Clj.inc :arity #{1}}
   'inc' {:model 'Clj.inc :arity #{1}}
   'dec {:model 'Clj.dec :arity #{1}}
   'dec' {:model 'Clj.dec :arity #{1}}
   'quot {:model 'Clj.quot :arity #{2}}
   'rem {:model 'Clj.rem :arity #{2}}
   'mod {:model 'Clj.mod :arity #{2}}
   'zero? {:model 'Clj.zero? :arity #{1}}
   'pos? {:model 'Clj.pos? :arity #{1}}
   'neg? {:model 'Clj.neg? :arity #{1}}
   'even? {:model 'Clj.even? :arity #{1}}
   'odd? {:model 'Clj.odd? :arity #{1}}
   'not {:model 'Clj.not :arity #{1}}
   'nil? {:model 'Clj.nil? :arity #{1}}
   'some? {:model 'Clj.some? :arity #{1}}
   'first {:model 'Clj.first :arity #{1}}
   'rest {:model 'Clj.rest :arity #{1}}
   'next {:model 'Clj.next :arity #{1}}
   'seq {:model 'Clj.seq :arity #{1}}
   'count {:model 'Clj.count :arity #{1}}
   'empty? {:model 'Clj.empty? :arity #{1}}
   'map {:model 'Clj.map :arity #{2} :fn-args #{0}}
   'filter {:model 'Clj.filter :arity #{2} :fn-args #{0}}
   'remove {:model 'Clj.remove :arity #{2} :fn-args #{0}}
   'reduce {:model 'Clj.reduce :arity #{3} :fn-args #{0}}
   'take {:model 'Clj.take :arity #{2}}
   'drop {:model 'Clj.drop :arity #{2}}
   'reverse {:model 'Clj.reverse :arity #{1}}
   'vec {:model 'Clj.vec :arity #{1}}
   'cons {:model 'Clj.cons :arity #{2}}
   'concat {:model 'Clj.concat :arity #{2}}
   'conj {:model 'Clj.conj :arity #{2}}
   'into {:model 'Clj.into :arity #{2}}
   'contains? {:model 'Clj.contains? :arity #{2}}
   'nthnext {:model 'Clj.nthnext :arity #{2}}
   'nthrest {:model 'Clj.nthrest :arity #{2}}
   'some {:model 'Clj.someBy :arity #{2} :fn-args #{0}}
   'every? {:model 'Clj.every? :arity #{2} :fn-args #{0}}
   'not-every? {:model 'Clj.notEvery? :arity #{2} :fn-args #{0}}
   'not-any? {:model 'Clj.notAny? :arity #{2} :fn-args #{0}}
   'mapcat {:model 'Clj.mapcat :arity #{2} :fn-args #{0}}
   'keep {:model 'Clj.keep :arity #{2} :fn-args #{0}}
   'map-indexed {:model 'Clj.mapIndexed :arity #{2} :fn-args #{0}}
   'keep-indexed {:model 'Clj.keepIndexed :arity #{2} :fn-args #{0}}
   'last {:model 'Clj.last :arity #{1}}
   'butlast {:model 'Clj.butlast :arity #{1}}
   'take-while {:model 'Clj.takeWhile :arity #{2} :fn-args #{0}}
   'drop-while {:model 'Clj.dropWhile :arity #{2} :fn-args #{0}}
   'split-at {:model 'Clj.splitAt :arity #{2}}
   'interpose {:model 'Clj.interpose :arity #{2}}
   'interleave {:model 'Clj.interleave :arity #{2}}
   'distinct {:model 'Clj.distinct :arity #{1}}
   'mapv {:model 'Clj.mapv :arity #{2} :fn-args #{0}}
   'filterv {:model 'Clj.filterv :arity #{2} :fn-args #{0}}
   'partition {:model 'Clj.partition :arity #{2}}
   'partition-all {:model 'Clj.partitionAll :arity #{2}}
   'sort {:model 'Clj.sort :arity #{1}}
   'sort-by {:model 'Clj.sortBy :arity #{2} :fn-args #{0}}
   'max-key {:model 'Clj.maxKey :arity #{3} :fn-args #{0}}
   'min-key {:model 'Clj.minKey :arity #{3} :fn-args #{0}}
   'not-empty {:model 'Clj.notEmpty :arity #{1}}
   'empty {:model 'Clj.empty :arity #{1}}
   'subvec {:model 'Clj.subvec :arity #{3}}
   'select-keys {:model 'Clj.selectKeys :arity #{2}}
   'set {:model 'Clj.toSet :arity #{1}}
   'frequencies {:model 'Clj.frequencies :arity #{1}}
   'group-by {:model 'Clj.groupBy :arity #{2} :fn-args #{0}}})


(def ^:private set-fns
  "clojure.set functions that are one model in `Clj`."
  {'union {:model 'Clj.union :arity #{2}}
   'intersection {:model 'Clj.intersection :arity #{2}}
   'difference {:model 'Clj.difference :arity #{2}}})


(def ^:private string-fns
  "clojure.string functions that are one model in `Clj.Str'`."
  {'upper-case {:model 'Clj.Str'.upperCase :arity #{1}}
   'lower-case {:model 'Clj.Str'.lowerCase :arity #{1}}
   'trim {:model 'Clj.Str'.trim :arity #{1}}
   'triml {:model 'Clj.Str'.triml :arity #{1}}
   'trimr {:model 'Clj.Str'.trimr :arity #{1}}
   'blank? {:model 'Clj.Str'.blank? :arity #{1}}
   'starts-with? {:model 'Clj.Str'.startsWith? :arity #{2}}
   'ends-with? {:model 'Clj.Str'.endsWith? :arity #{2}}
   'includes? {:model 'Clj.Str'.includes? :arity #{2}}
   'replace {:model 'Clj.Str'.replace :arity #{3}}})


(def ^:private folds
  "Variadic functions folded from the left into a binary model."
  {'+ 'Clj.add '+' 'Clj.add '* 'Clj.mul '*' 'Clj.mul 'max 'Clj.max 'min 'Clj.min})


(def ^:private chains
  "Variadic comparisons: `(< a b c)` is `(< a b)` and `(< b c)`."
  {'< 'Clj.lt '<= 'Clj.le '> 'Clj.gt '>= 'Clj.ge '= 'Clj.eq '== 'Clj.eq})


(def ^:private values
  "Models of clojure.core functions used as values, beyond `fns`."
  {'- 'Clj.sub '-' 'Clj.sub 'str 'Clj.str 'range 'Clj.range 'nth 'Clj.nth 'not= 'Clj.notEq})


(defn- value-of-core
  "The model of a clojure.core function used as a value."
  [sym form]
  (or (:model (fns sym))
      (folds sym)
      (chains sym)
      (values sym)
      (when (= 'identity sym) (list 'fn ['x0] 'x0))
      (fail (str "clojure.core/" sym " has no model in Clj") form)))


;; Context

(defn- fresh!
  [ctx prefix]
  (symbol (str prefix (swap! (:counter ctx) inc))))


(defn- local?
  [ctx sym]
  (contains? (:locals ctx) sym))


(defn- resolve-var
  [ctx sym]
  (when-not (local? ctx sym)
    (let [v (ns-resolve (the-ns (:ns ctx)) sym)]
      (when (var? v) v))))


(defn- core-var?
  [^clojure.lang.Var v]
  (= 'clojure.core (ns-name (.ns v))))


(defn- typed-var?
  [v]
  (contains? (meta v) :lean/sig))


(defn- lean-var?
  "A function that deflean or the CLI generated from Lean."
  [v]
  (contains? (meta v) :lean/name))


(defn- var-is?
  [ctx sym target]
  (when (symbol? sym)
    (when-let [v (resolve-var ctx sym)]
      (= v (resolve target)))))


(defn- bind
  [ctx xs]
  (update ctx :locals merge (zipmap xs (repeat nil))))


(declare tr tr-test typed-call pick-arity arity-name)


(defn- tr-all
  [ctx forms]
  (mapv #(tr ctx %) forms))


(defn- field
  [k]
  (symbol (str "." (name k))))


(defn- getter
  "A keyword as a function: its lookup on a structure."
  [ctx k]
  (let [x (fresh! ctx "x")]
    (list 'fn [x] (list (field k) x))))


;; Conditions

(defn- condition
  [ctx c]
  (list '= (list 'Clj.truthy (tr-test ctx c)) true))


(defn- lifted
  "A branch whose other branch is `nil`: coerced to `Option`, so that Lean
  settles its type before lifting it."
  [x other]
  (if (and (nil? other) (some? x)) (list 'coe x) x))


(defn- tr-if
  "`(if c t e)`. When `c` is a local, it stands for its non-nil value in `t`."
  [ctx c t e]
  (let [h (fresh! ctx "_h")
        then (if (and (symbol? c) (local? ctx c))
               (list 'let [c (list 'Clj.Unwrap.unwrap c h)] (lifted (tr ctx t) e))
               (lifted (tr ctx t) e))]
    (list 'if h (condition ctx c) then (lifted (tr ctx e) t))))


(defn- tr-cond
  [ctx clauses form]
  (when (odd? (count clauses)) (fail "cond needs test/expression pairs" form))
  (let [[c e & more] clauses]
    (cond
      (nil? c) (fail "cond needs an :else clause, since the model returns a value" form)
      (or (keyword? c) (true? c)) (tr ctx e)
      :else (tr-if ctx c e (cons 'cond more)))))


(defn- tr-or
  "`or` as a value: the first truthy argument, else the last one."
  [ctx [a & more]]
  (if (empty? more)
    (tr ctx a)
    (let [h (fresh! ctx "_h")
          a' (tr-test ctx a)]
      (list 'if h (list '= (list 'Clj.truthy a') true) (list 'Clj.Unwrap.unwrap a' h) (tr-or ctx more)))))


(defn- tr-and
  "`and` as a value: the first falsy argument, else the last one."
  [ctx [a & more]]
  (if (empty? more)
    (tr ctx a)
    (let [a' (tr-test ctx a)]
      (list 'if (list 'Clj.truthy a') (tr-and ctx more) a'))))


;; Bindings

(defn- destructure-pairs
  "Pairs `[name expr]` (Clojure forms) that bind the destructuring form `b`
  to the value of the local `v`."
  [ctx b v form]
  (cond
    (symbol? b) [[b v]]

    (vector? b)
    (let [[items tail] (split-with #(not (#{'& :as} %)) b)
          rest-name (second (drop-while #(not= '& %) b))
          as-name (second (drop-while #(not= :as %) b))]
      (when (some #{'&} tail)
        (when-not rest-name (fail "& needs a name" form)))
      (concat (when as-name [[as-name v]])
              (mapcat (fn [i item]
                        (let [x (if (symbol? item) item (fresh! ctx "d"))]
                          (cons [x (list ::at i v)]
                                (when-not (symbol? item) (destructure-pairs ctx item x form)))))
                      (range) items)
              (when rest-name
                (let [x (if (symbol? rest-name) rest-name (fresh! ctx "d"))]
                  (cons [x (list 'clojure.core/nthnext v (count items))]
                        (when-not (symbol? rest-name) (destructure-pairs ctx rest-name x form)))))))

    (map? b)
    (let [defaults (:or b)
          as-name (:as b)
          keyed (concat (for [k (:keys b)] [(symbol (name k)) (keyword (name k))])
                        (for [[k f] b :when (not (keyword? k))] [k f]))]
      (concat (when as-name [[as-name v]])
              (mapcat (fn [[x k]]
                        (when-not (keyword? k) (fail "map destructuring takes keyword keys of a structure" form))
                        (let [y (if (symbol? x) x (fresh! ctx "d"))
                              access (if (contains? defaults y)
                                       (list ::get-or v k (get defaults y))
                                       (list ::get v k))]
                          (cons [y access] (when-not (symbol? x) (destructure-pairs ctx x y form)))))
                      keyed)))

    :else (fail "cannot destructure" form)))


(defn- tr-bindings
  "Lean `let` pairs and the context after Clojure binding pairs, destructuring
  each binding into plain names."
  [ctx pairs form]
  (loop [pairs pairs ctx ctx acc []]
    (if-let [[b v] (first pairs)]
      (if (symbol? b)
        (recur (rest pairs) (bind ctx [b]) (conj acc b (tr ctx v)))
        (let [x (fresh! ctx "d")]
          (recur (concat (destructure-pairs ctx b x form) (rest pairs))
                 (bind ctx [x])
                 (conj acc x (tr ctx v)))))
      [acc ctx])))


(defn- tr-let
  [ctx [bs body & more] form]
  (when-not (and (vector? bs) (even? (count bs))) (fail "let needs a binding vector" form))
  (when (seq more) (fail "a let body with several forms discards all but the last, which a model cannot express" form))
  (let [[acc ctx'] (tr-bindings ctx (partition 2 bs) form)]
    (if (empty? acc) (tr ctx' body) (list 'let acc (tr ctx' body)))))


(defn- tr-if-some
  "`if-let` checks that the value is truthy and `if-some` that it is not nil;
  on `Option α` both take the `some` branch, and `if-let` also checks the
  element."
  [ctx truthy? [bs t e] form]
  (when-not (and (vector? bs) (= 2 (count bs))) (fail "needs one binding" form))
  (let [[b v] bs
        x (if (symbol? b) b (fresh! ctx "d"))
        body (lifted (tr (bind ctx [x]) (if (symbol? b) t (list 'clojure.core/let [b x] t))) e)
        else (lifted (tr ctx e) t)]
    (list 'match-eq (fresh! ctx "_h") (tr ctx v)
          (list 'some x) (if truthy? (list 'if (list 'Clj.truthy x) body else) body)
          'none else)))


(defn- tr-fn
  [ctx [params & body] form]
  (when-not (and (vector? params) (not-any? #{'&} params) (= 1 (count body)))
    (fail "fn needs one arity of fixed parameters and one body form" form))
  (let [xs (mapv #(if (symbol? %) % (fresh! ctx "p")) params)
        destr (mapcat (fn [p x] (when-not (symbol? p) [p x])) params xs)
        body (if (seq destr) (list 'clojure.core/let (vec destr) (first body)) (first body))]
    (list 'fn xs (tr (-> (bind ctx xs) (dissoc :recur)) body))))


(defn- tr-case
  [ctx [x & clauses] form]
  (let [default? (odd? (count clauses))
        pairs (partition 2 clauses)
        pattern #(cond (keyword? %) (field %)
                       (or (number? %) (string? %) (char? %) (boolean? %)) %
                       :else (fail "case takes keyword and literal constants" form))]
    (list* 'match (tr ctx x)
           (concat (vec (mapcat (fn [[p e]] [(pattern p) (tr ctx e)]) pairs))
                   (when default? ['_ (tr ctx (last clauses))])))))


(defn- tr-loop
  "A `leanfran.typed/loop` becomes a local `let rec`; `recur` calls it. The
  loop's value has the type `:ret` of the binding vector's metadata, or the
  function's return type."
  [ctx [bindings body] form]
  (let [triples (partition 3 bindings)
        vars (mapv first triples)
        helper (symbol (str "loop" (swap! (:counter ctx) inc)))
        m (meta bindings)
        inner (-> (bind ctx vars)
                  (assoc :recur {:helper helper :arity (count vars)}))]
    (when-not (every? symbol? vars) (fail "loop variables are plain names" form))
    (list 'let-rec (with-meta helper (select-keys m [:termination-by :decreasing-by]))
          (vec (mapcat (fn [[x t _]] [x t]) triples))
          (or (:ret m) (:ret ctx))
          (tr inner body)
          (list* helper (mapv #(tr ctx (nth % 2)) triples)))))


(defn- tr-letfn
  "`leanfran.typed/letfn`: local functions with Lean signatures, as `let rec`
  each, in order."
  [ctx [fns body] form]
  (let [names (map first fns)
        ctx' (bind ctx names)]
    (reduce (fn [acc [nm bs ret fbody & more]]
              (when (seq more) (fail "a letfn function takes one body form" form))
              (let [params (take-nth 2 bs)]
                (when-not (every? symbol? params) (fail "letfn parameters are plain names" form))
                (list 'let-rec (with-meta nm (select-keys (meta nm) [:termination-by :decreasing-by]))
                      bs ret
                      (tr (-> (bind ctx' params) (assoc :recur {:helper nm :arity (count params)})) fbody)
                      acc)))
            (tr ctx' body)
            (reverse fns))))


(defn- tr-recur
  [ctx args form]
  (let [{:keys [helper arity]} (:recur ctx)]
    (cond
      (nil? (:recur ctx)) (fail "recur outside leanfran.typed/loop, leanfran.typed/letfn, or the function body; fn has no Lean signature to recur with" form)
      (not= arity (count args)) (fail "recur with the wrong number of arguments" form)
      :else (list* helper (tr-all ctx args)))))


;; Calls

(defn- tr-arg
  [ctx fn-args i x]
  (if (and (keyword? x) (contains? fn-args i)) (getter ctx x) (tr ctx x)))


(defn- fold
  [f xs]
  (reduce (fn [acc x] (list f acc x)) xs))


(defn- tr-core
  [ctx sym args form]
  (let [n (count args)]
    (cond
      (folds sym) (if (zero? n) (fail "needs at least one argument" form) (fold (folds sym) (tr-all ctx args)))
      (chains sym) (if (< n 2)
                     (fail "needs at least two arguments" form)
                     (let [xs (tr-all ctx args)]
                       (fold '&& (map (fn [[a b]] (list (chains sym) a b)) (partition 2 1 xs)))))
      (#{'- '-'} sym) (case n
                        0 (fail "needs at least one argument" form)
                        1 (list 'Clj.neg (tr ctx (first args)))
                        (fold 'Clj.sub (tr-all ctx args)))
      (= 'not= sym) (if (< n 2)
                      (fail "needs at least two arguments" form)
                      (list 'not (tr-core ctx '= args form)))
      (= 'str sym) (if (zero? n) "" (fold '++ (map #(list 'Clj.str %) (tr-all ctx args))))
      (= '/ sym) (case n
                   0 (fail "needs at least one argument" form)
                   1 (list 'Clj.div 1.0 (tr ctx (first args)))
                   (fold 'Clj.div (tr-all ctx args)))
      (and (= 'reduce sym) (= 2 n)) (let [[f coll] args
                                          coll' (tr ctx coll)]
                                      (cond
                                        (var-is? ctx f 'clojure.core/+) (list 'Clj.reduce 'Clj.add 0 coll')
                                        (var-is? ctx f 'clojure.core/*) (list 'Clj.reduce 'Clj.mul 1 coll')
                                        (var-is? ctx f 'clojure.core/str) (list 'Clj.Str'.join1 coll')
                                        :else (list 'Clj.reduce1 (tr-arg ctx #{0} 0 f) coll')))
      (= 'apply sym) (let [[f coll & more] args]
                       (when (seq more) (fail "apply takes a function and one collection" form))
                       (cond
                         (var-is? ctx f 'clojure.core/+) (list 'Clj.reduce 'Clj.add 0 (tr ctx coll))
                         (var-is? ctx f 'clojure.core/*) (list 'Clj.reduce 'Clj.mul 1 (tr ctx coll))
                         (var-is? ctx f 'clojure.core/str) (list 'Clj.Str'.join1 (tr ctx coll))
                         (var-is? ctx f 'clojure.core/max) (list 'Clj.reduce1 'Clj.max (tr ctx coll))
                         (var-is? ctx f 'clojure.core/min) (list 'Clj.reduce1 'Clj.min (tr ctx coll))
                         :else (fail "apply takes +, *, str, max, or min, whose models fold a collection" form)))
      (= 'identity sym) (if (= 1 n) (tr ctx (first args)) (fail "identity takes one argument" form))
      (= 'comp sym) (let [x (fresh! ctx "x")]
                      (list 'fn [x] (reduce (fn [acc f] (list (tr-arg ctx #{0} 0 f) acc)) x (reverse args))))
      (= 'partial sym) (let [[f & bound] args
                             x (fresh! ctx "x")]
                         (list 'fn [x] (concat (list (tr-arg ctx #{0} 0 f)) (tr-all ctx bound) [x])))
      (= 'constantly sym) (list 'fn [(fresh! ctx "_x")] (tr ctx (first args)))
      (= 'subs sym) (case n
                      2 (list* 'Clj.subsFrom (tr-all ctx args))
                      3 (list* 'Clj.subs (tr-all ctx args))
                      (fail "subs takes two or three arguments" form))
      (= 'list sym) (tr-all ctx args)
      (= 'vector sym) (tr ctx (vec args))
      (= 'range sym) (case n
                       1 (list 'Clj.range (tr ctx (first args)))
                       2 (list 'Clj.range2 (tr ctx (first args)) (tr ctx (second args)))
                       (fail "range takes one or two arguments" form))
      (= 'nth sym) (case n
                     2 (list* 'Clj.nth (tr-all ctx args))
                     3 (list* 'Clj.nth3 (tr-all ctx args))
                     (fail "nth takes two or three arguments" form))
      (= 'get sym) (let [[m k] args]
                     (cond
                       (and (keyword? k) (= 2 n)) (list (field k) (tr ctx m))
                       (and (keyword? k) (= 3 n)) (list (field k) (tr ctx m))
                       (= 2 n) (list 'Clj.get (tr ctx m) (tr ctx k))
                       :else (list 'Option.getD (list 'Clj.get (tr ctx m) (tr ctx k)) (tr ctx (nth args 2)))))
      (= 'fnil sym) (let [[f d & more] args
                          x (fresh! ctx "x")]
                      (when (seq more) (fail "fnil takes a function and one default" form))
                      (list 'fn [x] (list (tr-arg ctx #{0} 0 f) (list 'Option.getD x (tr ctx d)))))
      (= 'assoc sym) (let [[m & kvs] args]
                       (when-not (and (seq kvs) (even? (count kvs))) (fail "assoc takes keys and values" form))
                       (if (every? keyword? (take-nth 2 kvs))
                         (list 'with (tr ctx m) (into {} (map (fn [[k x]] [k (tr ctx x)]) (partition 2 kvs))))
                         (reduce (fn [acc [k x]] (list 'Clj.assoc acc (tr ctx k) (tr ctx x))) (tr ctx m) (partition 2 kvs))))
      (= 'update sym) (let [[m k f & more] args
                            m' (tr ctx m)
                            f' (if (keyword? f) (getter ctx f) (tr ctx f))]
                        (if (keyword? k)
                          (list 'with m' {k (list* f' (list (field k) m') (tr-all ctx more))})
                          (let [x (fresh! ctx "x")]
                            (list 'Clj.update m' (tr ctx k)
                                  (if (seq more) (list 'fn [x] (list* f' x (tr-all ctx more))) f')))))
      (= 'dissoc sym) (reduce (fn [acc k] (list 'Clj.dissoc acc (tr ctx k))) (tr ctx (first args)) (rest args))
      (= 'disj sym) (reduce (fn [acc k] (list 'Clj.disj acc (tr ctx k))) (tr ctx (first args)) (rest args))
      (= 'merge sym) (if (empty? args) (fail "merge needs a map" form) (fold 'Clj.merge (tr-all ctx args)))
      (= 'hash-map sym) (tr ctx (apply hash-map args))
      (= 'hash-set sym) (tr ctx (set args))
      (#{'keys 'vals} sym) (fail (str sym " lists a hash map in hash order, which a model cannot state; use get, contains?, or count") form)

      (fns sym) (let [{:keys [model arity fn-args]} (fns sym)]
                  (if (contains? arity n)
                    (list* model (vec (map-indexed (fn [i x] (tr-arg ctx (or fn-args #{}) i x)) args)))
                    (fail (str "the model of " sym " takes " (str/join " or " (sort arity)) " arguments") form)))
      :else (fail (str "clojure.core/" sym " has no model in Clj") form))))


(defn- string-var?
  [^clojure.lang.Var v]
  (= 'clojure.string (ns-name (.ns v))))


(defn- set-var?
  [^clojure.lang.Var v]
  (= 'clojure.set (ns-name (.ns v))))


(defn- plain-regex
  "The string a regular expression literal matches, when it has no
  metacharacters."
  [x form]
  (let [s (str x)]
    (if (and (instance? java.util.regex.Pattern x) (not (re-find #"[\\.\[\]{}()*+?^$|]" s)))
      s
      (fail "split takes a regular expression literal of plain characters" form))))


(defn- tr-string
  [ctx sym args form]
  (let [n (count args)]
    (cond
      (= 'join sym) (case n
                      1 (list 'Clj.Str'.join1 (tr ctx (first args)))
                      2 (list 'Clj.Str'.join (tr ctx (first args)) (tr ctx (second args)))
                      (fail "join takes one or two arguments" form))
      (= 'split sym) (if (= 2 n)
                       (list 'Clj.Str'.split (tr ctx (first args)) (plain-regex (second args) form))
                       (fail "split takes a string and a regular expression" form))
      (string-fns sym) (let [{:keys [model arity]} (string-fns sym)]
                         (if (contains? arity n)
                           (list* model (tr-all ctx args))
                           (fail (str "the model of clojure.string/" sym " takes " (str/join " or " (sort arity)) " arguments") form)))
      :else (fail (str "clojure.string/" sym " has no model in Clj") form))))


(defn- tr-call
  [ctx [head & args :as form]]
  (let [v (when (symbol? head) (resolve-var ctx head))]
    (cond
      (keyword? head) (case (count args)
                        1 (list (field head) (tr ctx (first args)))
                        2 (list (field head) (tr ctx (first args)))
                        (fail "a keyword takes a map and an optional default" form))
      (and v (typed-var? v)) (typed-call ctx v args form)
      (and v (lean-var? v)) (do (swap! (:modules ctx) conj (:lean/module (meta v)))
                                (list* (symbol (:lean/name (meta v))) (tr-all ctx args)))
      (and v (string-var? v)) (tr-string ctx (.sym ^clojure.lang.Var v) args form)
      (and v (set-var? v)) (let [{:keys [model arity]} (set-fns (.sym ^clojure.lang.Var v))]
                             (cond
                               (nil? model) (fail (str "clojure.set/" (.sym ^clojure.lang.Var v) " has no model in Clj") form)
                               (contains? arity (count args)) (list* model (tr-all ctx args))
                               :else (fold model (tr-all ctx args))))
      (and v (core-var? v)) (tr-core ctx (.sym ^clojure.lang.Var v) args form)
      v (fail (str head " is not a leanfran.typed/defn function, a function from Lean, or modelled in Clj") form)
      (local? ctx head) (list* head (tr-all ctx args))
      (seq? head) (list* (tr ctx head) (tr-all ctx args))
      :else (fail "cannot translate the call" form))))


(defn- macro-var?
  [ctx sym]
  (when (symbol? sym)
    (when-let [v (resolve-var ctx sym)]
      (:macro (meta v)))))


(defn- quoted
  [x form]
  (cond
    (or (number? x) (string? x) (char? x) (boolean? x) (keyword? x) (nil? x)) x
    (seq? x) (apply list 'clojure.core/list (map #(quoted % form) x))
    (vector? x) (apply list 'clojure.core/vector (map #(quoted % form) x))
    :else (fail "quoted data takes numbers, strings, characters, booleans, keywords, lists, and vectors" form)))


(defn- tr-internal
  [ctx [head & args :as form]]
  (case head
    ::at (let [[i v] args] (list 'Clj.elem i (tr ctx v)))
    ::get (let [[v k] args] (list (field k) (tr ctx v)))
    ::get-or (let [[v k _] args] (list (field k) (tr ctx v)))
    (fail "internal form" form)))


(defn- tr-seq
  [ctx [head & args :as form]]
  (let [is? #(var-is? ctx head %)]
    (cond
      (#{::at ::get ::get-or} head) (tr-internal ctx form)
      (= 'if head) (case (count args)
                     3 (apply tr-if ctx args)
                     2 (tr-if ctx (first args) (second args) nil)
                     (fail "if takes two or three forms" form))
      (= 'do head) (if (= 1 (count args))
                     (tr ctx (first args))
                     (fail "do with several forms runs the others for their effects, which a model cannot express" form))
      (= 'recur head) (tr-recur ctx args form)
      (= 'quote head) (tr ctx (quoted (first args) form))
      (is? 'clojure.core/when) (if (= 2 (count args))
                                 (tr-if ctx (first args) (second args) nil)
                                 (fail "when with several body forms discards all but the last, which a model cannot express" form))
      (is? 'clojure.core/when-not) (if (= 2 (count args))
                                     (tr-if ctx (list 'clojure.core/not (first args)) (second args) nil)
                                     (fail "when-not with several body forms" form))
      (is? 'clojure.core/if-not) (tr-if ctx (list 'clojure.core/not (first args)) (second args) (nth args 2 nil))
      (is? 'clojure.core/cond) (tr-cond ctx args form)
      (is? 'clojure.core/if-let) (tr-if-some ctx true [(first args) (second args) (nth args 2 nil)] form)
      (is? 'clojure.core/when-let) (tr-if-some ctx true [(first args) (second args) nil] form)
      (is? 'clojure.core/if-some) (tr-if-some ctx false [(first args) (second args) (nth args 2 nil)] form)
      (is? 'clojure.core/when-some) (tr-if-some ctx false [(first args) (second args) nil] form)
      (is? 'clojure.core/and) (if (empty? args) true (tr-and ctx args))
      (is? 'clojure.core/or) (if (empty? args) 'none (tr-or ctx args))
      (is? 'clojure.core/let) (tr-let ctx args form)
      (is? 'clojure.core/fn) (tr-fn ctx args form)
      (is? 'clojure.core/case) (tr-case ctx args form)
      (is? 'leanfran.typed/loop) (tr-loop ctx args form)
      (is? 'leanfran.typed/letfn) (tr-letfn ctx args form)
      (is? 'clojure.core/loop) (fail "use leanfran.typed/loop, whose bindings carry Lean types" form)
      (is? 'clojure.core/letfn) (fail "use leanfran.typed/letfn, whose functions carry Lean signatures" form)
      (is? 'clojure.core/doto) (fail "doto runs forms for their effects, which a model cannot express" form)
      (macro-var? ctx head) (tr ctx (binding [*ns* (the-ns (:ns ctx))] (macroexpand-1 form)))
      :else (tr-call ctx form))))


(defn- tr-test
  "A form in the position of a condition: `and` and `or` give `Bool`."
  [ctx x]
  (if (and (seq? x) (symbol? (first x)))
    (let [is? #(var-is? ctx (first x) %)
          args (rest x)]
      (cond
        (is? 'clojure.core/and) (if (empty? args) true (fold '&& (map #(list 'Clj.truthy (tr-test ctx %)) args)))
        (is? 'clojure.core/or) (if (empty? args) false (fold '|| (map #(list 'Clj.truthy (tr-test ctx %)) args)))
        :else (tr ctx x)))
    (tr ctx x)))


(defn- tr
  [ctx x]
  (cond
    (nil? x) 'none
    (seq? x) (if (empty? x) [] (tr-seq ctx x))
    (keyword? x) (field x)
    (symbol? x) (if (local? ctx x)
                  x
                  (let [v (resolve-var ctx x)]
                    (cond
                      (nil? v) (fail "unresolved symbol" x)
                      (typed-var? v) (do (swap! (:deps ctx) conj v)
                                         (let [sig (:lean/sig (meta v))]
                                           (arity-name sig (pick-arity sig 1 x))))
                      (lean-var? v) (do (swap! (:modules ctx) conj (:lean/module (meta v)))
                                        (symbol (:lean/name (meta v))))
                      (string-var? v) (or (:model (string-fns (.sym ^clojure.lang.Var v)))
                                          (fail (str "clojure.string/" (.sym ^clojure.lang.Var v) " has no model in Clj") x))
                      (core-var? v) (value-of-core (.sym ^clojure.lang.Var v) x)
                      :else (fail (str x " is not a leanfran.typed/defn function, a function from Lean, or modelled in Clj") x))))
    (or (string? x) (char? x) (boolean? x) (integer? x)) x
    (double? x) (if (Double/isFinite x) x (fail "a model takes finite floating-point literals" x))
    (map? x) (cond
               (empty? x) 'Clj.Map.empty
               (every? keyword? (keys x)) (into {} (map (fn [[k v]] [k (tr ctx v)]) x))
               :else (list 'Clj.mapOf (mapv (fn [[k v]] (list '<> (tr ctx k) (tr ctx v))) x)))
    (set? x) (list 'Clj.setOf (tr-all ctx (vec x)))
    (vector? x) (case (count x)
                  0 (list 'array)
                  2 (list* 'Clj.vec2 (tr-all ctx x))
                  (list* 'array (tr-all ctx x)))
    :else (fail "outside the translated subset" x)))


;; Models

(defn- arity-parts
  [a]
  (types/binder-parts (:binders a)))


(defn- arity-name
  "Lean name of the model of the arity `a` of a translated function."
  [{:keys [name arities]} a]
  (if (= 1 (count arities))
    name
    (let [{:keys [params rest]} (arity-parts a)]
      (symbol (str name ".arity" (count params) (when rest "v"))))))


(defn- pick-arity
  "The arity of `sig` that a call with `n` arguments takes: a fixed one, else
  the one with rest arguments."
  [sig n form]
  (let [fits (fn [a]
               (let [{:keys [params rest]} (arity-parts a)]
                 (if rest (>= n (count params)) (= n (count params)))))]
    (or (first (filter #(and (fits %) (not (:rest (arity-parts %)))) (:arities sig)))
        (first (filter fits (:arities sig)))
        (fail (str (:name sig) " has no arity for " n " arguments") form))))


(defn- typed-call
  [ctx v args form]
  (swap! (:deps ctx) conj v)
  (let [sig (:lean/sig (meta v))
        a (pick-arity sig (count args) form)
        {:keys [params rest]} (arity-parts a)
        [fixed more] (split-at (count params) args)]
    (list* (arity-name sig a)
           (concat (tr-all ctx fixed) (when rest [(tr-all ctx more)])))))


(defn- extern-name
  [{:keys [ns name]} variadic?]
  (str (if variadic? "clj&:" "clj:") ns "/" name))


(defn- model-of
  "The models of the arities of the function `v`: their commands, the
  translated functions they call, and the Lean modules of the functions from
  Lean they call. A polymorphic arity has no `@[extern]`: its type arguments
  have no Clojure value to pass. It takes `[Clj.Truthy α]` for each type
  variable, so that a Clojure test of an `α` value uses the truthiness of the
  type the caller instantiates `α` with."
  [v extern?]
  (let [{:keys [arities] :as sig} (:lean/sig (meta v))
        deps (atom #{})
        modules (atom #{})
        commands
        (vec (for [a arities]
               (let [{:keys [params rest type-params]} (arity-parts a)
                     counter (atom 0)
                     pairs (cond-> params rest (conj rest))
                     xs (mapv (fn [[p _]] (if (symbol? p) p (symbol (str "arg" (swap! counter inc))))) pairs)
                     destr (mapcat (fn [[p _] x] (when-not (symbol? p) [p x])) pairs xs)
                     model (arity-name sig a)
                     ctx {:ns (:ns sig)
                          :name model
                          :ret (:ret a)
                          :locals (zipmap xs (repeat nil))
                          :recur {:helper model :arity (count xs)}
                          :counter counter
                          :deps deps
                          :modules modules}
                     body (if (seq destr) (list 'clojure.core/let (vec destr) (:body a)) (:body a))
                     body' (binding [*where* (select-keys sig [:file :line :name])] (tr ctx body))
                     m (cond-> (select-keys sig [:termination-by :decreasing-by])
                         (seq type-params) (assoc :private true)
                         (and extern? (empty? type-params)) (assoc :attrs [(str "extern \"" (extern-name sig rest) "\"")]))]
                 (list 'def (with-meta model m)
                       (vec (concat type-params
                                    (for [[kind tv] type-params :when (= 'implicit kind)] (list 'inst (list 'Clj.Truthy tv)))
                                    (mapcat (fn [x [_ t]] [x t]) xs pairs)))
                       (:ret a) body'))))]
    {:commands commands
     :deps (disj @deps v)
     :modules @modules}))


(defn- sccs
  "Strongly connected components of `graph` (node → successors), callees
  first."
  [nodes graph]
  (let [index (atom 0) stack (atom []) on (atom #{}) idx (atom {}) low (atom {}) out (atom [])]
    (letfn [(visit
              [v]
              (swap! idx assoc v @index)
              (swap! low assoc v @index)
              (swap! index inc)
              (swap! stack conj v)
              (swap! on conj v)
              (doseq [w (graph v)]
                (cond
                  (not (contains? @idx w)) (do (visit w) (swap! low update v min (@low w)))
                  (@on w) (swap! low update v min (@idx w))))
              (when (= (@low v) (@idx v))
                (loop [c []]
                  (let [w (peek @stack)]
                    (swap! stack pop)
                    (swap! on disj w)
                    (if (= w v) (swap! out conj (conj c w)) (recur (conj c w)))))))]
      (doseq [v nodes :when (not (contains? @idx v))] (visit v)))
    @out))


(defn models
  "`leanfran.dsl` commands of the Lean models of the `leanfran.typed/defn`
  vars `vs` and of the functions they call, callees first and mutually
  recursive ones in `mutual`, with the Lean modules they need. With `extern?`,
  each model is `@[extern]` to its Clojure var, so that compiled Lean calls the
  Clojure function."
  [vs extern?]
  (let [found (loop [todo (vec vs) found {}]
                (if-let [v (first todo)]
                  (cond
                    (contains? found v) (recur (subvec todo 1) found)
                    (not (typed-var? v)) (throw (ex-info (str "leanfran.translate: " v " is not defined with leanfran.typed/defn") {:var v}))
                    :else (let [m (model-of v extern?)]
                            (recur (into (subvec todo 1) (sort-by str (:deps m))) (assoc found v m))))
                  found))
        names (map #(:name (:lean/sig (meta %))) (keys found))]
    (when-not (apply distinct? (map str names))
      (throw (ex-info "leanfran.translate: two translated functions share a name" {:names names})))
    {:commands (vec (for [c (sccs (sort-by str (keys found)) #(sort-by str (:deps (found %))))]
                      (if (= 1 (count c))
                        (if (= 1 (count (:commands (found (first c)))))
                          (first (:commands (found (first c))))
                          (list* 'mutual (:commands (found (first c)))))
                        (list* 'mutual (mapcat #(:commands (found %)) (sort-by str c))))))
     :modules (set (mapcat :modules (vals found)))}))


(defn clojure-command?
  "Whether `x` is the deflean command `(clojure f ...)`."
  [x]
  (and (seq? x) (= 'clojure (first x))))


(defn render-command
  "`(clojure f ...)` in the namespace `ns`: `:text`, the Lean source of the
  models of the named functions and of the functions they call (`@[extern]` to
  the Clojure vars with `extern?`), and `:modules`, the Lean modules they
  need."
  [ns [_ & syms :as cmd] extern?]
  (let [vs (mapv (fn [s]
                   (or (when (symbol? s) (ns-resolve ns s))
                       (throw (ex-info (str "leanfran.translate: cannot resolve " s " in " (pr-str cmd)) {:command cmd}))))
                 syms)
        {:keys [commands modules]} (models vs extern?)]
    {:text (dsl/render commands) :modules modules}))
