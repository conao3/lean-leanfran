# AGENTS.md

lean-clj compiles Lean 4 IR to Clojure (`LeanClj/`, `Main.lean`) and embeds Lean
in Clojure (`src/lean_clj/core.clj`). See README.md for usage.

## Layout

- `LeanClj/EmitClj.lean`: the emitter. Collects IR decls from roots, emits
  Clojure forms, and derives the marshalling descriptors of public functions.
- `LeanClj/Sx.lean`: S-expression tree and layout.
- `Main.lean`: the `lean-clj` CLI.
- `src/lean_clj/runtime.clj`: runtime. `lean_*` functions are named after the C
  symbols of Lean externs; generated code checks at load time that every
  symbol it uses exists (`check-symbols!`).
- `src/lean_clj/core.clj`: `deflean`.
- `src/lean_clj/dsl.clj`: S-expressions → Lean source for `deflean`.
- `LeanCljTest/`: Lean test programs. `Vectors.lean` holds the diff-test
  cases; `OracleMain.lean` is the native oracle.
- `test/`: Clojure tests. `test-out/` holds generated code (ignored by git).

## Conventions

- The toolchain in `lean-toolchain` matches nixpkgs-unstable's `lean4`.
- When a generated namespace reports missing runtime symbols, find the extern
  in the Lean sources (`grep -rn 'extern "<symbol>"'` under the toolchain's
  `src/lean`) and implement it with the same argument order, dropping erased
  arguments.
- New behaviour gets a case in `LeanCljTest/Vectors.lean`; the diff-test must
  match the C backend byte for byte.

## Verification

```
nix develop --command make check
```
