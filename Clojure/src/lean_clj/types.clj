(ns lean-clj.types
  "Lean types written as `lean-clj.dsl` terms, and what lean-clj derives from
  them: test.check generators of the Clojure values that correspond to a type,
  a check of such values, malli schemas, and clj-kondo types.

  Structures and enumerations are known by the Lean name they are written
  with in a `deflean` block (`register-commands!`)."
  (:require
    [clojure.java.io :as io]
    [clojure.pprint :as pprint]
    [clojure.string :as str]
    [clojure.test.check.generators :as gen]
    [lean-clj.dsl :as dsl]
    [lean-clj.runtime :as runtime]))


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
                    (when (and (seq ctors) (every? symbol? ctors))
                      (swap! types assoc (str module "." prefix (dsl/ident nm))
                             {:kind :enum :module module :ctors (vec ctors)})))
        namespace (doseq [c (rest args)]
                    (register-command! module (str prefix (dsl/ident (first args)) ".") c))
        mutual (doseq [c args] (register-command! module prefix c))
        nil))))


(defn register-commands!
  "Record the monomorphic structures and enumerations among the
  `lean-clj.dsl` commands of the Lean module `module`."
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
               :enum {:kind :enum :module module :ctors (mapv #(symbol (name %)) ctors)})])))


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
            (throw (ex-info (str "lean-clj.types: type " t " is ambiguous among " (str/join ", " (sort names)))
                            {:type t :names names})))))))


(defn module-of
  "Lean module that defines the structure or enumeration `t`, if registered."
  [t]
  (:module (entry t)))


(defn- lookup
  [t]
  (or (entry t)
      (throw (ex-info (str "lean-clj.types: unknown type " t) {:type t}))))


(defn- unsupported
  [t]
  (throw (ex-info (str "lean-clj.types: type " (pr-str t) " has no Clojure value form") {:type t})))


(def ^:private big-nat
  (gen/fmap #(+ (bigint Long/MAX_VALUE) 1 %) gen/nat))


(def ^:private big-neg
  (gen/fmap #(- (bigint Long/MIN_VALUE) 1 %) gen/nat))


(def ^:dynamic *big-ints*
  "Whether `gen` mixes in integers beyond `Long`."
  true)


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
      (let [{:keys [kind fields ctors]} (lookup t)]
        (case kind
          :struct (apply gen/hash-map (mapcat (fn [[f ft]] [(field-key f) (gen ft)]) fields))
          :enum (gen/elements (mapv field-key ctors)))))

    (seq? t)
    (let [[head a b] t]
      (case head
        List (gen/fmap #(apply list %) (gen/vector (gen a)))
        Array (gen/vector (gen a))
        Option (if (and (seq? a) (= 'Option (first a)))
                 (unsupported t)
                 (gen/one-of [(gen/return nil) (gen a)]))
        Prod (gen/tuple (gen a) (gen b))
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
      (let [{:keys [kind fields ctors]} (lookup t)]
        (case kind
          :struct (and (map? x)
                       (= (set (map (comp field-key first) fields)) (set (keys x)))
                       (every? (fn [[f ft]] (valid? ft (get x (field-key f)))) fields))
          :enum (contains? (set (map field-key ctors)) x))))

    (seq? t)
    (let [[head a b] t]
      (case head
        List (and (seq? x) (every? #(valid? a %) x))
        Array (and (vector? x) (every? #(valid? a %) x))
        Option (or (nil? x) (valid? a x))
        Prod (and (vector? x) (= 2 (count x)) (valid? a (first x)) (valid? b (second x)))
        (unsupported t)))

    :else (unsupported t)))


(defn malli-schema
  "malli schema of the Clojure values of the Lean type `t`, as data."
  [t]
  (cond
    (symbol? t)
    (case t
      Nat [:and 'integer? [:>= 0]]
      Int 'integer?
      Bool :boolean
      String :string
      Char 'char?
      Float :double
      (let [{:keys [kind fields ctors]} (lookup t)]
        (case kind
          :struct (into [:map {:closed true}] (map (fn [[f ft]] [(field-key f) (malli-schema ft)]) fields))
          :enum (into [:enum] (map field-key ctors)))))

    (seq? t)
    (let [[head a b] t]
      (case head
        List [:sequential (malli-schema a)]
        Array [:vector (malli-schema a)]
        Option (if (and (seq? a) (= 'Option (first a)))
                 (unsupported t)
                 [:maybe (malli-schema a)])
        Prod [:tuple (malli-schema a) (malli-schema b)]
        (unsupported t)))

    :else (unsupported t)))


(defn fn-schema
  "malli function schema `[:=> [:cat T ...] R]` of a `lean-clj.typed/defn`
  var, for `malli.core/=>`."
  [v]
  (let [{:keys [binders ret]} (:lean/sig (meta v))]
    [:=> (into [:cat] (map malli-schema (take-nth 2 (rest binders)))) (malli-schema ret)]))


(defn kondo-type
  "clj-kondo type of the Clojure values of the Lean type `t`."
  [t]
  (cond
    (symbol? t)
    (case t
      Nat :nat-int
      Int :int
      Bool :boolean
      String :string
      Char :char
      Float :double
      (case (:kind (lookup t))
        :struct :map
        :enum :keyword))

    (seq? t)
    (let [[head a] t]
      (case head
        List :seq
        Array :vector
        Prod :vector
        Option (if (and (seq? a) (= 'Option (first a)))
                 (unsupported t)
                 (keyword "nilable" (name (kondo-type a))))
        (unsupported t)))

    :else (unsupported t)))


(defn kondo-config
  "clj-kondo `:type-mismatch` config of the `lean-clj.typed/defn` functions
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
                          :let [{:keys [binders ret]} (:lean/sig (meta v))]
                          :when binders
                          :let [args (take-nth 2 (rest binders))]]
                      [sym {:arities {(count args) {:args (mapv kondo-type args) :ret (kondo-type ret)}}}]))]))}}})


(defn write-kondo-config!
  "Write `kondo-config` of `nss` to `.clj-kondo/lean-clj/types/config.edn`,
  where clj-kondo picks it up."
  [nss]
  (let [f (io/file ".clj-kondo" "lean-clj" "types" "config.edn")]
    (io/make-parents f)
    (spit f (with-out-str (pprint/pprint (kondo-config nss))))
    (str f)))
