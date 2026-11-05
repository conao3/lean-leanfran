# Samples

Programs built with lean-clj, each small enough to read in one sitting. Every
directory is a Clojure project that depends on lean-clj through
`:local/root`, with its own README and a `make test` that the repository's
`make check` runs. Run the samples inside `nix develop` of the repository
root.

lean-clj is used in three ways, and the samples follow them.

## 1. Write functions in Lean and call them from Clojure

`deflean` holds Lean inside a Clojure file. Lean checks the definitions and
their proofs when the namespace is compiled, and the functions become Clojure
functions of the namespace.

| Sample | What it shows |
|---|---|
| [`todo-cli`](todo-cli) | `deflean` in S-expressions: structures and theorems about the list operations, behind a Clojure CLI |
| [`word-count`](word-count) | `deflean` with `:imports` (`Std.HashMap`) and Lean source written as a string next to S-expressions, for `do` notation |

## 2. Compile a Lean project to a Clojure namespace

The `lean-clj` CLI compiles the modules of a lake project to a Clojure
namespace, which you commit and load without Lean.

| Sample | What it shows |
|---|---|
| [`roman-numerals`](roman-numerals) | an ordinary lake project compiled to a committed Clojure namespace, which runs without Lean |

## 3. Write functions in Clojure and verify them in Lean

`lean-clj.typed/defn` gives a Clojure function a Lean signature, and
`(clojure f)` in a `deflean` block turns the function into a Lean model to
prove theorems about. The ways of relating an implementation to its
specification each have a sample:

| How the implementation relates to the specification | Sample |
|---|---|
| The specification runs as it is | use 1: a `deflean` definition is the program |
| A faster implementation equals the specification on every input, and `@[csimp]` runs the implementation in its place | [`verified-clojure`](verified-clojure) (`sum-to`) |
| A faster implementation equals the specification under an assumption, and callers that meet it call the implementation | [`sorted-search`](sorted-search) |
| The implementation satisfies a property of its result | [`verified-clojure`](verified-clojure) (insertion sort is sorted), [`inventory`](inventory) (how operations change a map) |

The samples also cover the Clojure that such functions are written in:

| Sample | What it shows |
|---|---|
| [`inventory`](inventory) | maps (`(Map K V)`), `update` and `get` with defaults, `when` returning `nil`, and destructuring |
| [`generic-search`](generic-search) | a polymorphic function, a function with two arities, and rest arguments |

The signatures also serve Clojure tools without any proof:

| Sample | What it shows |
|---|---|
| [`typed-schemas`](typed-schemas) | malli schemas, test.check generators, and clj-kondo types derived from the Lean signatures |

## Where to start

Start with `todo-cli` for `deflean`, then `verified-clojure` for verifying
Clojure functions.
