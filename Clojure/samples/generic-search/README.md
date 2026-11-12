# generic-search

Clojure functions with the signatures Clojure functions often have, proved in
Lean: [`src/generic/core.clj`](src/generic/core.clj) has a membership test for
any element type, a function with two arities, and one with rest arguments.

```clojure
(lt/defn member? [(implicit α Type) (inst (BEq α)) x α xs (List α)] Bool
  (if-some [y (first xs)]
    (or (= x y) (member? x (rest xs)))
    false))

(lt/defn clamp
  ([x Int] Int (clamp x 0 100))
  ([x Int lo Int hi Int] Int (max lo (min hi x))))

(lt/defn total [x Int & more (List Int)] Int
  (reduce + x more))
```

| Theorem | Statement |
|---|---|
| `member-head` | an element is a member of a list that starts with it, for any type with lawful equality |
| `member-nil` | nothing is a member of the empty list |
| `clamp-in-range` | the three-argument `clamp` (`clamp.arity3`) returns a value within `[lo, hi]` |
| `total-nil` | `total` of one argument is that argument |

`member?` uses `if-some`: with `if-let`, a `false` element would end the search
early, since `if-let` tests truthiness. The model of a polymorphic function takes
`[Clj.Truthy α]`, so its theorems hold at every element type; a theorem
about one states `(inst (Clj.Truthy α))` among its binders.

`generic.main` checks `member?` at `Int` and at `String` with
`(lt/check #'member? {:at '{α String}})`, and each arity of `clamp`.

## Run

```
make test    # run generic.main and compare with expected.txt
make run
```
