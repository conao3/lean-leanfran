# lean-clj

Write and prove functions in Lean 4, run them on the JVM from Clojure.

lean-clj has two parts:

- **A Lean IR → Clojure backend.** The `lean-clj` CLI reads the compiler IR of
  a Lean module and emits a Clojure namespace. Proofs and types are erased by
  the Lean compiler, so the generated code is the same program the C backend
  compiles. A hand-written runtime (`lean-clj.runtime`) provides the C symbols
  of Lean's `@[extern]` declarations.
- **`deflean`, Lean embedded in Clojure.** Write Lean in a Clojure file; the
  macro checks it, proofs included, with `lake build` when the form is
  compiled, and defines the functions in the current namespace.

```clojure
(ns demo.core
  (:refer-clojure :exclude [double])
  (:require [lean-clj.core :refer [deflean]]))

(deflean arith
  "def double (n : Nat) : Nat := n + n

   theorem double_eq (n : Nat) : double n = 2 * n := by
     unfold double; omega

   structure Account where
     owner : String
     balance : Nat

   def deposit (a : Account) (n : Nat) : Account :=
     { a with balance := a.balance + n }")

(double 21)                                ;=> 42
(deposit {:owner "ann" :balance 10} 5)     ;=> {:owner "ann", :balance 15}
```

A block whose proof fails stops compilation with Lean's error messages, with
line numbers relative to the block.

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
(deflean <block> [{:imports ["Std.Data.HashMap"]}] "<Lean source>")
```

The block becomes the Lean module `LeanCljEmbed.<Namespace>.<Block>` (for
`demo.core` and `arith`: `LeanCljEmbed.Demo.Core.Arith`) in the lake workspace
`.lean-clj/` of the working directory. The generated code is cached in
`.lean-clj/cache/` under a hash of the namespace, block name, imports, and
source; with the cache present, expanding the block does not need Lean.

clj-kondo picks up the names a block defines through the hook exported in
`resources/clj-kondo.exports/io.github.conao3/lean-clj`.

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
