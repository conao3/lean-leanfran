(ns misuse
  (:require
    [accounts.core :as accounts]))


(accounts/deposit {:owner "ann" :balance 10 :frozen false} "5")
(inc (accounts/owner-name {:owner "ann" :balance 10 :frozen false}))
