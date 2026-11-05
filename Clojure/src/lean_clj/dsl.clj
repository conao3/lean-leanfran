(ns lean-clj.dsl
  "Render Lean source from Clojure data.

  Commands, terms, and tactics are written as S-expressions:

    (def double [n Nat] Nat (+ n n))
    (theorem double_eq [n Nat] (= (double n) (* 2 n))
      (by (unfold double) omega))

  `(lean \"...\")` embeds Lean source verbatim wherever a command, term, or
  tactic is expected."
  (:require
    [clojure.string :as str]))


(set! *warn-on-reflection* true)


;; Identifiers

(defn- camel-part
  [s]
  (let [[head & tail] (str/split s #"-")]
    (apply str head (map #(if (seq %) (str (str/upper-case (subs % 0 1)) (subs % 1)) "") tail))))


(defn- ident-part
  [s]
  (let [s (if (re-matches #"[\p{L}\p{N}_'!?]+(-[\p{L}\p{N}_'!?]+)+" s) (camel-part s) s)]
    (if (or (not (re-find #"[\p{L}\p{N}]" s)) (re-matches #"[\p{L}_][\p{L}\p{N}_'!?₀-₉]*|[0-9]+" s))
      s
      (str "«" s "»"))))


(defn ident
  "Lean identifier of a symbol or keyword: each `.`-separated part with a `-`
  becomes lowerCamelCase, and a part that mixes letters with characters
  Lean identifiers do not take is written in `«»` (operators stay as they are)."
  [x]
  (let [s (if (keyword? x) (name x) (str x))]
    (if (or (= s ".") (= s ".."))
      s
      (->> (str/split s #"\." -1)
           (map ident-part)
           (str/join ".")))))


(defn- tactic-name
  [x]
  (str/replace (str x) "-" "_"))


;; Terms

(declare term tactic binders)


(def ^:private binops
  {'+ "+", '- "-", '* "*", '/ "/", '% "%", 'pow "^", '++ "++",
   '= "=", '== "==", '!= "!=", 'not= "≠", '< "<", '<= "≤", '> ">", '>= "≥",
   'and "∧", 'or "∨", 'iff "↔", '&& "&&", '|| "||", 'band "&&", 'bor "||",
   'land "&&&", 'lor "|||", 'xor "^^^", '<<< "<<<", '>>> ">>>",
   'in "∈", 'not-in "∉", 'cons "::", '|> "|>", '<| "<|", '>>= ">>=", '<$> "<$>", 'comp "∘"})


(def ^:private unops
  {'- "-", 'not "¬", '! "!"})


(defn- lean-string
  [^String s]
  (str "\""
       (str/escape s {\" "\\\"" \\ "\\\\" \newline "\\n" \tab "\\t" \return "\\r"})
       "\""))


(defn- lean-char
  [c]
  (case c
    \' "'\\''"
    \\ "'\\\\'"
    \newline "'\\n'"
    \tab "'\\t'"
    (str "'" c "'")))


(defn- raw?
  [x]
  (and (seq? x) (= 'lean (first x))))


(defn- comma
  [xs]
  (str/join ", " (map term xs)))


(defn- fields
  [m]
  (str/join ", " (map (fn [[k v]] (str (ident k) " := " (term v))) m)))


(defn- match-arms
  [clauses]
  (when (odd? (count clauses))
    (throw (ex-info "lean-clj.dsl: match needs pattern/result pairs" {:clauses clauses})))
  (->> (partition 2 clauses)
       (map (fn [[p e]] (str " | " (if (vector? p) (comma p) (term p)) " => " (term e))))
       (apply str)))


(defn- list-term
  [[head & args]]
  (cond
    (and (contains? unops head) (= 1 (count args)))
    (str "(" (unops head) (term (first args)) ")")

    (contains? binops head)
    (str "(" (str/join (str " " (binops head) " ") (map term args)) ")")

    :else
    (case head
      lean (first args)
      if (if (= 4 (count args))
           (let [[h c t e] args] (str "(if " (term h) " : " (term c) " then " (term t) " else " (term e) ")"))
           (let [[c t e] args] (str "(if " (term c) " then " (term t) " else " (term e) ")")))
      let (let [[bs body] args]
            (str "("
                 (->> (partition 2 bs)
                      (map (fn [[x v]] (str "let " (term x) " := " (term v) "; ")))
                      (apply str))
                 (term body) ")"))
      (fn fun) (let [[params body] args]
                 (str "(fun " (str/join " " (map term params)) " => " (term body) ")"))
      match (let [[d & clauses] args]
              (str "(match " (if (vector? d) (comma d) (term d)) " with" (match-arms clauses) ")"))
      match-eq (let [[h d & clauses] args]
                 (str "(match " (term h) " : " (term d) " with" (match-arms clauses) ")"))
      the (let [[t e] args] (str "(" (term e) " : " (term t) ")"))
      -> (str "(" (str/join " → " (map term args)) ")")
      forall (let [[bs p] args] (str "(∀ " (binders bs) ", " (term p) ")"))
      exists (let [[bs p] args] (str "(∃ " (binders bs) ", " (term p) ")"))
      <> (str "⟨" (comma args) "⟩")
      with (let [[s m] args] (str "{ " (term s) " with " (fields m) " }"))
      array (str "#[" (comma args) "]")
      by (str "(by " (str/join "; " (map tactic args)) ")")
      (if (and (symbol? head) (str/starts-with? (name head) ".") (seq args))
        (let [[recv & more] args
              call (str (term recv) "." (ident (subs (name head) 1)))]
          (if (seq more)
            (str "(" call " " (str/join " " (map term more)) ")")
            call))
        (if (seq args)
          (str "(" (term head) " " (str/join " " (map term args)) ")")
          (term head))))))


(defn term
  "Lean source of a term."
  [x]
  (cond
    (seq? x) (if (empty? x) "()" (list-term x))
    (vector? x) (str "[" (comma x) "]")
    (map? x) (if (empty? x) "{}" (str "{ " (fields x) " }"))
    (symbol? x) (ident x)
    (keyword? x) (ident x)
    (string? x) (lean-string x)
    (char? x) (lean-char x)
    (boolean? x) (str x)
    (ratio? x) (throw (ex-info "lean-clj.dsl: ratios have no Lean literal" {:value x}))
    (number? x) (if (neg? x) (str "(" x ")") (str x))
    :else (throw (ex-info (str "lean-clj.dsl: cannot render " (pr-str x)) {:value x}))))


(defn- type-app
  "A type application without the outer parentheses: `(BEq α)` → `BEq α`."
  [x]
  (if (and (seq? x) (symbol? (first x)) (not (contains? binops (first x))))
    (str/join " " (map term x))
    (term x)))


;; Binders

(defn binders
  "Lean binders of a vector: `[x T y U]` → `(x : T) (y : U)`; the lists
  `(implicit x T)`, `(strict x T)`, and `(inst C)` make one binder each."
  [bs]
  (loop [bs (seq bs) acc []]
    (if-not bs
      (str/join " " acc)
      (let [b (first bs)]
        (if (seq? b)
          (let [[kind & args] b]
            (recur (next bs)
                   (conj acc (case kind
                               implicit (str "{" (term (first args)) " : " (term (second args)) "}")
                               strict (str "⦃" (term (first args)) " : " (term (second args)) "⦄")
                               inst (str "[" (type-app (first args)) "]")
                               (throw (ex-info (str "lean-clj.dsl: unknown binder " kind) {:binder b}))))))
          (do (when-not (next bs)
                (throw (ex-info (str "lean-clj.dsl: binder " b " has no type") {:binders bs})))
              (recur (nnext bs) (conj acc (str "(" (term b) " : " (term (second bs)) ")")))))))))


;; Tactics

(defn tactic
  "Lean source of a tactic."
  [x]
  (cond
    (symbol? x) (tactic-name x)
    (string? x) x
    (raw? x) (second x)
    (seq? x)
    (let [[head & args] x]
      (case head
        on-all (str/join " <;> " (map tactic args))
        seq (str "(" (str/join "; " (map tactic args)) ")")
        case (let [[tag vars & tacs] args]
               (str "(case " (if (nil? tag) "nil" (term tag)) (apply str (map #(str " " (term %)) vars))
                    " => (" (str/join "; " (map tactic tacs)) "))"))
        (str/join " " (cons (tactic-name head) (map term args)))))
    :else (throw (ex-info (str "lean-clj.dsl: cannot render tactic " (pr-str x)) {:value x}))))


;; Commands

(defn- modifiers
  [sym]
  (let [m (meta sym)]
    (str (when-let [attrs (:attrs m)] (str "@[" (str/join ", " (map str attrs)) "] "))
         (when (:private m) "private ")
         (when (:protected m) "protected ")
         (when (:noncomputable m) "noncomputable ")
         (when (:partial m) "partial "))))


(defn- head-binders
  [bs]
  (let [s (binders bs)]
    (if (str/blank? s) "" (str " " s))))


(defn- def-like
  [kw [nm bs & more]]
  (let [[ty body] (if (= 2 (count more)) more [nil (first more)])
        {:keys [termination-by decreasing-by]} (meta nm)]
    (str (modifiers nm) kw " " (ident nm) (head-binders bs)
         (when ty (str " : " (term ty)))
         " := " (term body)
         (when termination-by (str "\ntermination_by " (term termination-by)))
         (when decreasing-by
           (str "\ndecreasing_by " (if (and (seq? decreasing-by) (= 'by (first decreasing-by)))
                                     (str "(" (str/join "; " (map tactic (rest decreasing-by))) ")")
                                     (tactic decreasing-by)))))))


(defn- deriving?
  [x]
  (and (seq? x) (= 'deriving (first x))))


(defn- deriving-line
  [xs]
  (when-let [d (first (filter deriving? xs))]
    (str "\n  deriving " (str/join ", " (map term (rest d))))))


(declare command)


(defn- structure
  [[nm & more]]
  (let [vs (filter vector? more)
        [params fs] (if (= 2 (count vs)) vs [[] (first vs)])]
    (str (modifiers nm) "structure " (ident nm) (head-binders params) " where"
         (->> (partition 2 fs)
              (map (fn [[f t]] (str "\n  " (ident f) " : " (term t))))
              (apply str))
         (deriving-line more))))


(defn- inductive
  [[nm & more]]
  (let [[params ctors] (if (vector? (first more)) [(first more) (rest more)] [[] more])]
    (str (modifiers nm) "inductive " (ident nm) (head-binders params) " where"
         (->> (remove deriving? ctors)
              (map (fn [c]
                     (if (seq? c)
                       (let [[cn bs ty] c]
                         (str "\n  | " (ident cn) (head-binders bs) (when ty (str " : " (term ty)))))
                       (str "\n  | " (ident c)))))
              (apply str))
         (deriving-line ctors))))


(defn command
  "Lean source of a command."
  [x]
  (cond
    (string? x) x
    (seq? x)
    (let [[head & args] x]
      (case head
        lean (first args)
        def (def-like "def" args)
        abbrev (def-like "abbrev" args)
        theorem (let [[nm bs p proof] args]
                  (str (modifiers nm) "theorem " (ident nm) (head-binders bs) " : " (term p) " := " (term proof)))
        example (let [[bs p proof] args]
                  (str "example" (head-binders bs) " : " (term p) " := " (term proof)))
        instance (let [[bs c body] (if (vector? (first args)) args (cons [] args))]
                   (str "instance" (head-binders bs) " : " (type-app c) " := " (term body)))
        structure (structure args)
        inductive (inductive args)
        mutual (str "mutual\n" (str/join "\n" (map command args)) "\nend")
        namespace (let [[nm & cmds] args]
                    (str "namespace " (ident nm) "\n\n" (str/join "\n\n" (map command cmds)) "\n\nend " (ident nm)))
        open (str "open " (str/join " " (map ident args)))
        (throw (ex-info (str "lean-clj.dsl: unknown command " head) {:form x}))))
    :else (throw (ex-info (str "lean-clj.dsl: cannot render command " (pr-str x)) {:form x}))))


(defn render
  "Lean source of a sequence of commands."
  [cmds]
  (str/join "\n\n" (map command cmds)))
