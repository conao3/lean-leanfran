# word-count

Print the most frequent words of a text. The counting is Lean, in
[`src/words/count.clj`](src/words/count.clj); the CLI in
[`src/words/main.clj`](src/words/main.clj) reads standard input and prints.

This sample shows two `deflean` features that [`todo-cli`](../todo-cli) does
not use:

- **`:imports`** brings in Lean modules beyond the core library, here
  `Std.HashMap`.
- **Lean source as a string** sits next to S-expression commands. Lean's `do`
  notation (`let mut`, `for`) has no S-expression form, so `frequencies` is
  written in Lean directly; the S-expression definitions call it like any other
  function.

```clojure
(deflean count
  {:imports ["Std.Data.HashMap"]}

  (def words [text String] (List String)
    (.filter (.map (.splitToList text (fn [c] (! (word-char? c))))
                   (fn [w] (.toLower w)))
             (fn [w] (! (.isEmpty w)))))

  "private def frequencies (ws : List String) : Std.HashMap String Nat := Id.run do
     let mut m := {}
     for w in ws do
       m := m.insert w (m.getD w 0 + 1)
     return m"

  (def top-words [n Nat text String] (List (Prod String Nat))
    ...)

  (theorem top-words-at-most [n Nat text String]
    (<= (.length (top-words n text)) n)
    (by (simp [top-words]) omega)))
```

`private` keeps `frequencies` out of the Clojure namespace. `top-words` returns
`List (String × Nat)`, which Clojure receives as a list of two-element
vectors:

```clojure
(wc/top-words 2 "the cat and the hat")  ;=> (["the" 2] ["and" 1])
```

## Usage

Inside `nix develop` of the repository root (the first run needs Lean to
expand `deflean`; `make` builds the `leanfran` CLI and puts it on `PATH`):

```
$ make run ARGS='--limit 4'
5	the
3	dog
2	fox
2	is
$ ./word-count text list-top-words --limit 2 < sample.txt
5	the
3	dog
```

`--limit` defaults to 10. `make test` compares the output for
[`sample.txt`](sample.txt) with `expected.txt`.
