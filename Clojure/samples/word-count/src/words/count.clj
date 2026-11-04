(ns words.count
  "Word frequencies, written in Lean."
  (:require
    [lean-clj.core :refer [deflean]]))


(deflean count
  {:imports ["Std.Data.HashMap"]}

  (def word-char?
    [c Char] Bool
    (|| (.isAlphanum c) (== c \')))

  (def words
    [text String] (List String)
    (.filter (.map (.splitToList text (fn [c] (! (word-char? c))))
                   (fn [w] (.toLower w)))
             (fn [w] (! (.isEmpty w)))))

  "private def frequencies (ws : List String) : Std.HashMap String Nat := Id.run do
     let mut m := {}
     for w in ws do
       m := m.insert w (m.getD w 0 + 1)
     return m"

  (def top-words
    [n Nat text String] (List (Prod String Nat))
    (.take (.toList (.qsort (.toArray (frequencies (words text)))
                            (fn [a b]
                              (|| (> (.snd a) (.snd b))
                                  (&& (== (.snd a) (.snd b)) (< (.fst a) (.fst b)))))))
           n))

  (theorem top-words-at-most [n Nat text String]
           (<= (.length (top-words n text)) n)
           (by (simp [top-words]) omega)))
