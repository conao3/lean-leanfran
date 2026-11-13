(ns leanfran.types
  "Lean types written as `leanfran.dsl` terms, and what leanfran derives from
  them: test.check generators of the Clojure values that correspond to a type,
  a check of such values, malli schemas, and clj-kondo types.

  Structures and enumerations are known by the Lean name they are written
  with in a `deflean` block (`register-commands!`)."
  (:require
    [clojure.java.io :as io]
    [clojure.pprint :as pprint]
    [clojure.string :as str]
    [clojure.test.check.generators :as gen]
    [clojure.walk :as walk]
    [leanfran.dsl :as dsl]
    [leanfran.runtime :as runtime]))


(set! *warn-on-reflection* true)


(defonce ^{:doc "Structures and enumerations by full Lean name:
  `{:kind :struct :module m :fields [[field type] ...]}` or
  `{:kind :enum :module m :ctors [ctor ...]}`."}
  types
  (atom {}))


(defn kebab
  "Clojure name of a Lean name component, as the generated code writes it
  (`ownerName` → `owner-name`)."
  [^String s]
  (let [n (count s)]
    (loop [i 0 acc (StringBuilder.)]
      (if (= i n)
        (str acc)
        (let [c (.charAt s i)
              prev (when (pos? i) (.charAt s (dec i)))
              nxt (when (< (inc i) n) (.charAt s (inc i)))]
          (if (Character/isUpperCase c)
            (do (when (or (and prev (or (Character/isLowerCase (char prev)) (Character/isDigit (char prev))))
                          (and prev nxt (Character/isLowerCase (char nxt)) (Character/isUpperCase (char prev))))
                  (.append acc \-))
                (recur (inc i) (.append acc (Character/toLowerCase c))))
            (recur (inc i) (.append acc c))))))))


(defn- field-key
  [f]
  (keyword (kebab (dsl/ident f))))


(defn- register-command!
  [module prefix cmd]
  (when (seq? cmd)
    (let [[head & args] cmd]
      (case head
        structure (let [[nm & more] args
                        vs (filter vector? more)
                        fs (if (= 2 (count vs)) (second vs) (first vs))]
                    (when (= 1 (count vs))
                      (swap! types assoc (str module "." prefix (dsl/ident nm))
                             {:kind :struct :module module :fields (mapv vec (partition 2 fs))})))
        inductive (let [[nm & more] args
                        ctors (remove #(and (seq? %) (= 'deriving (first %))) more)]
                    (cond
                      (and (seq ctors) (every? symbol? ctors))
                      (swap! types assoc (str module "." prefix (dsl/ident nm))
                             {:kind :enum :module module :ctors (vec ctors)})

                      (and (seq ctors) (not (vector? (first more))))
                      (swap! types assoc (str module "." prefix (dsl/ident nm))
                             {:kind :sum :module module
                              :ctors (mapv (fn [c]
                                             (if (symbol? c)
                                               {:name c :fields []}
                                               {:name (first c) :fields (mapv vec (partition 2 (second c)))}))
                                           ctors)})))
        namespace (doseq [c (rest args)]
                    (register-command! module (str prefix (dsl/ident (first args)) ".") c))
        mutual (doseq [c args] (register-command! module prefix c))
        nil))))


(defn register-commands!
  "Record the monomorphic structures and enumerations among the
  `leanfran.dsl` commands of the Lean module `module`."
  [module cmds]
  (doseq [c cmds] (register-command! module "" c)))


(defn- desc-type
  "Lean type of a marshalling descriptor of the generated code, or nil for
  one without a Clojure value form here."
  [d]
  (if (keyword? d)
    ({:nat 'Nat :int 'Int :bool 'Bool :string 'String :char 'Char :float 'Float} d)
    (let [[k a b] d
          ta (when (some? a) (if (string? a) (symbol a) (desc-type a)))]
      (case k
        :list (when ta (list 'List ta))
        :array (when ta (list 'Array ta))
        :option (when ta (list 'Option ta))
        :prod (when-let [tb (desc-type b)] (when ta (list 'Prod ta tb)))
        :map (when-let [tb (desc-type b)] (when ta (list 'Map ta tb)))
        :set (when ta (list 'Set ta))
        :ref ta
        nil))))


(defn- runtime-types
  "Structures and enumerations that generated code registered at load time,
  including those written as Lean source and those of CLI-generated
  namespaces."
  []
  (into {}
        (for [[k {:keys [kind module fields ctors]}] (runtime/registered-types)]
          [k (case kind
               :struct {:kind :struct :module module
                        :fields (mapv (fn [[f _ d]] [(symbol (name f)) (desc-type d)]) fields)}
               :enum {:kind :enum :module module :ctors (mapv #(symbol (name %)) ctors)}
               :sum {:kind :sum :module module
                     :ctors (mapv (fn [{:keys [name fields]}]
                                    {:name (symbol (clojure.core/name name))
                                     :fields (mapv (fn [[f _ d]] [(symbol (clojure.core/name f)) (desc-type d)]) fields)})
                                  ctors)})])))


(def ^:dynamic *preferred-module-prefix*
  "Among types of the same short name, the one whose module starts with this
  prefix (the deflean modules of one Clojure namespace)."
  nil)


(defn- entry
  "The registered type named `t`: by full Lean name, or by the last components
  when they name one type, or one type in modules under
  `*preferred-module-prefix*`."
  [t]
  (let [s (dsl/ident t)
        all (merge (runtime-types) @types)]
    (or (get all s)
        (let [hits (distinct (keep (fn [[k v]] (when (str/ends-with? k (str "." s)) (assoc v :name k))) all))
              preferred (when *preferred-module-prefix*
                          (filter #(some-> (:module %) (str/starts-with? *preferred-module-prefix*)) hits))
              [hits names] (if (= 1 (count (set (map :name preferred))))
                             [preferred (set (map :name preferred))]
                             [hits (set (map :name hits))])]
          (case (count names)
            0 nil
            1 (dissoc (first hits) :name)
            (throw (ex-info (str "leanfran.types: type " t " is ambiguous among " (str/join ", " (sort names)))
                            {:type t :names names})))))))


(defn module-of
  "Lean module that defines the structure or enumeration `t`, if registered."
  [t]
  (:module (entry t)))


(defn- lookup
  [t]
  (or (entry t)
      (throw (ex-info (str "leanfran.types: unknown type " t) {:type t}))))


(defn- head-of
  "The head of a type application, with `Clj.Map` and `Clj.Set` as `Map` and
  `Set`."
  [h]
  ({'Clj.Map 'Map 'Clj.Set 'Set} h h))


(defn- unsupported
  [t]
  (throw (ex-info (str "leanfran.types: type " (pr-str t) " has no Clojure value form") {:type t})))


(def ^:private big-nat
  (gen/fmap #(+ (bigint Long/MAX_VALUE) 1 %) gen/nat))


(def ^:private big-neg
  (gen/fmap #(- (bigint Long/MIN_VALUE) 1 %) gen/nat))


(def ^:dynamic *big-ints*
  "Whether `gen` mixes in integers beyond `Long`."
  true)


(def ^:private uint-max
  '{UInt8 255 UInt16 65535 UInt32 4294967295 UInt64 18446744073709551615 USize 18446744073709551615})


(defn- fin-bound
  [t]
  (when (and (seq? t) (= 'Fin (first t)) (integer? (second t))) (second t)))


(defn- tagged
  "The map of a constructor of a sum type, as the generated code passes it."
  [ctor]
  (field-key ctor))


(defn gen
  "test.check generator of the Clojure values of the Lean type `t`. Integers
  include values beyond `Long` while `*big-ints*` is true."
  [t]
  (cond
    (symbol? t)
    (case t
      Nat (if *big-ints* (gen/frequency [[9 gen/nat] [1 big-nat]]) gen/nat)
      Int (if *big-ints* (gen/frequency [[9 gen/small-integer] [1 big-nat] [1 big-neg]]) gen/small-integer)
      Bool gen/boolean
      String gen/string-ascii
      Char gen/char-ascii
      Float (gen/double* {:NaN? false :infinite? false})
      Unit (gen/return nil)
      (UInt8 UInt16 UInt32 UInt64 USize) (gen/fmap bigint (gen/large-integer* {:min 0 :max (min Long/MAX_VALUE (uint-max t))}))
      (let [{:keys [kind fields ctors]} (lookup t)]
        (case kind
          :struct (apply gen/hash-map (mapcat (fn [[f ft]] [(field-key f) (gen ft)]) fields))
          :enum (gen/elements (mapv field-key ctors))
          :sum (gen/one-of (for [{:keys [name fields]} ctors]
                             (gen/fmap #(assoc % :tag (tagged name))
                                       (apply gen/hash-map (mapcat (fn [[f ft]] [(field-key f) (gen ft)]) fields))))))))

    (seq? t)
    (let [[head a b] t
          head (head-of head)]
      (case head
        List (gen/fmap #(apply list %) (gen/vector (gen a)))
        Array (gen/vector (gen a))
        Option (if (and (seq? a) (= 'Option (first a)))
                 (unsupported t)
                 (gen/one-of [(gen/return nil) (gen a)]))
        Prod (gen/tuple (gen a) (gen b))
        Map (gen/map (gen a) (gen b))
        Set (gen/set (gen a))
        Fin (if-let [n (fin-bound t)] (gen/choose 0 (dec n)) (unsupported t))
        (unsupported t)))

    :else (unsupported t)))


(defn valid?
  "Whether `x` is a Clojure value of the Lean type `t`, telling lists from
  vectors as the generated code does."
  [t x]
  (cond
    (symbol? t)
    (case t
      Nat (and (integer? x) (not (neg? x)))
      Int (integer? x)
      Bool (boolean? x)
      String (string? x)
      Char (char? x)
      Float (double? x)
      Unit (nil? x)
      (UInt8 UInt16 UInt32 UInt64 USize) (and (integer? x) (<= 0 x (uint-max t)))
      (let [{:keys [kind fields ctors]} (lookup t)
            valid-fields (fn [fields m] (every? (fn [[f ft]] (valid? ft (get m (field-key f)))) fields))]
        (case kind
          :struct (and (map? x)
                       (= (set (map (comp field-key first) fields)) (set (keys x)))
                       (valid-fields fields x))
          :enum (contains? (set (map field-key ctors)) x)
          :sum (and (map? x)
                    (some (fn [{:keys [name fields]}]
                            (and (= (tagged name) (:tag x))
                                 (= (set (cons :tag (map (comp field-key first) fields))) (set (keys x)))
                                 (valid-fields fields x)))
                          ctors)
                    true))))

    (seq? t)
    (let [[head a b] t
          head (head-of head)]
      (case head
        List (and (seq? x) (every? #(valid? a %) x))
        Array (and (vector? x) (every? #(valid? a %) x))
        Option (or (nil? x) (valid? a x))
        Prod (and (vector? x) (= 2 (count x)) (valid? a (first x)) (valid? b (second x)))
        Map (and (map? x) (every? (fn [[k v]] (and (valid? a k) (valid? b v))) x))
        Set (and (set? x) (every? #(valid? a %) x))
        Fin (if-let [n (fin-bound t)] (and (integer? x) (<= 0 x (dec n))) (unsupported t))
        (unsupported t)))

    :else (unsupported t)))


(defn malli-schema
  "malli schema of the Clojure values of the Lean type `t`, as data."
  [t]
  (cond
    (= '_ t) :any

    (symbol? t)
    (case t
      Nat [:and 'integer? [:>= 0]]
      Int 'integer?
      Bool :boolean
      String :string
      Char 'char?
      Float :double
      Unit :nil
      (UInt8 UInt16 UInt32 UInt64 USize) [:and 'integer? [:>= 0] [:<= (uint-max t)]]
      (let [{:keys [kind fields ctors]} (lookup t)
            entries (fn [fields] (map (fn [[f ft]] [(field-key f) (malli-schema ft)]) fields))]
        (case kind
          :struct (into [:map {:closed true}] (entries fields))
          :enum (into [:enum] (map field-key ctors))
          :sum (into [:multi {:dispatch :tag}]
                     (for [{:keys [name fields]} ctors]
                       [(tagged name) (into [:map {:closed true} [:tag [:= (tagged name)]]] (entries fields))])))))

    (seq? t)
    (let [[head a b] t
          head (head-of head)]
      (case head
        List [:sequential (malli-schema a)]
        Array [:vector (malli-schema a)]
        Option (if (and (seq? a) (= 'Option (first a)))
                 (unsupported t)
                 [:maybe (malli-schema a)])
        Prod [:tuple (malli-schema a) (malli-schema b)]
        Map [:map-of (malli-schema a) (malli-schema b)]
        Set [:set (malli-schema a)]
        Fin (if-let [n (fin-bound t)] [:and 'integer? [:>= 0] [:< n]] (unsupported t))
        (unsupported t)))

    :else (unsupported t)))


(defn binder-parts
  "The parts of a `leanfran.typed` binder vector `[x T ... & xs (List T)]`:
  `:params`, the `[name type]` pairs of the fixed parameters, `:rest`, the pair
  after `&`, `:type-params`, the binder lists (`(implicit α Type)`,
  `(inst (BEq α))`) that are not Clojure parameters, `:type-vars`, the names
  they bind, and `:args`, the Clojure argument vector."
  [bs]
  (loop [bs (seq bs) params [] specials [] rest-param nil]
    (if-not bs
      {:params params
       :rest rest-param
       :type-params specials
       :type-vars (set (keep (fn [[kind x]] (when (#{'implicit 'strict} kind) x)) specials))
       :args (vec (concat (map first params) (when rest-param ['& (first rest-param)])))}
      (let [b (first bs)]
        (cond
          (seq? b) (recur (next bs) params (conj specials b) rest-param)
          (= '& b) (let [[_ n t & more] bs]
                     (when (or (nil? t) (seq more))
                       (throw (ex-info "leanfran.types: & takes one name and its List type, last" {:binders bs})))
                     (recur nil params specials [n t]))
          (nil? (next bs)) (throw (ex-info (str "leanfran.types: binder " b " has no type") {:binders bs}))
          :else (recur (nnext bs) (conj params [b (second bs)]) specials rest-param))))))


(defn- with-vars
  "`f` of a type whose type variables `vars` stand for any value."
  [f vars _ t]
  (f (walk/postwalk #(if (and (symbol? %) (contains? vars %)) '_ %) t)))


(defn fn-schema
  "malli function schema of a `leanfran.typed/defn` var, for
  `malli.core/=>`: `[:=> [:cat T ...] R]`, or `[:function ...]` of one per
  arity. Type variables become `:any`."
  [v]
  (let [schemas (for [{:keys [binders ret]} (:arities (:lean/sig (meta v)))
                      :let [{:keys [params rest type-vars]} (binder-parts binders)
                            s (partial with-vars malli-schema type-vars :any)]]
                  [:=> (cond-> (into [:cat] (map (comp s second) params))
                         rest (conj [:* (s (second (second rest)))]))
                   (s ret)])]
    (if (= 1 (count schemas)) (first schemas) (into [:function] schemas))))


(defn kondo-type
  "clj-kondo type of the Clojure values of the Lean type `t`."
  [t]
  (cond
    (= '_ t) :any

    (symbol? t)
    (case t
      Nat :nat-int
      Int :int
      Bool :boolean
      String :string
      Char :char
      Float :double
      Unit :nil
      (UInt8 UInt16 UInt32 UInt64 USize) :nat-int
      (case (:kind (lookup t))
        (:struct :sum) :map
        :enum :keyword))

    (seq? t)
    (let [[head a] t
          head (head-of head)]
      (case head
        List :seq
        Array :vector
        Prod :vector
        Map :map
        Set :set
        Fin :nat-int
        Option (if (and (seq? a) (= 'Option (first a)))
                 (unsupported t)
                 (keyword "nilable" (name (kondo-type a))))
        (unsupported t)))

    :else (unsupported t)))


(defn kondo-config
  "clj-kondo `:type-mismatch` config of the `leanfran.typed/defn` functions
  in the namespaces `nss`."
  [nss]
  {:linters
   {:type-mismatch
    {:namespaces
     (into (sorted-map)
           (for [ns nss]
             [(ns-name ns)
              (into (sorted-map)
                    (for [[sym v] (ns-interns ns)
                          :let [arities (:arities (:lean/sig (meta v)))]
                          :when arities]
                      [sym {:arities
                            (into {}
                                  (for [{:keys [binders ret]} arities
                                        :let [{:keys [params rest type-vars]} (binder-parts binders)
                                              k (partial with-vars kondo-type type-vars :any)
                                              args (mapv (comp k second) params)]]
                                    (if rest
                                      [:varargs {:args (conj args {:op :rest :spec (k (second (second rest)))})
                                                 :min-arity (count params)
                                                 :ret (k ret)}]
                                      [(count params) {:args args :ret (k ret)}])))}]))]))}}})


(defn write-kondo-config!
  "Write `kondo-config` of `nss` to `.clj-kondo/leanfran/types/config.edn`,
  where clj-kondo picks it up."
  [nss]
  (let [f (io/file ".clj-kondo" "leanfran" "types" "config.edn")]
    (io/make-parents f)
    (spit f (with-out-str (pprint/pprint (kondo-config nss))))
    (str f)))
