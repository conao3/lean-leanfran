(ns lean-clj.runtime
  "Runtime for Clojure code generated from Lean IR.

  Functions named `lean_*` implement the C symbols of Lean's `@[extern]`
  declarations, so generated code calls `lean-clj.runtime/<C symbol>`.
  Value representation:

  - `Nat` / `Int`: `Long`, or `clojure.lang.BigInt` when it does not fit
  - `UInt8`..`UInt32`, `Char`, `Bool`, enumerations: `Long`
  - `UInt64` / `USize`: `Long` holding the 64-bit pattern
  - `Float`: `Double`
  - `String`: `java.lang.String` (positions are UTF-8 byte offsets)
  - `Array`: persistent vector
  - nullary constructors: `Long` (the constructor index)
  - other constructors: `Ctor`
  - closures: `Closure`"
  (:refer-clojure :exclude [apply trampoline])
  (:import
    (clojure.lang
      BigInt)
    (java.nio.charset
      StandardCharsets)))


(set! *warn-on-reflection* true)


;; Objects

(definterface ICtor
  (^long getTag [])
  (setTag [^long t])
  (objs [])
  (scalars []))


(deftype Ctor
  [^:unsynchronized-mutable ^long tag os ss]

  ICtor

  (getTag [_] tag)


  (setTag [_ t] (set! tag t))


  (objs [_] os)


  (scalars [_] ss))


(defmethod print-method Ctor [^Ctor c ^java.io.Writer w]
  (.write w "#lean/ctor ")
  (print-method (into [(.getTag c)] ^objects (.objs c)) w))


(defn ctor
  [tag nobjs ssize & objs]
  (let [os (object-array nobjs)]
    (loop [i 0 xs objs]
      (when xs
        (aset os i (first xs))
        (recur (inc i) (next xs))))
    (Ctor. tag os (when (pos? (long ssize)) (object-array ssize)))))


(defn tag
  ^long [x]
  (if (instance? Ctor x) (.getTag ^Ctor x) (long x)))


(defn proj
  [^Ctor x i]
  (aget ^objects (.objs x) (int i)))


(defn sproj
  [^Ctor x offset]
  (aget ^objects (.scalars x) (int offset)))


(defn set-obj!
  [^Ctor x i v]
  (aset ^objects (.objs x) (int i) v)
  nil)


(defn sset!
  [^Ctor x offset v]
  (aset ^objects (.scalars x) (int offset) v)
  nil)


(defn set-tag!
  [^Ctor x t]
  (.setTag x t)
  nil)


(defn unreachable
  []
  (throw (ex-info "lean-clj: unreachable code" {})))


;; Closures and tail calls

(declare apply-v)


(deftype Closure
  [f ^long arity args]

  clojure.lang.IFn

  (invoke [this] (apply-v this []))


  (invoke [this a] (apply-v this [a]))


  (invoke [this a b] (apply-v this [a b]))


  (invoke [this a b c] (apply-v this [a b c]))


  (invoke [this a b c d] (apply-v this [a b c d]))


  (applyTo [this xs] (apply-v this (vec xs))))


(defn closure
  [f arity args]
  (Closure. f arity args))


(deftype TailCall
  [f args])


(defn tail-call
  [f & args]
  (TailCall. f args))


(defn trampoline
  [r]
  (if (instance? TailCall r)
    (recur (clojure.core/apply (.-f ^TailCall r) (.-args ^TailCall r)))
    r))


(deftype Restart
  [args])


(defn restart
  [& args]
  (Restart. (vec args)))


(defn restart?
  [r]
  (instance? Restart r))


(defn restart-arg
  [^Restart r i]
  (nth (.-args r) i))


(defn apply-v
  [f args]
  (if (instance? Closure f)
    (let [^Closure c f
          have (.-args c)
          need (- (.-arity c) (count have))
          n (count args)]
      (cond
        (= n need) (clojure.core/apply (.-f c) (concat have args))
        (< n need) (Closure. (.-f c) (.-arity c) (into have args))
        :else (recur (clojure.core/apply (.-f c) (concat have (subvec args 0 need)))
                     (subvec args need))))
    (clojure.core/apply f args)))


(defn apply
  [f & args]
  (apply-v f (vec args)))


;; Link check

