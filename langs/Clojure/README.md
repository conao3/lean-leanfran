# Clojure

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) for Clojure: write Lean with `deflean`, call it through Clojure values, and verify supported Clojure functions using Lean signatures and specifications.

## Install

Add the dependency to `deps.edn`:

```clojure
{:deps {io.github.conao3/leanfran {:mvn/version "0.6.0"}}}
```

Install the compiler:

```sh
nix profile install 'github:conao3/lean-leanfran#clojure'
```

The first expansion of a `deflean` block requires Lean 4.35.0 (`lean` and `lake`) and the compiler on `PATH`. Clojure 1.12 and JDK 21 or later are required. Generated namespaces and cached blocks run without Lean.

## First Lean block

```clojure
(ns demo.core
  (:refer-clojure :exclude [double])
  (:require [leanfran.core :refer [deflean]]))

(deflean arith
  (def double [n Nat] Nat
    (+ n n))

  (theorem double_eq [n Nat] (= (double n) (* 2 n))
    (by (unfold double) omega)))

(double 21) ;=> 42
```

`deflean` checks the block with Lean at macro expansion and caches the generated namespace in `.leanfran/cache/`. A failed proof stops compilation. You can also write blocks as Lean source strings.

## Next steps

- [Full Clojure guide](https://github.com/conao3/lean-leanfran/blob/master/docs/clojure-guide.md): value conversions, Lean blocks, typed functions, malli, clj-kondo, verification and CLI.
- [Samples](https://github.com/conao3/lean-leanfran/blob/master/langs/Clojure/samples/README.md), including typed schemas and step-by-step examples.
- [Development](https://github.com/conao3/lean-leanfran/blob/master/CONTRIBUTING.md) and [implementation notes](https://github.com/conao3/lean-leanfran/blob/master/docs/clojure-development.md).
