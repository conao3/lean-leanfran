(ns lean-clj.core-model-test
  "Each model in `Clj` against the `clojure.core` function it describes, on
  the same generated inputs. A call where Clojure throws is outside what the
  models describe and counts as agreeing."
  (:require
    [clojure.set]
    [clojure.string :as str]
    [clojure.test :as t]
    [clojure.test.check :as tc]
    [clojure.test.check.generators :as gen]
    [clojure.test.check.properties :as prop]
    [lean-clj.core :as lean]
    [lean-clj.types :as types]))


(defmacro ^:private defmodels
  "A deflean block of `(def name binders ret body)` and `models`, the table of
  each generated function next to the Clojure function and argument types."
  [block & entries]
  `(do (lean/deflean ~block {:imports ["Clj"]}
                     ~@(for [[nm bs ret body] entries] (list 'def nm bs ret body)))
       (def ~'models
         ~(vec (for [[nm bs _ _ f gens] entries]
                 {:name (list 'quote nm)
                  :model nm
                  :clj f
                  :types (list 'quote (vec (take-nth 2 (rest bs))))
                  :gens gens})))))


(def ^:private small-nat (gen/choose 0 40))


(declare models)


#_{:clj-kondo/ignore [:unresolved-symbol :unresolved-var :invalid-arity]}


(defmodels core-model
  (add-int [a Int b Int] Int (Clj.add a b) +)
  (add-nat [a Nat b Nat] Nat (Clj.add a b) +)
  (sub-int [a Int b Int] Int (Clj.sub a b) -)
  (neg-int [a Int] Int (Clj.neg a) -)
  (mul-int [a Int b Int] Int (Clj.mul a b) *)
  (inc-nat [a Nat] Nat (Clj.inc a) inc)
  (dec-int [a Int] Int (Clj.dec a) dec)
  (quot-int [a Int b Int] Int (Clj.quot a b) quot)
  (rem-int [a Int b Int] Int (Clj.rem a b) rem)
  (mod-int [a Int b Int] Int (Clj.mod a b) mod)
  (quot-nat [a Nat b Nat] Nat (Clj.quot a b) quot)
  (mod-nat [a Nat b Nat] Nat (Clj.mod a b) mod)
  (lt-int [a Int b Int] Bool (Clj.lt a b) <)
  (le-int [a Int b Int] Bool (Clj.le a b) <=)
  (gt-nat [a Nat b Nat] Bool (Clj.gt a b) >)
  (ge-nat [a Nat b Nat] Bool (Clj.ge a b) >=)
  (max-int [a Int b Int] Int (Clj.max a b) max)
  (min-nat [a Nat b Nat] Nat (Clj.min a b) min)
  (zero-int [a Int] Bool (Clj.zero? a) zero?)
  (pos-int [a Int] Bool (Clj.pos? a) pos?)
  (negative-int [a Int] Bool (Clj.neg? a) neg?)
  (pos-nat [a Nat] Bool (Clj.pos? a) pos?)
  (even-int [a Int] Bool (Clj.even? a) even?)
  (odd-int [a Int] Bool (Clj.odd? a) odd?)
  (eq-list [a (List Int) b (List Int)] Bool (Clj.eq a b) =)
  (eq-string [a String b String] Bool (Clj.eq a b) =)
  (not-eq-int [a Int b Int] Bool (Clj.notEq a b) not=)
  (not-option [a (Option Int)] Bool (Clj.not a) not)
  (not-bool [a Bool] Bool (Clj.not a) not)
  (not-int [a Int] Bool (Clj.not a) not)
  (nil-option [a (Option Int)] Bool (Clj.nil? a) nil?)
  (some-option [a (Option Int)] Bool (Clj.some? a) some?)
  (nil-int [a Int] Bool (Clj.nil? a) nil?)
  (first-list [xs (List Int)] (Option Int) (Clj.first xs) first)
  (first-array [xs (Array Int)] (Option Int) (Clj.first xs) first)
  (rest-array [xs (Array Int)] (List Int) (Clj.rest xs) rest)
  (next-list [xs (List Int)] (Option (List Int)) (Clj.next xs) next)
  (seq-array [xs (Array Int)] (Option (List Int)) (Clj.seq xs) seq)
  (count-array [xs (Array Int)] Nat (Clj.count xs) count)
  (count-list [xs (List Bool)] Nat (Clj.count xs) count)
  (empty-list [xs (List Int)] Bool (Clj.empty? xs) empty?)
  (map-inc [xs (Array Int)] (List Int) (Clj.map (fn [x] (Clj.inc x)) xs) #(map inc %))
  (filter-even [xs (List Int)] (List Int) (Clj.filter (fn [x] (Clj.even? x)) xs) #(filter even? %))
  (filter-option [xs (List (Option Int))] (List (Option Int)) (Clj.filter (fn [x] x) xs) #(filter identity %))
  (remove-even [xs (Array Int)] (List Int) (Clj.remove (fn [x] (Clj.even? x)) xs) #(remove even? %))
  (reduce-add [xs (Array Int)] Int (Clj.reduce (fn [acc x] (Clj.add acc x)) 0 xs) #(reduce + 0 %))
  (take-list [n Nat xs (List Int)] (List Int) (Clj.take n xs) take)
  (drop-array [n Nat xs (Array Int)] (List Int) (Clj.drop n xs) drop)
  (reverse-array [xs (Array Int)] (List Int) (Clj.reverse xs) reverse)
  (vec-list [xs (List Int)] (Array Int) (Clj.vec xs) vec)
  (cons-array [x Int xs (Array Int)] (List Int) (Clj.cons x xs) cons)
  (concat-list-array [xs (List Int) ys (Array Int)] (List Int) (Clj.concat xs ys) concat)
  (nth-list [xs (List Int) i Nat] Int (Clj.nth xs i) nth)
  (nth3-array [xs (Array Int) i Nat d Int] Int (Clj.nth3 xs i d) nth)
  (range-nat [n Nat] (List Nat) (Clj.range n) range [small-nat])
  (range2-nat [a Nat b Nat] (List Nat) (Clj.range2 a b) range [small-nat small-nat])
  (conj-list [xs (List Int) x Int] (List Int) (Clj.conj xs x) conj)
  (conj-array [xs (Array Int) x Int] (Array Int) (Clj.conj xs x) conj)
  (into-vector [to (Array Int) xs (List Int)] (Array Int) (Clj.into to xs) into)
  (into-list [to (List Int) xs (Array Int)] (List Int) (Clj.into to xs) into)
  (get-array [xs (Array Int) i Nat] (Option Int) (Clj.get xs i) get)
  (contains-array [xs (Array Int) i Nat] Bool (Clj.contains? xs i) contains?)
  (str-int [a Int] String (Clj.str a) str)
  (str-bool [a Bool] String (Clj.str a) str)
  (str-char [a Char] String (Clj.str a) str)
  (str-option [a (Option String)] String (Clj.str a) str)
  (some-even [xs (List Int)] (Option Bool) (Clj.someBy (fn [x] (Clj.even? x)) xs) #(some even? %))
  (every-pos [xs (Array Int)] Bool (Clj.every? (fn [x] (Clj.pos? x)) xs) #(every? pos? %))
  (not-every-pos [xs (List Int)] Bool (Clj.notEvery? (fn [x] (Clj.pos? x)) xs) #(not-every? pos? %))
  (not-any-zero [xs (List Int)] Bool (Clj.notAny? (fn [x] (Clj.zero? x)) xs) #(not-any? zero? %))
  (mapcat-twice [xs (List Int)] (List Int) (Clj.mapcat (fn [x] [x x]) xs) #(mapcat (fn [x] [x x]) %))
  (keep-pos [xs (List Int)] (List Int) (Clj.keep (fn [x] (if (Clj.pos? x) (some x) none)) xs) #(keep (fn [x] (when (pos? x) x)) %))
  (keep-even [xs (List Int)] (List Bool) (Clj.keep (fn [x] (Clj.even? x)) xs) #(keep even? %))
  (map-indexed-add [xs (List Int)] (List Int) (Clj.mapIndexed (fn [i x] (Clj.add (the Int i) x)) xs) #(map-indexed + %))
  (keep-indexed-odd [xs (List Int)] (List Int) (Clj.keepIndexed (fn [i x] (if (Clj.odd? (the Int i)) (some x) none)) xs) #(keep-indexed (fn [i x] (when (odd? i) x)) %))
  (last-array [xs (Array Int)] (Option Int) (Clj.last xs) last)
  (butlast-list [xs (List Int)] (Option (List Int)) (Clj.butlast xs) butlast)
  (take-while-pos [xs (List Int)] (List Int) (Clj.takeWhile (fn [x] (Clj.pos? x)) xs) #(take-while pos? %))
  (drop-while-pos [xs (Array Int)] (List Int) (Clj.dropWhile (fn [x] (Clj.pos? x)) xs) #(drop-while pos? %))
  (split-at-list [n Nat xs (List Int)] (Prod (List Int) (List Int)) (Clj.splitAt n xs) split-at)
  (interpose-list [x Int xs (List Int)] (List Int) (Clj.interpose x xs) interpose)
  (interleave-list [xs (List Int) ys (Array Int)] (List Int) (Clj.interleave xs ys) interleave)
  (distinct-list [xs (List Int)] (List Int) (Clj.distinct xs) distinct [(gen/fmap #(apply list %) (gen/vector (gen/choose 0 5)))])
  (mapv-inc [xs (List Int)] (Array Int) (Clj.mapv Clj.inc xs) #(mapv inc %))
  (filterv-even [xs (Array Int)] (Array Int) (Clj.filterv (fn [x] (Clj.even? x)) xs) #(filterv even? %))
  (partition-list [n Nat xs (List Int)] (List (List Int)) (Clj.partition n xs) partition [(gen/choose 1 5) (types/gen '(List Int))])
  (partition-all-list [n Nat xs (Array Int)] (List (List Int)) (Clj.partitionAll n xs) partition-all [(gen/choose 1 5) (types/gen '(Array Int))])
  (sort-ints [xs (List Int)] (List Int) (Clj.sort xs) sort)
  (sort-strings [xs (Array String)] (List String) (Clj.sort xs) sort)
  (sort-by-neg [xs (List Int)] (List Int) (Clj.sortBy (fn [x] (Clj.neg x)) xs) #(sort-by - %))
  (sort-by-parity [xs (List Int)] (List Int) (Clj.sortBy (fn [x] (Clj.even? x)) xs) #(sort-by even? %))
  (max-key-square [a Int b Int] Int (Clj.maxKey (fn [x] (Clj.mul x x)) a b) #(max-key (fn [x] (* x x)) %1 %2))
  (min-key-square [a Int b Int] Int (Clj.minKey (fn [x] (Clj.mul x x)) a b) #(min-key (fn [x] (* x x)) %1 %2))
  (not-empty-list [xs (List Int)] (Option (List Int)) (Clj.notEmpty xs) not-empty)
  (empty-array [xs (Array Int)] (Array Int) (Clj.empty xs) empty)
  (subvec-array [xs (Array Int) a Nat b Nat] (Array Int) (Clj.subvec xs a b) subvec)
  (reduce1-max [xs (List Int)] Int (Clj.reduce1 Clj.max xs) #(reduce max %))
  (nthrest-list [xs (List Int) n Nat] (List Int) (Clj.nthrest xs n) nthrest)
  (nthnext-array [xs (Array Int) n Nat] (Option (List Int)) (Clj.nthnext xs n) nthnext)
  (str-array [xs (Array Int)] String (Clj.str xs) str)
  (str-array-strings [xs (Array String)] String (Clj.str xs) str)
  (str-array-options [xs (Array (Option Bool))] String (Clj.str xs) str)
  (subs-from [s String a Nat] String (Clj.subsFrom s a) subs)
  (subs-range [s String a Nat b Nat] String (Clj.subs s a b) subs)
  (count-string [s String] Nat (Clj.count s) count)
  (first-string [s String] (Option Char) (Clj.first s) first)
  (upper-case [s String] String (Clj.Str'.upperCase s) str/upper-case)
  (lower-case [s String] String (Clj.Str'.lowerCase s) str/lower-case)
  (trim-string [s String] String (Clj.Str'.trim s) str/trim [(gen/fmap #(apply str %) (gen/vector (gen/elements [\a \space \tab \newline \b])))])
  (triml-string [s String] String (Clj.Str'.triml s) str/triml [(gen/fmap #(apply str %) (gen/vector (gen/elements [\a \space \tab \newline \b])))])
  (trimr-string [s String] String (Clj.Str'.trimr s) str/trimr [(gen/fmap #(apply str %) (gen/vector (gen/elements [\a \space \tab \newline \b])))])
  (blank-string [s (Option String)] Bool (Clj.Str'.blank? s) str/blank? [(gen/one-of [(gen/return nil) (gen/fmap #(apply str %) (gen/vector (gen/elements [\a \space \tab])))])])
  (starts-with [s String p String] Bool (Clj.Str'.startsWith? s p) str/starts-with? [(gen/elements ["abc" "ab" "" "b"]) (gen/elements ["a" "ab" "" "c"])])
  (ends-with [s String p String] Bool (Clj.Str'.endsWith? s p) str/ends-with? [(gen/elements ["abc" "bc" "" "b"]) (gen/elements ["c" "bc" "" "a"])])
  (includes [s String p String] Bool (Clj.Str'.includes? s p) str/includes? [(gen/elements ["abc" "bcd" "" "b"]) (gen/elements ["bc" "c" "" "x"])])
  (join-sep [sep String xs (List Int)] String (Clj.Str'.join sep xs) str/join)
  (join-all [xs (Array String)] String (Clj.Str'.join1 xs) str/join)
  (split-comma [s String] (Array String) (Clj.Str'.split s ",") #(str/split % #",") [(gen/fmap #(apply str %) (gen/vector (gen/elements [\a \, \b])))])
  (replace-string [s String m String r String] String (Clj.Str'.replace s m r) str/replace [(gen/elements ["abab" "" "ba"]) (gen/elements ["a" "ab" ""]) (gen/elements ["x" ""])])
  (add-float [a Float b Float] Float (Clj.add a b) +)
  (mul-float [a Float b Float] Float (Clj.mul a b) *)
  (sub-float [a Float b Float] Float (Clj.sub a b) -)
  (div-float [a Float b Float] Float (Clj.div a b) /)
  (quot-float [a Float b Float] Float (Clj.quot a b) quot)
  (rem-float [a Float b Float] Float (Clj.rem a b) rem)
  (mod-float [a Float b Float] Float (Clj.mod a b) mod)
  (lt-float [a Float b Float] Bool (Clj.lt a b) <)
  (max-float [a Float b Float] Float (Clj.max a b) max)
  (inc-float [a Float] Float (Clj.inc a) inc)
  (assoc-map [m (Clj.Map String Nat) k String v Nat] (Clj.Map String Nat) (Clj.assoc m k v) assoc)
  (assoc-vec [v (Array Int) i Nat x Int] (Array Int) (Clj.assoc v i x) assoc [(types/gen '(Array Int)) (gen/choose 0 6) gen/small-integer])
  (dissoc-map [m (Clj.Map Int String) k Int] (Clj.Map Int String) (Clj.dissoc m k) dissoc)
  (get-map [m (Clj.Map String Int) k String] (Option Int) (Clj.get m k) get [(gen/map (gen/elements ["a" "b" "c"]) gen/small-integer) (gen/elements ["a" "b" "d"])])
  (contains-map [m (Clj.Map Int Int) k Int] Bool (Clj.contains? m k) contains?)
  (count-map [m (Clj.Map Int Bool)] Nat (Clj.count m) count)
  (empty-map [m (Clj.Map Int Bool)] Bool (Clj.empty? m) empty?)
  (update-map [m (Clj.Map String Nat) k String] (Clj.Map String Nat) (Clj.update m k (fn [x] (+ (Option.getD x 0) 1))) #(update %1 %2 (fnil inc 0)) [(gen/map (gen/elements ["a" "b"]) gen/nat) (gen/elements ["a" "c"])])
  (update-vec [v (Array Int) i Nat] (Array Int) (Clj.update v i Clj.inc) #(update %1 %2 inc) [(types/gen '(Array Int)) (gen/choose 0 4)])
  (merge-maps [a (Clj.Map Int Int) b (Clj.Map Int Int)] (Clj.Map Int Int) (Clj.merge a b) merge)
  (select-keys-map [m (Clj.Map Int Int) ks (List Int)] (Clj.Map Int Int) (Clj.selectKeys m ks) select-keys)
  (eq-maps [a (Clj.Map Int Int) b (Clj.Map Int Int)] Bool (Clj.eq a b) = [(gen/map (gen/choose 0 2) (gen/choose 0 1)) (gen/map (gen/choose 0 2) (gen/choose 0 1))])
  (conj-map [m (Clj.Map Int Int) e (Prod Int Int)] (Clj.Map Int Int) (Clj.conj m e) conj)
  (into-map [m (Clj.Map Int Int) es (List (Prod Int Int))] (Clj.Map Int Int) (Clj.into m es) into)
  (frequencies-list [xs (List Int)] (Clj.Map Int Nat) (Clj.frequencies xs) frequencies [(gen/fmap #(apply list %) (gen/vector (gen/choose 0 3)))])
  (group-by-parity [xs (List Int)] (Clj.Map Bool (Array Int)) (Clj.groupBy (fn [x] (Clj.even? x)) xs) #(group-by even? %))
  (to-set [xs (List Int)] (Clj.Set Int) (Clj.toSet xs) set [(gen/fmap #(apply list %) (gen/vector (gen/choose 0 3)))])
  (conj-set [s (Clj.Set Int) x Int] (Clj.Set Int) (Clj.conj s x) conj)
  (disj-set [s (Clj.Set Int) x Int] (Clj.Set Int) (Clj.disj s x) disj [(gen/set (gen/choose 0 3)) (gen/choose 0 3)])
  (contains-set [s (Clj.Set Int) x Int] Bool (Clj.contains? s x) contains? [(gen/set (gen/choose 0 3)) (gen/choose 0 3)])
  (get-set [s (Clj.Set Int) x Int] (Option Int) (Clj.get s x) get [(gen/set (gen/choose 0 3)) (gen/choose 0 3)])
  (eq-sets [a (Clj.Set Int) b (Clj.Set Int)] Bool (Clj.eq a b) = [(gen/set (gen/choose 0 2)) (gen/set (gen/choose 0 2))])
  (union-sets [a (Clj.Set Int) b (Clj.Set Int)] (Clj.Set Int) (Clj.union a b) clojure.set/union)
  (intersection-sets [a (Clj.Set Int) b (Clj.Set Int)] (Clj.Set Int) (Clj.intersection a b) clojure.set/intersection [(gen/set (gen/choose 0 4)) (gen/set (gen/choose 0 4))])
  (difference-sets [a (Clj.Set Int) b (Clj.Set Int)] (Clj.Set Int) (Clj.difference a b) clojure.set/difference [(gen/set (gen/choose 0 4)) (gen/set (gen/choose 0 4))]))


(defn- agrees?
  [model clj args]
  (let [expected (apply model args)]
    (try
      (= (apply clj args) expected)
      (catch Exception _ true))))


(t/deftest models-agree-with-clojure-core
  (doseq [{:keys [name model clj types gens]} models]
    (let [g (apply gen/tuple (or gens (map types/gen types)))
          r (tc/quick-check 200 (prop/for-all [args g] (agrees? model clj args)) :seed 42)]
      (t/is (:pass? r) (str name " disagrees on " (pr-str (-> r :shrunk :smallest)))))))
