(ns accounts.core
  "Account operations with Lean signatures. The structure `Account` is
  defined in Lean, and the signatures give malli schemas, clj-kondo types, and
  test.check generators."
  (:require
    [leanfran.core :refer [deflean]]
    [leanfran.typed :as lt]))


(deflean types
  (structure Account [owner String balance Nat frozen Bool]))


(lt/defn deposit
  "Add `n` to the balance of `a`, unless `a` is frozen."
  [a Account n Nat]
  Account
  (if (:frozen a) a (update a :balance + n)))


(lt/defn owner-name
  [a Account]
  String
  (:owner a))
