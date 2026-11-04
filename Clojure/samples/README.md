# Samples

Programs built with lean-clj. Each directory is a self-contained Clojure
project that depends on lean-clj through `:local/root`, with its own README
and a `make test` that the repository's `make check` runs.

| Sample | Description |
|---|---|
| [`todo-cli`](todo-cli) | A command-line todo list whose operations are Lean definitions with proofs, written with `deflean` |
