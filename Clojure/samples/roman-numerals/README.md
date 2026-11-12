# roman-numerals

Use Lean code from an ordinary lake project in Clojure, without `deflean`.

[`lean/Roman.lean`](lean/Roman.lean) converts between numbers and Roman
numerals and proves that the conversion round-trips for every number below
1000:

```lean
def toRoman (n : Nat) : String := toRomanAux (n + 13) numerals n

def fromRoman (s : String) : Option Nat := ...

theorem roundtrip : ∀ n, n < 1000 → fromRoman (toRoman n) = if n = 0 then none else some n := by
  decide +kernel
```

The `lean-clj` CLI turns the module into the Clojure namespace
[`src/roman/core.clj`](src/roman/core.clj), which is committed. Clojure code
requires it like any namespace, and running it needs only the JVM — no Lean:

```clojure
(require '[roman.core :as roman])

(roman/to-roman 1994)        ;=> "MCMXCIV"
(roman/from-roman "MMXXVI")  ;=> 2026
(roman/from-roman "hello")   ;=> nil
```

The public functions are the module's non-private definitions, named in
kebab-case (`toRoman` → `to-roman`); `Option Nat` comes back as the number or
`nil`.

## Regenerating

After changing the Lean code, run inside `nix develop` of the repository root:

```
make generate
```

It checks the proofs with `lake build`, then runs

```
lean-clj module generate-namespace --module-name Roman --namespace roman.core \
  --search-path lean/.lake/build/lib/lean --output-file src/roman/core.clj
```

`make test` regenerates, fails if the committed namespace is out of date, and
compares a few calls with `expected.txt`.