(defn check-symbols!
  [syms]
  (let [missing (remove #(ns-resolve 'lean-clj.runtime (symbol %)) syms)]
    (when (seq missing)
      (throw (ex-info (str "lean-clj: the runtime does not define " (vec missing))
                      {:missing (vec missing)})))))


;; Nat and Int

(defn- norm
  [x]
  (if (instance? BigInt x)
    (let [^BigInt b x]
      (if (nil? (.-bipart b)) (.-lpart b) b))
    x))


(defn- big
  ^java.math.BigInteger [x]
  (biginteger x))


(defn- bool
  ^long [b]
  (if b 1 0))


(defn lean_nat_add
  [a b]
  (+' a b))


(defn lean_nat_sub
  [a b]
  (if (< a b) 0 (norm (-' a b))))


(defn lean_nat_mul
  [a b]
  (*' a b))


(defn lean_nat_div
  [a b]
  (if (zero? b) 0 (norm (quot a b))))


(defn lean_nat_mod
  [a b]
  (if (zero? b) a (norm (rem a b))))


(defn lean_nat_pow
  [a b]
  (norm (bigint (.pow (big a) (int b)))))


(defn lean_nat_gcd
  [a b]
  (norm (bigint (.gcd (big a) (big b)))))


(defn lean_nat_lcm
  [a b]
  (if (or (zero? a) (zero? b)) 0 (norm (quot (*' a b) (lean_nat_gcd a b)))))


(defn lean_nat_succ
  [a]
  (+' a 1))


(defn lean_nat_pred
  [a]
  (if (zero? a) 0 (norm (-' a 1))))


(defn lean_nat_dec_eq
  [a b]
  (bool (== a b)))


(defn lean_nat_dec_lt
  [a b]
  (bool (< a b)))


(defn lean_nat_dec_le
  [a b]
  (bool (<= a b)))


(defn lean_nat_land
  [a b]
  (norm (bigint (.and (big a) (big b)))))


(defn lean_nat_lor
  [a b]
  (norm (bigint (.or (big a) (big b)))))


(defn lean_nat_lxor
  [a b]
  (norm (bigint (.xor (big a) (big b)))))


(defn lean_nat_shiftl
  [a b]
  (norm (bigint (.shiftLeft (big a) (int b)))))


(defn lean_nat_shiftr
  [a b]
  (norm (bigint (.shiftRight (big a) (int b)))))


(defn lean_nat_log2
  [a]
  (if (zero? a) 0 (dec (.bitLength (big a)))))


(defn lean_nat_to_int
  [a]
  a)


(defn lean_nat_abs
  [a]
  (norm (if (neg? a) (-' a) a)))


(defn lean_int_add
  [a b]
  (norm (+' a b)))


(defn lean_int_sub
  [a b]
  (norm (-' a b)))


(defn lean_int_mul
  [a b]
  (norm (*' a b)))


(defn lean_int_neg
  [a]
  (norm (-' a)))


(defn lean_int_div
  [a b]
  (if (zero? b) 0 (norm (quot a b))))


(defn lean_int_mod
  [a b]
  (if (zero? b) a (norm (rem a b))))


(defn lean_int_emod
  [a b]
  (if (zero? b) a (norm (mod a (if (neg? b) (-' b) b)))))


(defn lean_int_ediv
  [a b]
  (if (zero? b) 0 (norm (quot (-' a (lean_int_emod a b)) b))))


(defn lean_int_dec_eq
  [a b]
  (bool (== a b)))


(defn lean_int_dec_lt
  [a b]
  (bool (< a b)))


(defn lean_int_dec_le
  [a b]
  (bool (<= a b)))


(defn lean_int_dec_nonneg
  [a]
  (bool (not (neg? a))))


(defn lean_int_to_nat
  [a]
  (if (neg? a) 0 a))


(defn lean_int_neg_succ_of_nat
  [a]
  (norm (-' (-' a) 1)))


(defn lean_int_to_int
  [a]
  a)


;; Fixed-width unsigned integers

(defn- low64
  ^long [x]
  (if (instance? BigInt x) (.longValue (big x)) (long x)))


(defmacro ^:private def-uint
  [n mask]
  (let [s (fn [op] (symbol (str "lean_uint" n "_" op)))
        m (long mask)]
    `(do
       (defn ~(s "add") [a# b#] (bit-and (unchecked-add (long a#) (long b#)) ~m))
       (defn ~(s "sub") [a# b#] (bit-and (unchecked-subtract (long a#) (long b#)) ~m))
       (defn ~(s "mul") [a# b#] (bit-and (unchecked-multiply (long a#) (long b#)) ~m))
       (defn ~(s "div") [a# b#] (if (zero? b#) 0 (quot (long a#) (long b#))))
       (defn ~(s "mod") [a# b#] (if (zero? b#) a# (rem (long a#) (long b#))))
       (defn ~(s "land") [a# b#] (bit-and (long a#) (long b#)))
       (defn ~(s "lor") [a# b#] (bit-or (long a#) (long b#)))
       (defn ~(s "xor") [a# b#] (bit-xor (long a#) (long b#)))
       (defn ~(s "complement") [a#] (bit-and (bit-not (long a#)) ~m))
       (defn ~(s "neg") [a#] (bit-and (unchecked-negate (long a#)) ~m))
       (defn ~(s "shift_left") [a# b#] (bit-and (bit-shift-left (long a#) (rem (long b#) ~n)) ~m))
       (defn ~(s "shift_right") [a# b#] (unsigned-bit-shift-right (long a#) (rem (long b#) ~n)))
       (defn ~(s "dec_eq") [a# b#] (bool (== (long a#) (long b#))))
       (defn ~(s "dec_lt") [a# b#] (bool (< (long a#) (long b#))))
       (defn ~(s "dec_le") [a# b#] (bool (<= (long a#) (long b#))))
       (defn ~(s "to_nat") [a#] (long a#))
       (defn ~(s "of_nat") [a#] (bit-and (low64 a#) ~m))
       (defn ~(s "to_uint8") [a#] (bit-and (long a#) 0xFF))
       (defn ~(s "to_uint16") [a#] (bit-and (long a#) 0xFFFF))
       (defn ~(s "to_uint32") [a#] (bit-and (long a#) 0xFFFFFFFF))
       (defn ~(s "to_uint64") [a#] (long a#))
       (defn ~(s "to_usize") [a#] (long a#))
       (defn ~(s "to_float") [a#] (double a#)))))


(def-uint 8 0xFF)
(def-uint 16 0xFFFF)
(def-uint 32 0xFFFFFFFF)


(defn- u64->nat
  [^long a]
  (if (neg? a) (+' (bigint a) 18446744073709551616N) a))


(defmacro ^:private def-uint64
  [prefix]
  (let [s (fn [op] (symbol (str prefix "_" op)))]
    `(do
       (defn ~(s "add") [a# b#] (unchecked-add (long a#) (long b#)))
       (defn ~(s "sub") [a# b#] (unchecked-subtract (long a#) (long b#)))
       (defn ~(s "mul") [a# b#] (unchecked-multiply (long a#) (long b#)))
       (defn ~(s "div") [a# b#] (if (zero? b#) 0 (Long/divideUnsigned (long a#) (long b#))))
       (defn ~(s "mod") [a# b#] (if (zero? b#) a# (Long/remainderUnsigned (long a#) (long b#))))
       (defn ~(s "land") [a# b#] (bit-and (long a#) (long b#)))
       (defn ~(s "lor") [a# b#] (bit-or (long a#) (long b#)))
       (defn ~(s "xor") [a# b#] (bit-xor (long a#) (long b#)))
       (defn ~(s "complement") [a#] (bit-not (long a#)))
       (defn ~(s "neg") [a#] (unchecked-negate (long a#)))
       (defn ~(s "shift_left") [a# b#] (bit-shift-left (long a#) (Long/remainderUnsigned (long b#) 64)))
       (defn ~(s "shift_right") [a# b#] (unsigned-bit-shift-right (long a#) (Long/remainderUnsigned (long b#) 64)))
       (defn ~(s "dec_eq") [a# b#] (bool (== (long a#) (long b#))))
       (defn ~(s "dec_lt") [a# b#] (bool (neg? (Long/compareUnsigned (long a#) (long b#)))))
       (defn ~(s "dec_le") [a# b#] (bool (not (pos? (Long/compareUnsigned (long a#) (long b#))))))
       (defn ~(s "to_nat") [a#] (u64->nat a#))
       (defn ~(s "of_nat") [a#] (low64 a#))
       (defn ~(s "to_uint8") [a#] (bit-and (long a#) 0xFF))
       (defn ~(s "to_uint16") [a#] (bit-and (long a#) 0xFFFF))
       (defn ~(s "to_uint32") [a#] (bit-and (long a#) 0xFFFFFFFF))
       (defn ~(s "to_uint64") [a#] (long a#))
       (defn ~(s "to_usize") [a#] (long a#))
       (defn ~(s "to_float") [a#] (double (u64->nat a#))))))


(def-uint64 "lean_uint64")
(def-uint64 "lean_usize")


(defn lean_usize_of_nat
  [a]
  (low64 a))


(defn lean_system_platform_nbits
  [_]
  64)


(defn lean_uint32_of_nat_mk
  [a]
  (bit-and (low64 a) 0xFFFFFFFF))


;; Float

(defn lean_float_add
  [a b]
  (+ (double a) (double b)))


(defn lean_float_sub
  [a b]
  (- (double a) (double b)))


(defn lean_float_mul
  [a b]
  (* (double a) (double b)))


(defn lean_float_div
  [a b]
  (/ (double a) (double b)))


(defn lean_float_negate
  [a]
  (- (double a)))


(defn lean_float_decLt
  [a b]
  (bool (< (double a) (double b))))


(defn lean_float_decLe
  [a b]
  (bool (<= (double a) (double b))))


(defn lean_float_beq
  [a b]
  (bool (== (double a) (double b))))


(defn lean_float_of_nat
  [a]
  (double a))


(defn lean_float_to_string
  [a]
  (let [a (double a)]
    (cond
      (Double/isNaN a) "NaN"
      (Double/isInfinite a) (if (pos? a) "inf" "-inf")
      :else (String/format java.util.Locale/ROOT "%f" (object-array [a])))))


(defn lean_float_of_scientific
  [m s e]
  (double (if (= s 1) (/ (bigdec m) (.pow 10M (int e))) (* (bigdec m) (.pow 10M (int e))))))


(defn sqrt
  [a]
  (Math/sqrt (double a)))


(defn floor
  [a]
  (Math/floor (double a)))


(defn ceil
  [a]
  (Math/ceil (double a)))


(defn round
  [a]
  (Math/round (double a)))


(defn exp
  [a]
  (Math/exp (double a)))


(defn log
  [a]
  (Math/log (double a)))


(defn sin
  [a]
  (Math/sin (double a)))


(defn cos
  [a]
  (Math/cos (double a)))


(defn tan
  [a]
  (Math/tan (double a)))


(defn pow
  [a b]
  (Math/pow (double a) (double b)))


;; Strings: positions are UTF-8 byte offsets

(defn- utf8
  ^bytes [^String s]
  (.getBytes s StandardCharsets/UTF_8))


(defn- ascii?
  [^String s]
  (let [n (.length s)]
    (loop [i 0]
      (cond
        (= i n) true
        (< (int (.charAt s i)) 128) (recur (inc i))
        :else false))))


(defn- lead-width
  ^long [^long b]
  (cond
    (zero? (bit-and b 0x80)) 1
    (= (bit-and b 0xE0) 0xC0) 2
    (= (bit-and b 0xF0) 0xE0) 3
    :else 4))


(defn- decode-at
  ^long [^bytes bs ^long i]
  (let [b0 (bit-and (aget bs i) 0xFF)
        n (alength bs)
        at (fn ^long [^long k] (if (< (+ i k) n) (bit-and (aget bs (+ i k)) 0x3F) 0))]
    (case (lead-width b0)
      1 b0
      2 (bit-or (bit-shift-left (bit-and b0 0x1F) 6) (at 1))
      3 (bit-or (bit-shift-left (bit-and b0 0x0F) 12) (bit-shift-left (at 1) 6) (at 2))
      (bit-or (bit-shift-left (bit-and b0 0x07) 18) (bit-shift-left (at 1) 12) (bit-shift-left (at 2) 6) (at 3)))))


(defn lean_string_utf8_byte_size
  [^String s]
  (if (ascii? s) (.length s) (alength (utf8 s))))


(defn lean_string_length
  [^String s]
  (.codePointCount s 0 (.length s)))


(defn lean_string_append
  [^String a ^String b]
  (.concat a b))


(defn lean_string_push
  [^String s c]
  (.toString (.appendCodePoint (StringBuilder. s) (int c))))


(defn lean_string_dec_eq
  [a b]
  (bool (= a b)))


(defn lean_string_dec_lt
  [^String a ^String b]
  (let [x (utf8 a) y (utf8 b)]
    (bool (neg? (java.util.Arrays/compareUnsigned x y)))))


(defn lean_string_utf8_at_end
  [s i]
  (bool (>= i (lean_string_utf8_byte_size s))))


(defn lean_string_utf8_get
  [^String s i]
  (if (ascii? s)
    (if (< i (.length s)) (long (int (.charAt s (int i)))) 65)
    (let [bs (utf8 s)]
      (if (< i (alength bs)) (decode-at bs i) 65))))


(defn lean_string_utf8_get_fast
  [s i]
  (lean_string_utf8_get s i))


(defn lean_string_utf8_next
  [^String s i]
  (if (ascii? s)
    (+' i 1)
    (let [bs (utf8 s)]
      (if (< i (alength bs))
        (+ (long i) (lead-width (bit-and (aget bs (int i)) 0xFF)))
        (+' i 1)))))


(defn lean_string_utf8_next_fast
  [s i]
  (lean_string_utf8_next s i))


(defn lean_string_utf8_prev
  [^String s i]
  (if (zero? i)
    0
    (let [bs (utf8 s)
          n (alength bs)]
      (if (> i n)
        (dec i)
        (loop [j (dec (long i))]
          (if (and (pos? j) (= (bit-and (aget bs j) 0xC0) 0x80))
            (recur (dec j))
            j))))))


(defn lean_string_utf8_extract
  [^String s b e]
  (let [bs (utf8 s)
        n (alength bs)
        e (min (long e) n)]
    (if (>= b e)
      ""
      (String. bs (int b) (int (- e b)) StandardCharsets/UTF_8))))


(defn lean_string_mk
  [cs]
  (let [sb (StringBuilder.)]
    (loop [l cs]
      (if (instance? Ctor l)
        (do (.appendCodePoint sb (int (proj l 0)))
            (recur (proj l 1)))
        (.toString sb)))))


(defn lean_string_data
  [^String s]
  (let [^ints cps (.toArray (.codePoints s))]
    (loop [i (dec (alength cps)) acc (identity 0)]
      (if (neg? i) acc (recur (dec i) (ctor 1 2 0 (long (aget cps i)) acc))))))


(defn lean_string_of_usize
  [a]
  (Long/toUnsignedString (long a)))


(defn lean_string_hash
  [^String s]
  (let [bs (utf8 s)
        m -4132994306676758123
        r 47
        n (alength bs)
        h0 (bit-xor 11 (unchecked-multiply n m))
        nblocks (quot n 8)
        h (loop [i 0 h h0]
            (if (= i nblocks)
              h
              (let [k (loop [j 7 k 0]
                        (if (neg? j) k (recur (dec j) (bit-or (bit-shift-left k 8) (bit-and (aget bs (+ (* i 8) j)) 0xFF)))))
                    k (unchecked-multiply k m)
                    k (bit-xor k (unsigned-bit-shift-right k r))
                    k (unchecked-multiply k m)]
                (recur (inc i) (unchecked-multiply (bit-xor h k) m)))))
        tail (* nblocks 8)
        rem (- n tail)
        h (if (pos? rem)
            (unchecked-multiply
              (loop [j (dec rem) h h]
                (if (neg? j) h (recur (dec j) (bit-xor h (bit-shift-left (bit-and (aget bs (+ tail j)) 0xFF) (* 8 j))))))
              m)
            h)
        h (bit-xor h (unsigned-bit-shift-right h r))
        h (unchecked-multiply h m)]
    (bit-xor h (unsigned-bit-shift-right h r))))


(defn lean_string_isempty
  [^String s]
  (bool (.isEmpty s)))


(defn lean_string_isprefixof
  [^String p ^String s]
  (bool (.startsWith s p)))


(defn lean_string_pushn
  [^String s c n]
  (let [sb (StringBuilder. s)]
    (dotimes [_ n] (.appendCodePoint sb (int c)))
    (.toString sb)))


(defn lean_string_posof
  [^String s c]
  (let [i (.indexOf s (int c))]
    (if (neg? i)
      (lean_string_utf8_byte_size s)
      (lean_string_utf8_byte_size (.substring s 0 i)))))


(defn lean_string_offsetofpos
  [^String s pos]
  (let [bs (utf8 s)
        n (min (long pos) (alength bs))]
    (loop [i 0 k 0]
      (if (>= i n) k (recur (+ i (lead-width (bit-and (aget bs i) 0xFF))) (inc k))))))


(defn lean_string_get_byte_fast
  [^String s i]
  (bit-and (aget (utf8 s) (int i)) 0xFF))


(defn lean_string_utf8_extract_fast
  [s b e]
  (lean_string_utf8_extract s b e))


(defn lean_string_utf8_set
  [^String s i c]
  (let [bs (utf8 s)]
    (if (>= i (alength bs))
      s
      (let [w (lead-width (bit-and (aget bs (int i)) 0xFF))]
        (str (String. bs 0 (int i) StandardCharsets/UTF_8)
             (String. (Character/toChars (int c)))
             (String. bs (int (+ (long i) w)) (int (- (alength bs) (long i) w)) StandardCharsets/UTF_8))))))


(defn lean_string_memcmp
  [^String a ^String b ls rs len]
  (let [x (utf8 a) y (utf8 b)]
    (bool (java.util.Arrays/equals x (int ls) (int (+ (long ls) (long len))) y (int rs) (int (+ (long rs) (long len)))))))


(defn lean_string_any
  [^String s p]
  (let [^ints cps (.toArray (.codePoints s))]
    (bool (some #(not (zero? (long (apply p %)))) cps))))


(defn lean_string_foldl
  [f init ^String s]
  (reduce #(apply f %1 %2) init (.toArray (.codePoints s))))


;; Arrays: persistent vectors

(defn lean_mk_empty_array_with_capacity
  [_]
  [])


(defn lean_array_mk
  [l]
  (loop [l l acc (transient [])] (if (instance? Ctor l) (recur (proj l 1) (conj! acc (proj l 0))) (persistent! acc))))


(defn lean_array_to_list
  [a]
  (reduce (fn [acc x] (ctor 1 2 0 x acc)) 0 (rseq (vec a))))


(defn lean_array_get_size
  [a]
  (count a))


(defn lean_array_size
  [a]
  (count a))


(defn lean_array_push
  [a v]
  (conj a v))


(defn lean_array_pop
  [a]
  (if (empty? a) a (pop a)))


(defn lean_array_fget
  [a i]
  (nth a i))


(defn lean_array_fget_borrowed
  [a i]
  (nth a i))


(defn lean_array_uget
  [a i]
  (nth a i))


(defn lean_array_uget_borrowed
  [a i]
  (nth a i))


(defn lean_array_fset
  [a i v]
  (assoc a i v))


(defn lean_array_uset
  [a i v]
  (assoc a i v))


(defn lean_mk_array
  [n v]
  (vec (repeat n v)))


(defn lean_panic_fn
  [dflt msg]
  (binding [*out* *err*]
    (println msg))
  dflt)


(defn lean_array_get_panic
  [dflt]
  (lean_panic_fn dflt "Error: index out of bounds"))


(defn lean_array_get
  [dflt a i]
  (if (< i (count a)) (nth a i) (lean_array_get_panic dflt)))


(defn lean_array_get_borrowed
  [dflt a i]
  (lean_array_get dflt a i))


(defn lean_array_set
  [a i v]
  (if (< i (count a)) (assoc a i v) a))


(defn lean_array_fswap
  [a i j]
  (assoc a i (nth a j) j (nth a i)))


(defn lean_array_swap
  [a i j]
  (if (and (< i (count a)) (< j (count a))) (lean_array_fswap a i j) a))


;; Float32: Java floats. An operation on two floats computed in double and
;; rounded to float is the correctly rounded float operation.

(defn- f32
  [x]
  (.floatValue (Double/valueOf (double x))))


(defn lean_float32_of_bits
  [u]
  (Float/intBitsToFloat (unchecked-int (long u))))


(defn lean_float_to_float32
  [a]
  (f32 a))


(defn lean_float32_to_float
  [a]
  (double a))


(defn lean_uint64_to_float32
  [a]
  (.floatValue (biginteger (u64->nat a))))


(defn lean_float32_add
  [a b]
  (f32 (+ (double a) (double b))))


(defn lean_float32_sub
  [a b]
  (f32 (- (double a) (double b))))


(defn lean_float32_mul
  [a b]
  (f32 (* (double a) (double b))))


(defn lean_float32_div
  [a b]
  (f32 (/ (double a) (double b))))


(defn sqrtf
  [a]
  (f32 (Math/sqrt (double a))))


(defn lean_float32_beq
  [a b]
  (if (== (double a) (double b)) 1 0))


(defn lean_float32_decLt
  [a b]
  (if (< (double a) (double b)) 1 0))


(declare lean_float_to_uint64)


(defn lean_float32_to_uint64
  [a]
  (lean_float_to_uint64 (double a)))


(defn lean_float32_to_string
  [a]
  (lean_float_to_string (double a)))


;; ByteArray and FloatArray: vectors of byte values (Long) and of doubles.

(defn lean_byte_array_mk
  [a]
  a)


(defn lean_mk_empty_byte_array
  [_]
  [])


(defn lean_byte_array_size
  [a]
  (count a))


(defn lean_byte_array_push
  [a b]
  (conj a b))


(defn lean_byte_array_get
  [a i]
  (if (and (instance? Long i) (< (long i) (count a))) (nth a i) 0))


(defn lean_byte_array_set
  [a i b]
  (if (and (instance? Long i) (< (long i) (count a))) (assoc a i b) a))


(defn lean_byte_array_copy_slice
  [src src-off dest dest-off len _exact]
  (let [src-off (min src-off (count src))
        n (min len (- (count src) src-off))
        dest-off (min dest-off (count dest))]
    (vec (concat (subvec dest 0 dest-off)
                 (subvec src src-off (+ src-off n))
                 (subvec dest (min (count dest) (+ dest-off n)))))))


(defn lean_string_to_utf8
  [^String s]
  (mapv #(bit-and (long %) 0xff) (.getBytes s java.nio.charset.StandardCharsets/UTF_8)))


(defn- utf8-bytes
  ^bytes [a]
  (byte-array (map unchecked-byte a)))


(defn lean_string_validate_utf8
  [a]
  (let [decoder (-> java.nio.charset.StandardCharsets/UTF_8
                    .newDecoder
                    (.onMalformedInput java.nio.charset.CodingErrorAction/REPORT)
                    (.onUnmappableCharacter java.nio.charset.CodingErrorAction/REPORT))]
    (try
      (.decode decoder (java.nio.ByteBuffer/wrap (utf8-bytes a)))
      1
      (catch java.nio.charset.CharacterCodingException _ 0))))


(defn lean_string_from_utf8_unchecked
  [a]
  (String. (utf8-bytes a) java.nio.charset.StandardCharsets/UTF_8))


(defn lean_float_array_mk
  [a]
  a)


(defn lean_float_array_size
  [a]
  (count a))


(defn lean_float_array_push
  [a d]
  (conj a d))


(defn lean_float_array_fget
  [a i]
  (nth a i))


(defn lean_float_array_get
  [a i]
  (if (and (instance? Long i) (< (long i) (count a))) (nth a i) 0.0))


(defn lean_float_array_set
  [a i d]
  (if (and (instance? Long i) (< (long i) (count a))) (assoc a i d) a))


;; Thunk and Task: delays and futures over Lean closures of `Unit`.

(defn lean_mk_thunk
  [c]
  (delay (apply c 0)))


(defn lean_thunk_pure
  [v]
  (delay v))


(defn lean_thunk_get_own
  [t]
  @t)


(defn lean_task_pure
  [a]
  (delay a))


(defn lean_task_spawn
  [c _prio]
  (future (apply c 0)))


(defn lean_task_map
  [f t _prio _sync]
  (future (apply f @t)))


(defn lean_task_bind
  [x f _prio _sync]
  (future @(apply f @x)))


(defn lean_task_get_own
  [t]
  @t)


(defn lean_dbg_trace
  [s f]
  (binding [*out* *err*] (println s))
  (apply f 0))


;; IO: an `IO` action returns `EST.Out`, `ok` (tag 0) with the value or
;; `error` (tag 1) with the `IO.Error`. A `BaseIO` or `ST` action, which cannot
;; fail, returns the value itself. The world argument is erased.

(defn- io-ok
  [a]
  (ctor 0 1 0 a))


(defn- stream
  "An `IO.FS.Stream` over the writer and reader that `out` and `in` return at
  the time of each call: flush, read, write, getLine, putStr, isTty."
  [out in]
  (ctor 0 6 0
        (closure (fn [_] (.flush ^java.io.Writer (out)) (io-ok 0)) 1 [])
        (closure (fn [n _]
                   (let [buf (char-array (min (long n) 65536))
                         k (.read ^java.io.Reader (in) buf)]
                     (io-ok (if (pos? k) (lean_string_to_utf8 (String. buf 0 k)) []))))
                 2 [])
        (closure (fn [bs _] (.write ^java.io.Writer (out) ^String (lean_string_from_utf8_unchecked bs)) (io-ok 0)) 2 [])
        (closure (fn [_]
                   (io-ok (if-let [l (binding [*in* (in)] (read-line))] (str l "\n") "")))
                 1 [])
        (closure (fn [s _] (.write ^java.io.Writer (out) ^String s) (.flush ^java.io.Writer (out)) (io-ok 0)) 2 [])
        (closure (fn [_] 0) 1 [])))


(defn lean_get_stdout
  []
  (stream (fn [] *out*) (fn [] *in*)))


(defn lean_get_stderr
  []
  (stream (fn [] *err*) (fn [] *in*)))


(defn lean_get_stdin
  []
  (stream (fn [] *out*) (fn [] *in*)))


(defn lean_io_mono_ms_now
  []
  (quot (System/nanoTime) 1000000))


(defn lean_io_mono_nanos_now
  []
  (norm (bigint (System/nanoTime))))


(defn lean_st_mk_ref
  [a]
  (atom a))


(defn lean_st_ref_get
  [r]
  @r)


(defn lean_st_ref_put
  [r a]
  (reset! r a)
  0)


(defn lean_st_ref_swap
  [r a]
  (first (swap-vals! r (constantly a))))


(defn lean_st_ref_take
  [r]
  (first (swap-vals! r (constantly 0))))


(defn lean_st_ref_ptr_eq
  [r1 r2]
  (if (identical? r1 r2) 1 0))


;; Marshalling between Clojure values and Lean values

(defonce ^:private types (atom {}))


(defn register-type!
  [k desc]
  (swap! types assoc k desc))


(defn registered-types
  "The structures and enumerations generated code has registered, by full
  Lean name."
  []
  @types)


(defn- lean-list->seq
  [l]
  (loop [l l acc (transient [])]
    (if (instance? Ctor l)
      (recur (proj l 1) (conj! acc (proj l 0)))
      (persistent! acc))))


(declare to-clj from-clj)


(defn- struct->map
  [{:keys [fields]} v]
  (into {}
        (for [[k [where i] d] fields]
          [k (to-clj d (if (= where :obj) (proj v i) (sproj v i)))])))


(defn- map->struct
  [{:keys [tag size ssize fields]} m]
  (let [c (ctor tag size ssize)]
    (doseq [[k [where i] d] fields]
      (let [x (from-clj d (get m k))]
        (if (= where :obj) (set-obj! c i x) (sset! c i x))))
    c))


(defn- sum->map
  [{:keys [ctors]} v]
  (let [t (if (instance? Ctor v) (tag v) v)
        {:keys [name fields]} (first (filter #(= t (:tag %)) ctors))]
    (into {:tag name}
          (for [[k [where i] d] fields]
            [k (to-clj d (if (= where :obj) (proj v i) (sproj v i)))]))))


(defn- map->sum
  [{:keys [ctors]} m]
  (let [{:keys [tag size ssize fields]} (or (first (filter #(= (:tag m) (:name %)) ctors))
                                            (throw (ex-info (str "lean-clj: no constructor " (:tag m)) {:value m})))]
    (if (and (zero? size) (zero? ssize))
      tag
      (let [c (ctor tag size ssize)]
        (doseq [[k [where i] d] fields]
          (let [x (from-clj d (get m k))]
            (if (= where :obj) (set-obj! c i x) (sset! c i x))))
        c))))


(defn to-clj
  [d v]
  (if (keyword? d)
    (case d
      :nat v
      :int v
      :bool (not (zero? (long v)))
      :string v
      :char (let [cp (long v)] (if (< cp 0x10000) (char cp) (String. (Character/toChars cp))))
      :u64 (u64->nat v)
      :float v
      :unit nil
      :raw v)
    (case (first d)
      :list (clojure.core/apply list (map #(to-clj (second d) %) (lean-list->seq v)))
      :array (mapv #(to-clj (second d) %) v)
      :option (when (instance? Ctor v) (to-clj (second d) (proj v 0)))
      :prod [(to-clj (nth d 1) (proj v 0)) (to-clj (nth d 2) (proj v 1))]
      :field1 {(nth d 1) (to-clj (nth d 2) v)}
      :io (if (zero? (tag v))
            (to-clj (second d) (proj v 0))
            (let [e (proj v 0)
                  msg (when (instance? Ctor e) (some #(when (string? %) %) (seq ^objects (.objs ^Ctor e))))]
              (throw (ex-info (str "lean-clj: IO error" (when msg (str ": " msg))) {:error e}))))
      :map (into {} (map (fn [p] [(to-clj (nth d 1) (proj p 0)) (to-clj (nth d 2) (proj p 1))]) (lean-list->seq v)))
      :set (into #{} (map #(to-clj (second d) %) (lean-list->seq v)))
      :ref (let [t (get @types (second d))]
             (case (:kind t)
               :struct (struct->map t v)
               :enum (nth (:ctors t) (tag v))
               :sum (sum->map t v))))))


(defn from-clj
  [d v]
  (if (keyword? d)
    (case d
      :nat (norm (bigint v))
      :int (norm (bigint v))
      :bool (if v 1 0)
      :string v
      :char (if (char? v) (long (int v)) (long v))
      :u64 (low64 (bigint v))
      :float (double v)
      :unit 0
      :raw v)
    (case (first d)
      :list (reduce (fn [acc x] (ctor 1 2 0 (from-clj (second d) x) acc)) 0 (reverse v))
      :array (mapv #(from-clj (second d) %) v)
      :option (if (nil? v) 0 (ctor 1 1 0 (from-clj (second d) v)))
      :prod (ctor 0 2 0 (from-clj (nth d 1) (nth v 0)) (from-clj (nth d 2) (nth v 1)))
      :field1 (from-clj (nth d 2) (get v (nth d 1)))
      :map (reduce (fn [acc [k x]] (ctor 1 2 0 (ctor 0 2 0 (from-clj (nth d 1) k) (from-clj (nth d 2) x)) acc)) 0 (reverse (seq v)))
      :set (reduce (fn [acc x] (ctor 1 2 0 (from-clj (second d) x) acc)) 0 (reverse (seq v)))
      :ref (let [t (get @types (second d))]
             (case (:kind t)
               :struct (map->struct t v)
               :enum (long (.indexOf ^java.util.List (:ctors t) v))
               :sum (map->sum t v))))))


(defn lean_panic_fn_borrowed
  [dflt msg]
  (lean_panic_fn dflt msg))


(defn lean_array_propagate_mark
  [_ ys]
  ys)


(defn lean_uint64_of_nat_mk
  [a]
  (low64 a))


(defn lean_float_of_bits
  [a]
  (Double/longBitsToDouble (long a)))


(defn lean_float_to_bits
  [a]
  (Double/doubleToRawLongBits (double a)))


(defn lean_float_to_uint64
  [a]
  (let [a (double a)]
    (cond
      (not (<= 0.0 a)) 0
      (>= a 1.8446744073709552E19) -1
      (< a 9.223372036854775807E18) (long a)
      :else (.longValue (.toBigInteger (bigdec a))))))
