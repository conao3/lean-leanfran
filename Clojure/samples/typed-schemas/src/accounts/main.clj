(ns accounts.main
  (:require
    [accounts.core :as accounts]
    [clojure.test.check.generators :as gen]
    [lean-clj.types :as types]
    [malli.core :as m]
    [malli.instrument :as mi]))


(m/=> accounts.core/deposit (types/fn-schema #'accounts/deposit))


(defn -main
  [& _]
  (prn (types/malli-schema 'Account))
  (prn (types/fn-schema #'accounts/deposit))
  (prn (gen/generate (types/gen 'Account) 5 42))
  (mi/instrument!)
  (prn (accounts/deposit {:owner "ann" :balance 10 :frozen false} 5))
  (prn (try (accounts/deposit {:owner "ann" :balance -1 :frozen false} 5)
            (catch Exception e (:type (ex-data e))))))
