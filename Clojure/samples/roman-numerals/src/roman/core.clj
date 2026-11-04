(ns roman.core
  (:refer-clojure :exclude [to-roman from-roman])
  (:require
    [lean-clj.runtime]))


(lean-clj.runtime/check-symbols! ["lean_nat_add" "lean_nat_dec_eq" "lean_nat_sub" "lean_nat_dec_le"
                                  "lean_string_append" "lean_string_utf8_byte_size"
                                  "lean_string_data" "lean_uint32_dec_eq" "lean_nat_dec_lt"])


(declare lean--Roman-toRoman
         lean--_private-Roman-0-Roman-numerals
         lean--_private-Roman-0-Roman-numerals-_closed_38
         lean--_private-Roman-0-Roman-numerals-_closed_37
         lean--_private-Roman-0-Roman-numerals-_closed_36
         lean--_private-Roman-0-Roman-numerals-_closed_35
         lean--_private-Roman-0-Roman-numerals-_closed_34
         lean--_private-Roman-0-Roman-numerals-_closed_33
         lean--_private-Roman-0-Roman-numerals-_closed_32
         lean--_private-Roman-0-Roman-numerals-_closed_31
         lean--_private-Roman-0-Roman-numerals-_closed_30
         lean--_private-Roman-0-Roman-numerals-_closed_29
         lean--_private-Roman-0-Roman-numerals-_closed_28
         lean--_private-Roman-0-Roman-numerals-_closed_27
         lean--_private-Roman-0-Roman-numerals-_closed_26
         lean--_private-Roman-0-Roman-numerals-_closed_25
         lean--_private-Roman-0-Roman-numerals-_closed_24
         lean--_private-Roman-0-Roman-numerals-_closed_23
         lean--_private-Roman-0-Roman-numerals-_closed_22
         lean--_private-Roman-0-Roman-numerals-_closed_21
         lean--_private-Roman-0-Roman-numerals-_closed_20
         lean--_private-Roman-0-Roman-numerals-_closed_19
         lean--_private-Roman-0-Roman-numerals-_closed_18
         lean--_private-Roman-0-Roman-numerals-_closed_17
         lean--_private-Roman-0-Roman-numerals-_closed_16
         lean--_private-Roman-0-Roman-numerals-_closed_15
         lean--_private-Roman-0-Roman-numerals-_closed_14
         lean--_private-Roman-0-Roman-numerals-_closed_13
         lean--_private-Roman-0-Roman-numerals-_closed_12
         lean--_private-Roman-0-Roman-numerals-_closed_11
         lean--_private-Roman-0-Roman-numerals-_closed_10
         lean--_private-Roman-0-Roman-numerals-_closed_9
         lean--_private-Roman-0-Roman-numerals-_closed_8
         lean--_private-Roman-0-Roman-numerals-_closed_7
         lean--_private-Roman-0-Roman-numerals-_closed_6
         lean--_private-Roman-0-Roman-numerals-_closed_5
         lean--_private-Roman-0-Roman-numerals-_closed_4
         lean--_private-Roman-0-Roman-numerals-_closed_3
         lean--_private-Roman-0-Roman-numerals-_closed_2
         lean--_private-Roman-0-Roman-numerals-_closed_1
         lean--_private-Roman-0-Roman-numerals-_closed_0
         lean--_private-Roman-0-Roman-toRomanAux
         lean--_private-Roman-0-Roman-toRomanAux-_closed_0
         lean--Roman-fromRoman
         lean--_private-Roman-0-Roman-fromRomanAux
         lean--_private-Roman-0-Roman-fromRomanAux-_closed_0
         lean--_private-Roman-0-Roman-value)


(defn- lean--_private-Roman-0-Roman-value
  [x_1]
  (let [x_2 73
        x_3 (lean-clj.runtime/lean_uint32_dec_eq x_1 x_2)]
    (case (long x_3)
      0
      (let [x_4 86
            x_5 (lean-clj.runtime/lean_uint32_dec_eq x_1 x_4)]
        (case (long x_5)
          0
          (let [x_6 88
                x_7 (lean-clj.runtime/lean_uint32_dec_eq x_1 x_6)]
            (case (long x_7)
              0
              (let [x_8 76
                    x_9 (lean-clj.runtime/lean_uint32_dec_eq x_1 x_8)]
                (case (long x_9)
                  0
                  (let [x_10 67
                        x_11 (lean-clj.runtime/lean_uint32_dec_eq x_1 x_10)]
                    (case (long x_11)
                      0
                      (let [x_12 68
                            x_13 (lean-clj.runtime/lean_uint32_dec_eq x_1 x_12)]
                        (case (long x_13)
                          0
                          (let [x_14 77
                                x_15 (lean-clj.runtime/lean_uint32_dec_eq x_1 x_14)]
                            (case (long x_15)
                              0 (let [x_16 0] x_16)
                              1 (let [x_17 1000] x_17)
                              (lean-clj.runtime/unreachable)))
                          1 (let [x_18 500] x_18)
                          (lean-clj.runtime/unreachable)))
                      1 (let [x_19 100] x_19)
                      (lean-clj.runtime/unreachable)))
                  1 (let [x_20 50] x_20)
                  (lean-clj.runtime/unreachable)))
              1 (let [x_21 10] x_21)
              (lean-clj.runtime/unreachable)))
          1 (let [x_22 5] x_22)
          (lean-clj.runtime/unreachable)))
      1 (let [x_23 1] x_23)
      (lean-clj.runtime/unreachable))))


