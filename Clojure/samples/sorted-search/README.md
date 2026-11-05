# sorted-search

A fast implementation that equals the specification only under an
assumption. `sorted-member?` in [`src/search/core.clj`](src/search/core.clj)
looks for `x` in a list and stops at the first element larger than `x`:

```clojure
(lt/defn sorted-member? [x Int xs (List Int)] Bool
  (if-let [y (first xs)]
    (cond
      (= x y) true
      (< x y) false
      :else (sorted-member? x (rest xs)))
    false))
```

The theorem `sorted-member-eq` proves that, for a sorted `xs`, the result is
`List.contains xs x`. The equality needs the assumption: `(sorted-member? 1
'(2 1))` is `false`, though `1` is in the list. A `@[csimp]` lemma has to hold
for every input, so this one stays a theorem, and callers that know their list
is sorted call `sorted-member?` directly.

## Run

```
make test    # run search.main and compare with expected.txt
make run
```
