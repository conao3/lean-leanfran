# verified-clojure

Clojure functions proved correct in Lean. The functions are written with
`leanfran.typed/defn`, which keeps a Lean signature on an ordinary Clojure
function; `(clojure f)` in a `deflean` block turns the function into a Lean
model to state and prove theorems about.

## Insertion sort

[`src/verified/sort.clj`](src/verified/sort.clj) sorts in Clojure:

```clojure
(lt/defn insert-sorted [x Int xs (List Int)] (List Int)
  (if-let [y (first xs)]
    (if (<= x y)
      (cons x xs)
      (cons y (insert-sorted x (rest xs))))
    (list x)))

(lt/defn sort-ints [xs (Array Int)] (List Int)
  (reduce (fn [acc x] (insert-sorted x acc)) () xs))
```

and proves, about the Lean models of these functions:

| Theorem | Statement |
|---|---|
| `insert-sorted-nil`, `insert-sorted-cons` | the equations of `insert-sorted` on `[]` and `y :: t` |
| `mem-insert-sorted` | the elements of `(insert-sorted x xs)` are `x` and those of `xs` |
| `insert-sorted-sorted` | `insert-sorted` keeps a sorted list sorted |
| `sort-ints-sorted` | `sort-ints` returns a sorted list |

## A specification run as its closed form

[`src/verified/sum.clj`](src/verified/sum.clj) defines `sum-to` in Lean as the
recursive sum `0 + 1 + ... + n`, and `sum-to-fast` in Clojure as
`n (n + 1) / 2`. The `@[csimp]` theorem `sum-to-eq` proves them equal, so
compiled Lean code, and the Clojure function `sum-to` that `deflean` defines,
run `sum-to-fast`: `(sum-to 1000000)` returns at once, without a million
nested calls.

## Run

```
make test    # run verified.main and compare with expected.txt
make run
```

`verified.main` also runs `leanfran.typed/check` on each function, which
compares the Clojure function with its Lean model on generated inputs.
