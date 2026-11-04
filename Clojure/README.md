# lean-clj

Write and prove functions in Lean 4, run them on the JVM from Clojure.

lean-clj has two parts:

- **A Lean IR → Clojure backend.** The `lean-clj` CLI reads the compiler IR of
  a Lean module and emits a Clojure namespace. Proofs and types are erased by
  the Lean compiler, so the generated code is the same program the C backend
  compiles. A hand-written runtime (`lean-clj.runtime`) provides the C symbols
  of Lean's `@[extern]` declarations.
- **`deflean`, Lean embedded in Clojure.** Write Lean in a Clojure file as
  S-expressions (or as Lean source in a string); the macro checks it, proofs
  included, with `lake build` when the form is compiled, and defines the
  functions in the current namespace.

```clojure
(ns demo.core
  (:refer-clojure :exclude [double])
  (:require [lean-clj.core :refer [deflean]]))

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

A block whose proof fails stops compilation with Lean's error messages and the
Lean source of the block.

## Requirements

- Lean 4.35.0 (`lean`, `lake`) and the `lean-clj` CLI on `PATH` when a
  `deflean` block is expanded for the first time.
- Clojure 1.12 on JDK 21 or later.

`nix develop` provides all of them except the CLI, which `make build` puts in
`.lake/build/bin`. `nix run github:conao3/lean-clj` runs the CLI directly.

## The CLI

```
lean-clj module generate-namespace --module-name <Lean module> --namespace <Clojure ns>
         [--roots <Lean name> ...] [--strip-namespace <Lean namespace>]
         [--search-path <dir> ...] [--output-file <path>] [--forms-only]
         [--output json|text]
```

Without `--roots`, every public definition of the module that has a supported
signature is exported. `--search-path` adds directories of `.olean` files (in a
lake package, `.lake/build/lib/lean`). Exit codes: 0 success, 252 invalid
parameters, 254 input the backend cannot handle, 255 other failures.

Public functions are named after the Lean name relative to the module (or
`--strip-namespace`), in kebab-case: `Point.add` → `point-add`, `isEven?` →
`is-even?`.

## Values

Public functions convert arguments and results between Clojure and Lean values
according to the Lean signature:

| Lean | Clojure |
|---|---|
| `Nat`, `Int`, `UInt8`..`UInt64`, `Float` | numbers (`BigInt` beyond `Long`) |
| `Bool` | `true` / `false` |
| `Char` | `Character` |
| `String` | string |
| `List α` / `Array α` | list / vector |
| `Option α` | the value or `nil` |
| `α × β` | two-element vector |
| structures | maps with keyword keys |
| enumerations | keywords (`Suit.hearts` → `:hearts`) |

Other types are passed through in the runtime representation (`Ctor` objects,
`Closure` objects that also implement `IFn`).

Inside generated code, `Nat` and `Int` are `Long`/`BigInt`, fixed-width
integers and `Bool` are `Long`, `UInt64` holds the 64-bit pattern in a `Long`,
`String` positions are UTF-8 byte offsets as in Lean, and `Array` is a
persistent vector.

## `deflean`

```clojure
(deflean <block> [{:imports ["Std.Data.HashMap"]}] <command> ...)
```

Each command is an S-expression of `lean-clj.dsl` or a string of Lean source;
`lean-clj.dsl/render` shows the Lean source of a sequence of commands.

| S-expression | Lean |
|---|---|
| `(def f [x T y U] R body)` | `def f (x : T) (y : U) : R := body` |
| `(theorem t [x T] P proof)` | `theorem t (x : T) : P := proof` |
| `(structure S [f T g U] (deriving Repr))` | `structure S where f : T ...` |
| `(inductive I a (b [x T]))` | `inductive I where \| a \| b (x : T)` |
| `(instance C body)`, `(mutual ...)`, `(namespace N ...)`, `(open N)` | the same commands |
| `(f a b)`, `(+ a b c)`, `(- a)`, `(not p)` | `(f a b)`, `(a + b + c)`, `(-a)`, `(¬p)` |
| `(if c t e)`, `(let [x v] e)`, `(fn [x] e)` | `if`, `let`, `fun` |
| `(match x p1 e1 p2 e2)`, `(match [x y] [p q] e)` | `match x with \| p1 => e1 ...` |
| `(.field x)`, `(.method x a)` | `x.field`, `(x.method a)` |
| `{:x 1}`, `(with s {:x 1})`, `(<> a b)` | `{ x := 1 }`, `{ s with x := 1 }`, `⟨a, b⟩` |
| `[a b]`, `(array a b)` | `[a, b]`, `#[a, b]` |
| `(the T e)`, `(-> A B)`, `(forall [x T] P)`, `(exists [x T] P)` | `(e : T)`, `A → B`, `∀`, `∃` |
| `(by (simp [a b]) omega)` | `(by simp [a, b]; omega)` |
| `(lean "...")` | Lean source as is |

Symbols with a `-` become lowerCamelCase in Lean (`is-prime` → `isPrime`), and
the public Clojure name converts back (`is-prime`); `_` is kept, so Lean lemma
names are written as they are (`Nat.add_comm`). Binder vectors take
`(implicit α Type)` and `(inst (BEq α))`; metadata on a name adds modifiers
(`^:partial`, `^:private`, `^{:attrs [simp]}`). Binary operators: `+ - * / %
pow ++ = == != not= < <= > >= and or iff && || band bor land lor xor <<< >>>
in not-in cons |> <| >>= <$> comp`. Inside `by`, a tactic name's `-` becomes `_`
(`all-goals` → `all_goals`); `(on-all t1 t2)` is `t1 <;> t2` and
`(case tag [x] t ...)` is `case tag x => ...`.

The block becomes the Lean module `LeanCljEmbed.<Namespace>.<Block>` (for
`demo.core` and `arith`: `LeanCljEmbed.Demo.Core.Arith`) in the lake workspace
`.lean-clj/` of the working directory. The generated code is cached in
`.lean-clj/cache/` under a hash of the namespace, block name, imports, and
Lean source; with the cache present, expanding the block does not need Lean.

clj-kondo picks up the names a block defines through the hook exported in
`resources/clj-kondo.exports/io.github.conao3/lean-clj`.

## Samples

[`samples/`](samples) holds programs built with lean-clj, starting with
[`todo-cli`](samples/todo-cli), a command-line todo list whose operations are
Lean definitions with proofs.

## Development

```
make build     # lake build
make test      # diff-test against the C backend, then the Clojure tests
make check     # format check, lint, and all tests
make format
```

`./test-diff.sh` runs `LeanCljTest.Vectors.report` compiled by Lean's C backend
and the same function generated as Clojure, and compares the output.

## License

Apache-2.0
