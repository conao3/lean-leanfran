# Samples

Programs built with lean-clj, each small enough to read in one sitting. Every
directory is a Clojure project that depends on lean-clj through
`:local/root`, with its own README and a `make test` that the repository's
`make check` runs.

| Sample | What it shows |
|---|---|
| [`todo-cli`](todo-cli) | `deflean` in S-expressions: structures and theorems about the list operations, behind a Clojure CLI |
| [`word-count`](word-count) | `deflean` with `:imports` (`Std.HashMap`) and Lean source written as a string next to S-expressions, for `do` notation |
| [`roman-numerals`](roman-numerals) | an ordinary lake project compiled to a committed Clojure namespace with the `lean-clj` CLI, which runs without Lean |

Start with `todo-cli`. Run the samples inside `nix develop` of the repository
root.
