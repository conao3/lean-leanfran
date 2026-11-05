(ns lean-clj.io-test
  "IO actions written in Lean and run from Clojure."
  (:require
    [clojure.string :as str]
    [clojure.test :as t]
    [lean-clj.core :as lean]))


(lean/deflean actions
              "def greet (n : String) : IO Unit := do
                 IO.println s!\"hello {n}\"
                 IO.eprintln \"to stderr\"

               def counter (k : Nat) : IO Nat := do
                 let r ← IO.mkRef 0
                 for _ in [0:k] do
                   r.modify (· + 1)
                 r.get

               def fail (n : Nat) : IO Nat := do
                 if n > 2 then throw (IO.userError s!\"too big: {n}\")
                 pure n

               def echo : IO String := do
                 let line ← (← IO.getStdin).getLine
                 pure line.trimAscii.toString

               def elapsed : IO Bool := do
                 let a ← IO.monoMsNow
                 let b ← IO.monoMsNow
                 pure (a ≤ b)")


(t/deftest io-actions-run
  (let [err (java.io.StringWriter.)]
    (t/is (= "hello lean\n" (with-out-str (binding [*err* err] (greet "lean")))))
    (t/is (= "to stderr\n" (str err))))
  (t/is (= 5 (counter 5)))
  (t/is (= 2 (fail 2)))
  (t/is (thrown-with-msg? clojure.lang.ExceptionInfo #"too big: 3" (fail 3)))
  (t/is (= "typed" (with-in-str "  typed  \nmore\n" (echo))))
  (t/is (true? (elapsed)))
  (t/is (str/blank? (with-out-str (counter 1)))))