(def ^:private lean--_private-Roman-0-Roman-fromRomanAux-_closed_0
  (delay (let [x_1 0 x_2 (lean-clj.runtime/ctor 1 1 0 x_1)] x_2)))


(defn- lean--_private-Roman-0-Roman-fromRomanAux
  [x_1]
  (case (lean-clj.runtime/tag x_1)
    0 (force lean--_private-Roman-0-Roman-fromRomanAux-_closed_0)
    1
    (let [x_3 (lean-clj.runtime/proj x_1 0)
          x_4 (lean-clj.runtime/proj x_1 1)
          x_5 x_3
          x_6 (lean--_private-Roman-0-Roman-value x_5)
          x_7 0
          x_8 (lean-clj.runtime/lean_nat_dec_eq x_6 x_7)]
      (case (long x_8)
        0
        (case (lean-clj.runtime/tag x_4)
          0 (let [x_9 (lean-clj.runtime/ctor 1 1 0 x_6)] x_9)
          1
          (let [x_10 (lean-clj.runtime/proj x_4 0)
                x_11 x_10
                x_12 (lean--_private-Roman-0-Roman-value x_11)
                x_13 (lean-clj.runtime/lean_nat_dec_lt x_6 x_12)]
            (case (long x_13)
              0
              (let [x_14 (lean--_private-Roman-0-Roman-fromRomanAux x_4)]
                (case (lean-clj.runtime/tag x_14)
                  0 x_14
                  1
                  (let [x_15 (lean-clj.runtime/proj x_14 0)]
                    (letfn [(block_16 [x_17 x_18] (let [x_19 (lean-clj.runtime/lean_nat_add x_15 x_6)] (letfn [(block_20 [x_21] x_21)] (case (long x_18) 0 (do (lean-clj.runtime/set-obj! x_17 0 x_19) (block_20 x_17)) 1 (let [x_22 (lean-clj.runtime/ctor 1 1 0 x_19)] (block_20 x_22)) (lean-clj.runtime/unreachable)))))]
                      (let [x_23 1]
                        (case (long x_23)
                          0 (block_16 x_14 x_23)
                          1 (block_16 nil x_23)
                          (lean-clj.runtime/unreachable)))))
                  (lean-clj.runtime/unreachable)))
              1
              (let [x_24 (lean--_private-Roman-0-Roman-fromRomanAux x_4)]
                (case (lean-clj.runtime/tag x_24)
                  0 x_24
                  1
                  (let [x_25 (lean-clj.runtime/proj x_24 0)]
                    (letfn [(block_26 [x_27 x_28] (let [x_29 (lean-clj.runtime/lean_nat_sub x_25 x_6)] (letfn [(block_30 [x_31] x_31)] (case (long x_28) 0 (do (lean-clj.runtime/set-obj! x_27 0 x_29) (block_30 x_27)) 1 (let [x_32 (lean-clj.runtime/ctor 1 1 0 x_29)] (block_30 x_32)) (lean-clj.runtime/unreachable)))))]
                      (let [x_33 1]
                        (case (long x_33)
                          0 (block_26 x_24 x_33)
                          1 (block_26 nil x_33)
                          (lean-clj.runtime/unreachable)))))
                  (lean-clj.runtime/unreachable)))
              (lean-clj.runtime/unreachable)))
          (lean-clj.runtime/unreachable))
        1 (let [x_34 0] x_34)
        (lean-clj.runtime/unreachable)))
    (lean-clj.runtime/unreachable)))


