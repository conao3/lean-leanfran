# Clojure guide

[leanfran](../README.md) · [Clojure quick start](../langs/Clojure/README.md)

Commands and source paths below are relative to `langs/Clojure/`.

## Quick start

```clojure
(ns demo.core
  (:refer-clojure :exclude [double])
  (:require [leanfran.core :refer [deflean]]))

(deflean arith
  (def double [n Nat] Nat
    (+ n n))

  (theorem double_eq [n Nat] (= (double n) (* 2 n))
    (by (unfold double) omega))

  (structure Account [owner String balance Nat])

  (def deposit [a Account n Nat] Account
    (with a {:balance (+ (.balance a) n)})))

(double 21)                                ;=> 42
(deposit {:owner "ann" :balance 10} 5)     ;=> {:owner "ann", :balance 15}
```

If a proof in the block fails, compilation stops and prints Lean's error
messages next to the Lean source of the block.

## Installation

See the [Clojure quick start](../langs/Clojure/README.md) for installation.

## Values

Public functions convert arguments and results between Clojure and Lean values
according to the Lean signature:

| Lean                                              | Clojure                                                           |
| ------------------------------------------------- | ----------------------------------------------------------------- |
| `Nat`, `Int`, `UInt8`..`UInt64`, `Fin n`, `Float` | numbers (`BigInt` beyond `Long`)                                  |
| `Unit`                                            | `nil`                                                             |
| `Bool`                                            | `true` / `false`                                                  |
| `Char`                                            | `Character`                                                       |
| `String`                                          | string                                                            |
| `List α` / `Array α`                              | list / vector                                                     |
| `Option α`                                        | the value or `nil`                                                |
| `α × β`                                           | two-element vector                                                |
| structures                                        | maps with keyword keys (a one-field structure too)                |
| enumerations                                      | keywords (`Suit.hearts` → `:hearts`)                              |
| other inductives (`Except` too)                   | maps with a `:tag` (`{:tag :circle :r 1}`, `{:tag :ok :value 3}`) |
| `Clj.Map κ ν` / `Clj.Set α`                       | map / set                                                         |
| `IO α`                                            | the value of running the action, or an exception                  |

Other types pass through in the runtime representation (`Ctor` objects, and
`Closure` objects that also implement `IFn`).

Inside generated code, `Nat` and `Int` are `Long`/`BigInt`, fixed-width
integers and `Bool` are `Long`, `UInt64` holds the 64-bit pattern in a `Long`,
`String` positions are UTF-8 byte offsets as in Lean, and `Array` is a
persistent vector.

At run time, only the JVM runs. Lean runs when a `deflean` block expands or
when the CLI compiles a module, and `leanfran.runtime` replaces Lean's C
runtime, so no Lean process, FFI, or second heap takes part. The values that
cross between Clojure and generated code are immutable, and Lean's mutable
state runs on Clojure's own: `IO.Ref` and `ST.Ref` are atoms, `Task` is a
future, `Thunk` is a delay, a constant is a delay computed once per namespace,
and the standard streams are `*out*`, `*err*`, and `*in*`, so `binding`
redirects them.

## `deflean`

```clojure
(deflean <block> [{:imports ["Std.Data.HashMap"]}] <command> ...)
```

Each command is an S-expression of `leanfran.dsl` or a string of Lean source.
`leanfran.dsl/render` shows the Lean source of a sequence of commands.

| S-expression                                                           | Lean                                               |
| ---------------------------------------------------------------------- | -------------------------------------------------- |
| `(def f [x T y U] R body)`                                             | `def f (x : T) (y : U) : R := body`                |
| `(theorem t [x T] P proof)`                                            | `theorem t (x : T) : P := proof`                   |
| `(structure S [f T g U] (deriving Repr))`                              | `structure S where f : T ...`                      |
| `(inductive I a (b [x T]))`                                            | `inductive I where \| a \| b (x : T)`              |
| `(instance C body)`, `(mutual ...)`, `(namespace N ...)`, `(open N)`   | the same commands                                  |
| `(f a b)`, `(+ a b c)`, `(- a)`, `(not p)`                             | `(f a b)`, `(a + b + c)`, `(-a)`, `(¬p)`           |
| `(if c t e)`, `(if h c t e)`, `(let [x v] e)`, `(fn [x] e)`            | `if`, `if h : c then`, `let`, `fun`                |
| `(match x p1 e1 p2 e2)`, `(match [x y] [p q] e)`, `(match-eq h x ...)` | `match x with \| p1 => e1 ...`, `match h : x with` |
| `(.field x)`, `(.method x a)`                                          | `x.field`, `(x.method a)`                          |
| `{:x 1}`, `(with s {:x 1})`, `(<> a b)`                                | `{ x := 1 }`, `{ s with x := 1 }`, `⟨a, b⟩`        |
| `[a b]`, `(array a b)`                                                 | `[a, b]`, `#[a, b]`                                |
| `(the T e)`, `(-> A B)`, `(forall [x T] P)`, `(exists [x T] P)`        | `(e : T)`, `A → B`, `∀`, `∃`                       |
| `(by (simp [a b]) omega)`                                              | `(by simp [a, b]; omega)`                          |
| `(lean "...")`                                                         | Lean source as is                                  |

