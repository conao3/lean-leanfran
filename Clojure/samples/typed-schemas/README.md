# typed-schemas

What the Lean signature of a function gives Clojure tools. The structure
`Account` is defined in a `deflean` block, and the functions in
[`src/accounts/core.clj`](src/accounts/core.clj) take it in their
`lean-clj.typed/defn` signatures:

```clojure
(deflean types
  (structure Account [owner String balance Nat frozen Bool]))

(lt/defn deposit [a Account n Nat] Account
  (if (:frozen a) a (update a :balance + n)))
```

From these, `lean-clj.types` derives:

| What | Where it is used |
|---|---|
| `(types/malli-schema 'Account)`, `(types/fn-schema #'deposit)` | [`src/accounts/main.clj`](src/accounts/main.clj) registers the schema with `m/=>`, and `malli.instrument` rejects a negative balance |
| `(types/gen 'Account)` | test.check generators of accounts |
| `(types/write-kondo-config! ['accounts.core])` | [`.clj-kondo/lean-clj/types/config.edn`](.clj-kondo/lean-clj/types/config.edn), with which clj-kondo flags the calls in [`examples/misuse.clj`](examples/misuse.clj) |

`Nat` becomes a non-negative integer in each tool, and a structure a closed
map with the same keys as the values the generated code takes.

## Run

```
make kondo-config   # regenerate the clj-kondo types
make test           # run accounts.main and clj-kondo, compare with expected.txt
make run
```
