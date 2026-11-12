(ns lean-clj.malli
  "malli instrumentation of `lean-clj.typed/defn` functions from their Lean
  signatures. malli is the user's dependency; this namespace loads it when
  called."
  (:require
    [lean-clj.types :as types]))


(set! *warn-on-reflection* true)


(defn register!
  "Register the malli function schema (`lean-clj.types/fn-schema`) of every
  `lean-clj.typed/defn` function of the namespaces `nss`, as `malli.core/=>`
  does. Returns the registered vars."
  [nss]
  (let [register (requiring-resolve 'malli.core/-register-function-schema!)]
    (vec (for [ns nss
               :let [ns (the-ns ns)]
               [sym v] (ns-interns ns)
               :when (:lean/sig (meta v))]
           (do (register (ns-name ns) sym (types/fn-schema v) {})
               v)))))


(defn instrument!
  "`register!` the functions of the namespaces `nss`, then instrument them with
  `malli.instrument/instrument!`, so that calls with arguments outside their
  Lean types throw. `opts` go to `instrument!` (`:report`, `:scope`)."
  ([nss] (instrument! nss {}))
  ([nss opts]
   (register! nss)
   ((requiring-resolve 'malli.instrument/instrument!)
    (merge {:filters [(apply (requiring-resolve 'malli.instrument/-filter-ns) (map #(ns-name (the-ns %)) nss))]}
           opts))))