(defn- lean--Roman-fromRoman
  [x_1]
  (let [x_2 (lean-clj.runtime/lean_string_utf8_byte_size x_1)
        x_3 0
        x_4 (lean-clj.runtime/lean_nat_dec_eq x_2 x_3)]
    (case (long x_4)
      0
      (let [x_5 (lean-clj.runtime/lean_string_data x_1)]
        (lean--_private-Roman-0-Roman-fromRomanAux x_5))
      1 (let [x_7 0] x_7)
      (lean-clj.runtime/unreachable))))


(def ^:private lean--_private-Roman-0-Roman-toRomanAux-_closed_0 (delay (let [x_1 ""] x_1)))


(defn- lean--_private-Roman-0-Roman-toRomanAux
  [x_1 x_2 x_3]
  (loop [x_1 x_1
         x_2 x_2
         x_3 x_3]
    (let [x_4 0
          x_5 (lean-clj.runtime/lean_nat_dec_eq x_1 x_4)]
      (case (long x_5)
        1 (force lean--_private-Roman-0-Roman-toRomanAux-_closed_0)
        0
        (case (lean-clj.runtime/tag x_2)
          0 (force lean--_private-Roman-0-Roman-toRomanAux-_closed_0)
          1
          (let [x_8 (lean-clj.runtime/proj x_2 0)
                x_9 (lean-clj.runtime/proj x_2 1)
                x_10 (lean-clj.runtime/proj x_8 0)
                x_11 (lean-clj.runtime/proj x_8 1)
                x_12 1
                x_13 (lean-clj.runtime/lean_nat_sub x_1 x_12)
                x_14 (lean-clj.runtime/lean_nat_dec_le x_10 x_3)]
            (case (long x_14)
              0 (recur x_13 x_9 x_3)
              1
              (let [x_16 (lean-clj.runtime/lean_nat_sub x_3 x_10)
                    x_17 (lean--_private-Roman-0-Roman-toRomanAux x_13 x_2 x_16)]
                (lean-clj.runtime/lean_string_append x_11 x_17))
              (lean-clj.runtime/unreachable)))
          (lean-clj.runtime/unreachable))
        (lean-clj.runtime/unreachable)))))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_0 (delay (let [x_1 "M"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_1
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_0)
               x_2 1000
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_2 (delay (let [x_1 "CM"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_3
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_2)
               x_2 900
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_4 (delay (let [x_1 "D"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_5
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_4)
               x_2 500
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_6 (delay (let [x_1 "CD"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_7
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_6)
               x_2 400
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_8 (delay (let [x_1 "C"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_9
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_8)
               x_2 100
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_10 (delay (let [x_1 "XC"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_11
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_10)
               x_2 90
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_12 (delay (let [x_1 "L"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_13
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_12)
               x_2 50
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_14 (delay (let [x_1 "XL"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_15
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_14)
               x_2 40
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_16 (delay (let [x_1 "X"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_17
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_16)
               x_2 10
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_18 (delay (let [x_1 "IX"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_19
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_18)
               x_2 9
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_20 (delay (let [x_1 "V"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_21
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_20)
               x_2 5
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_22 (delay (let [x_1 "IV"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_23
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_22)
               x_2 4
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_24 (delay (let [x_1 "I"] x_1)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_25
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_24)
               x_2 1
               x_3 (lean-clj.runtime/ctor 0 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_26
  (delay (let [x_1 0
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_25)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_27
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_26)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_23)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_28
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_27)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_21)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_29
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_28)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_19)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_30
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_29)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_17)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_31
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_30)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_15)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_32
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_31)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_13)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_33
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_32)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_11)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_34
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_33)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_9)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_35
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_34)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_7)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_36
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_35)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_5)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_37
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_36)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_3)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals-_closed_38
  (delay (let [x_1 (force lean--_private-Roman-0-Roman-numerals-_closed_37)
               x_2 (force lean--_private-Roman-0-Roman-numerals-_closed_1)
               x_3 (lean-clj.runtime/ctor 1 2 0 x_2 x_1)]
           x_3)))


(def ^:private lean--_private-Roman-0-Roman-numerals
  (delay (force lean--_private-Roman-0-Roman-numerals-_closed_38)))


(defn- lean--Roman-toRoman
  [x_1]
  (let [x_2 13
        x_3 (lean-clj.runtime/lean_nat_add x_1 x_2)
        x_4 (force lean--_private-Roman-0-Roman-numerals)]
    (lean--_private-Roman-0-Roman-toRomanAux x_3 x_4 x_1)))


(defn to-roman
  [a0]
  (lean-clj.runtime/to-clj :string (lean--Roman-toRoman (lean-clj.runtime/from-clj :nat a0))))


(defn from-roman
  [a0]
  (lean-clj.runtime/to-clj [:option :nat]
                           (lean--Roman-fromRoman (lean-clj.runtime/from-clj :string a0))))