Names:

- A `-` in a symbol becomes lowerCamelCase in Lean (`is-prime` → `isPrime`),
  and the public Clojure name converts back (`is-prime`). leanfran keeps `_`,
  so you write Lean lemma names as they are (`Nat.add_comm`).
- Binder vectors take `(implicit α Type)` and `(inst (BEq α))`. Metadata on a
  name adds modifiers (`^:partial`, `^:private`, `^{:attrs [simp]}`), and
  `:termination-by` and `:decreasing-by` on a `def` add `termination_by` and
  `decreasing_by`.
- Inside `by`, a `-` in a tactic name becomes `_` (`all-goals` → `all_goals`).
  `(on-all t1 t2)` is `t1 <;> t2`, and `(case tag [x] t ...)` is
  `case tag x => ...`.

Binary operators: `+ - * / % pow ++ = == != not= < <= > >= and or iff && ||
band bor land lor xor <<< >>> in not-in cons |> <| >>= <$> comp`.

### Blocks, modules, and the cache

The block becomes the Lean module `LeanCljEmbed.<Namespace>.<Block>` (for
`demo.core` and `arith`: `LeanCljEmbed.Demo.Core.Arith`) in the lake workspace
`.leanfran/`. The workspace is `$LEANFRAN_CLJ_WORKSPACE`, or `.leanfran/` of the
project root, the nearest directory up from the working directory with a
`deps.edn`.

- `{:use [other-block demo.types/types]}` imports and opens other blocks, of
  the same namespace or of another one, so that a block uses their structures
  and functions.
- `(export f {:at {α Int} :as name})` adds a monomorphic definition that calls
  the polymorphic definition `f` of the block. Clojure calls it as `name`
  (by default `f-int`). A definition that cannot be a Clojure function (one
  with instance arguments, say) is reported when the block expands.
- Each Clojure function that a block defines carries `:lean/name` and
  `:lean/module` metadata.
- leanfran caches the generated code in `.leanfran/cache/` under a hash of the
  block's Lean module and of the deflean modules it imports, so changing a
  block regenerates the blocks that use it. With the cache present, expanding a
  block needs no Lean.
- An error from Lean points at the Clojure file and line of the form it came
  from, followed by the Lean source of the block.
- The `leanfran` CLI on `PATH` must be the version of the library.

clj-kondo picks up the names a block defines through the hook exported in
`resources/clj-kondo.exports/io.github.conao3/leanfran`.

## Verifying Clojure functions

`leanfran.typed/defn` defines an ordinary Clojure function with a Lean
signature. `(clojure f ...)` in a `deflean` block translates the function into
a Lean definition, its model, to state and prove theorems about:

```clojure
(require '[leanfran.typed :as lt])

(lt/defn insert-sorted [x Int xs (List Int)] (List Int)
  (if-let [y (first xs)]
    (if (<= x y) (cons x xs) (cons y (insert-sorted x (rest xs))))
    (list x)))

(deflean sorting
  (clojure insert-sorted)

  (theorem insert-sorted-length [x Int xs (List Int)]
    (= (.length (insert-sorted x xs)) (+ (.length xs) 1))
    (by (on-all (fun-induction insert-sorted x xs) simp-all grind))))
```

### Signatures

- `[x T y U] R`, as in `deflean`. Parameters may be destructuring forms
  (`[[a b] (Prod Int String) {:keys [owner]} Account]`), and `& xs (List T)`
  takes the rest arguments.
- `(lt/defn f ([x Int] Int ...) ([x Int y Int] Int ...))` has several arities;
  their models are `f.arity1` and `f.arity2`.
