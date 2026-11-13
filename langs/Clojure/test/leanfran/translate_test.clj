(ns leanfran.translate-test
  (:require
    [clojure.string :as str]
    [clojure.test :as t]
    [leanfran.translate :as tr]
    [leanfran.typed :as lt]))


(lt/defn grade
  [s Int]
  String
  (cond
    (>= s 90) "A"
    (< 50 s 90) (str "B" s)
    :else (-> s (- 3) str)))


(lt/defn first-or
  [xs (Array Int) d Int]
  Int
  (if-some [x (first xs)] x d))


(lt/defn deposit
  [a Account n Nat]
  Account
  (if (:frozen a) a (update a :balance + n)))


(lt/defn count-up
  [n Nat]
  Nat
  (lt/loop ^{:termination-by (- n i)} [i Nat 0 acc Nat 0]
    (if (< i n) (recur (inc i) (+ acc i)) acc)))


(lt/defn suit-name
  [s Suit]
  String
  (case s :hearts "hearts" "other"))


(lt/defn uses-interop
  [s String]
  Nat
  (.length s))


(defn- render
  [& syms]
  (:text (tr/render-command (the-ns 'leanfran.translate-test) (cons 'clojure syms) true)))


(t/deftest translates-clojure-to-models
  (t/is (= (str "@[extern \"clj:leanfran.translate-test/grade\"] def grade (s : Int) : String := "
                "(if _h1 : ((Clj.truthy (Clj.ge s 90)) = true) then \"A\" else "
                "(if _h2 : ((Clj.truthy ((Clj.lt 50 s) && (Clj.lt s 90))) = true) then "
                "((Clj.str \"B\") ++ (Clj.str s)) else (Clj.str (Clj.sub s 3))))")
           (render 'grade)))
  (t/is (str/includes? (render 'first-or)
                       "(match _h1 : (Clj.first xs) with | (some x) => x | none => d)"))
  (t/is (str/includes? (render 'deposit)
                       "(if _h1 : ((Clj.truthy a.frozen) = true) then a else { a with balance := (Clj.add a.balance n) })"))
  (t/is (= (str "@[extern \"clj:leanfran.translate-test/count-up\"] def countUp (n : Nat) : Nat := "
                "(let rec loop1 (i : Nat) (acc : Nat) : Nat := "
                "(if _h2 : ((Clj.truthy (Clj.lt i n)) = true) then (loop1 (Clj.inc i) (Clj.add acc i)) else acc)\n"
                "  termination_by (n - i)\n"
                "  ; (loop1 0 0))")
           (render 'count-up)))
  (t/is (str/includes? (render 'suit-name) "(match s with | .hearts => \"hearts\" | _ => \"other\")")))


(t/deftest rejects-what-it-cannot-model
  (t/is (thrown-with-msg? clojure.lang.ExceptionInfo #"has no model in Clj|outside|cannot translate"
          (render 'uses-interop))))
