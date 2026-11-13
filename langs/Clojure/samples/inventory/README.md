# inventory

Stock kept in a Clojure map from item names to quantities.
[`src/inventory/core.clj`](src/inventory/core.clj) writes the operations with
the Clojure that maps take: `update` with a function that handles a missing
item (`(or q 0)`), `get` with a default, `when` that returns `nil` for an
order that cannot be filled, and destructuring of `[item n]` lines.

```clojure
(lt/defn take-out [stock (Map String Int) item String n Int] (Option (Map String Int))
  (let [q (get stock item 0)]
    (when (<= n q)
      (assoc stock item (- q n)))))
```

`(Map K V)` in a signature is `Clj.Map`, the Lean model of a Clojure map. The
theorems are about how the operations change the map:

| Theorem | Statement |
|---|---|
| `restock-adds` | after `restock`, the item holds its old quantity plus `n` |
| `restock-keeps-others` | `restock` leaves the other items as they were |
| `take-out-short` | `take-out` of more than the stock is `nil` |
| `take-out-takes` | otherwise the item holds its old quantity minus `n` |

The proofs use the `Clj.Map` lemmas `get_insert_self` and `get_insert_ne`.

## Run

```
make test    # run inventory.main and compare with expected.txt
make run
```