- `(implicit α Type)` and `(inst (BEq α))` make a polymorphic function. Its
  model takes `[Clj.Truthy α]` too, so that a test of an `α` value means what
  it means at the type the caller uses; theorems about it state
  `(inst (Clj.Truthy α))` among their binders.
- Types are Lean types, and `(Map K V)` and `(Set α)` are the models of Clojure
  maps and sets.
- `:termination-by` (a Lean term) and `:decreasing-by` metadata on the name
  give Lean the termination argument; Lean finds it itself for recursion on
  `(rest xs)` under `(if-let [y (first xs)] ...)`.

### What the translation takes

| Clojure                                                                                                                  | Lean model                                                                                           |
| ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `if`, `when`, `when-not`, `if-not`, `cond`, `case` on keywords and literals                                              | `if h : truthy c = true`, `match`; a local tested by `if` stands for its non-nil value in the branch |
| `if-let`, `when-let`, `if-some`, `when-some`                                                                             | `match h : v with \| some x => ...`                                                                  |
| `and`, `or`                                                                                                              | `&&`, `\|\|` in conditions; the first falsy or truthy value elsewhere (`(or x 0)`)                   |
| `let`, `fn`, destructuring                                                                                               | `let`, `fun`, projections (`Clj.elem i` of a vector: a pair's component, or an `Option` element)     |
| `lt/loop` (`[i Nat 0 ...]`) and `recur`, `lt/letfn`                                                                      | a local `let rec`                                                                                    |
| calls of `lt/defn` functions and of functions from `deflean`                                                             | calls of their models and Lean definitions; mutual recursion becomes `mutual`                        |
| keywords: `(:k m)`, `(get m :k)`, `(map :k xs)`, `assoc`, `update`                                                       | structure fields                                                                                     |
| `{k v}` with other keys, `#{...}`, `get`, `assoc`, `update`, `dissoc`, `merge`, `frequencies`, `group-by`, `clojure.set` | `Clj.Map`, `Clj.Set`                                                                                 |
| `'(1 2)`, `[a b]`, macros that expand to these (`->`, `->>`, `cond->`)                                                   | list and vector literals; a two-element vector is a pair or a vector                                 |

`do` with several forms, atoms, Java interop, `try`, `keys` and `vals` of a hash
map (whose order is the hash order), and keyword-keyed maps other than
structures stop the translation with the reason.

### The models of clojure.core

The Lean library `Clj`
([`resources/leanfran/lean/Clj.lean`](../langs/Clojure/resources/leanfran/lean/Clj.lean)) models
the arithmetic of `Nat`, `Int`, and `Float`; truthiness and `nil`; the sequence
functions (`map`, `filter`, `reduce`, `some`, `every?`, `mapcat`, `keep`,
`partition`, `distinct`, `sort`, `sort-by`, `take-while`, `interpose`, and
more); maps and sets; `str` and `clojure.string`. Where Clojure's meaning
depends on the type, a model has instances only for the types on which Lean can
state it: `-` and `dec` take `Int` (Clojure's `(- 3 5)` is `-2`), and `first`,
`next`, `seq`, and `get` return `Option`. `simp only [clj_simp]` rewrites the
models to Lean's own operations. Each model is compared with `clojure.core` on
generated inputs in `test/leanfran/core_model_test.clj`.

A theorem holds for the Clojure function where the function returns a value:
calls that throw (`Long` overflow, division by zero, an index out of range)
are outside what the models describe. The models take integers in the `Long`
range to be `Long`s, and `clojure.string` case conversion and whitespace to be
those of ASCII.

### Running Clojure from Lean

The model of a monomorphic function is `@[extern]` to the Clojure var, so
compiled Lean code that calls it runs the Clojure function. A `@[csimp]`
theorem `(= (the (-> Nat Nat) spec) impl)` makes compiled calls of `spec`, and
the Clojure function `spec` itself, run the Clojure `impl`.

### Checking a function against its model

`(lt/check #'f opts)` compares each arity of `f` with its model on inputs
generated from the signature, with test.check, and returns the result with a
`:counterexample` (the arguments and both values) when they differ. Options:
`:num-tests`, `:seed`, `:gens` (generators by parameter name), `:at` (the
types of a polymorphic function's type variables), `:max-size`, `:big-ints?`
(integers beyond `Long`), and `:throws :fail` (count a call that throws as a
failure). `(lt/defcheck name f opts)` defines a `clojure.test` test that runs
it.

## Types

`leanfran.types` derives from a Lean type, written as in signatures:

| Function                                            | Result                                                                                                     |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `gen`                                               | a test.check generator of the Clojure values of the type                                                   |
| `valid?`                                            | whether a value has the type, telling lists from vectors                                                   |
| `malli-schema`, `fn-schema`                         | a malli schema as data, and the function schema of a `lt/defn` var (`[:function ...]` for several arities) |
| `kondo-type`, `kondo-config`, `write-kondo-config!` | clj-kondo `:type-mismatch` types of `lt/defn` functions, written to `.clj-kondo/leanfran/types/config.edn` |

It knows `Nat`, `Int`, `Bool`, `String`, `Char`, `Float`, `UInt8`..`UInt64`,
`Unit`, `(Fin n)`, `List`, `Array`, `Option`, `Prod`, `(Map K V)`, `(Set α)`,
and the structures, enumerations, and sum types (as `{:tag :circle :r 1}`)
of `deflean` blocks and generated namespaces, by full Lean name or by a short
name that one of them has. `leanfran.malli/instrument!` registers the malli
function schemas of the `lt/defn` functions of namespaces and instruments them
(malli is your dependency).

## The CLI

```
leanfran module generate-namespace --module-name <Lean module> --namespace <Clojure ns>
         [--roots <Lean name> ...] [--strip-namespace <Lean namespace>]
         [--search-path <dir> ...] [--output-file <path>] [--forms-only]
         [--output json|text]

leanfran project generate --lake-dir <dir> --namespace-prefix <ns>
         --output-dir <dir> [--modules <Lean module> ...]
```

`module generate-namespace` emits one module. Without `--roots`, the CLI
exports the public definitions of the module that have a supported signature,
and reports the others on standard error. `--search-path` adds directories of
`.olean` files (in a lake package, `.lake/build/lib/lean`). `project generate`
builds a lake project, takes the search path of its dependencies from
`lake env`, and writes a namespace `<prefix>.<module>` for each module under
the project (or each of `--modules`). Exit codes: 0 success, 252 invalid
parameters, 254 input the backend cannot handle, 255 other failures.

Public functions take the Lean name relative to the module (or
`--strip-namespace`) in kebab-case: `Point.add` → `point-add`, `isEven?` →
`is-even?`. An `IO` action runs when called and returns its value, or throws
for an error; its output goes to `*out*` and `*err*`.

The backend works on Lean's compiler IR. A hand-written runtime
(`leanfran.runtime`) provides the C symbols of Lean's `@[extern]`
declarations, including `Float32`, `ByteArray`, `FloatArray`, `Thunk`, `Task`,
and the standard streams and references of `IO`. A generated namespace checks
at load time that the runtime has the symbols it uses.

## Samples

[`samples/`](../langs/Clojure/samples) holds small programs built with leanfran. Each one is a
Clojure project with its own README and a `make test`.

| Use                                                                   | Samples                                                                                                                                                                                                                                                                 |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Write functions in Lean and call them from Clojure (`deflean`)        | [`todo-cli`](../langs/Clojure/samples/todo-cli), [`word-count`](../langs/Clojure/samples/word-count)                                                                                                                                                                                |
| Compile a Lean project to a Clojure namespace (the CLI)               | [`roman-numerals`](../langs/Clojure/samples/roman-numerals)                                                                                                                                                                                                                   |
| Write functions in Clojure and verify them in Lean (`leanfran.typed`) | [`verified-clojure`](../langs/Clojure/samples/verified-clojure), [`sorted-search`](../langs/Clojure/samples/sorted-search), [`inventory`](../langs/Clojure/samples/inventory), [`generic-search`](../langs/Clojure/samples/generic-search), [`typed-schemas`](../langs/Clojure/samples/typed-schemas) |

[`samples/README.md`](../langs/Clojure/samples/README.md) describes what each sample shows and
where to start.

## Development

```
make build     # lake build
make test      # diff-test against the C backend, then the Clojure tests
make check     # format check, lint, and all tests
make format
```

`../../maint/Clojure/test-diff.sh` runs `LeanCljTest.Vectors.report` compiled by Lean's C backend
and the same function generated as Clojure, and compares the output.

Releases come from the `Release` workflow of conao3/lean-leanfran, which
releases the backends together under one version. It writes the version
with `clojure -T:build set-version :version '"X.Y.Z"'`, runs `make check`,
pushes the commit and the tag `vX.Y.Z` to `master`, and the `Publish` workflow
deploys the jar to Clojars.

## License

Apache-2.0. See [LICENSE](https://github.com/conao3/lean-leanfran/blob/master/LICENSE).
