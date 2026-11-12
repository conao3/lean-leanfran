# AGENTS.md

lean-py compiles Lean 4 IR to Python (`LeanPython/`, `Main.lean`), exposes Lean types as pydantic
models, and embeds Lean in Python (`src/lean_python/embed.py`, `sync.py`). See README.md for usage.

## Layout

- `LeanPython/EmitPy.lean`: the emitter. Collects IR decls from roots and emits Python functions
  (join points as a `while True` state machine, reference counting as in C).
- `LeanPython/Marshal.lean`: Lean types → descriptors, pydantic models, decision procedures of
  proof fields. `LeanPython/Generate.lean`: public functions. `Main.lean`: the `lean-python` CLI.
- `src/lean_python/runtime.py`, `io_externs.py`: runtime. `lean_*` functions are named after the C
  symbols of Lean externs; `LeanPython/RuntimeExterns.lean` lists them (`make gen-externs`), and the
  CLI refuses to emit code calling a symbol not in the list.
- `src/lean_python/marshal.py`: conversion between Python and runtime values, `LeanModel`,
  `LeanInductive` (Lean's JSON encoding), `adopt` for the user's models.
- `src/lean_python/embed.py`, `sync.py`, `models.py`, `cli.py`: `lean(...)` and `lean-py sync`.
- `LeanPythonTest/`: Lean test programs. `Vectors.lean` and `Io.lean` hold the diff-test cases;
  `*Main.lean` are the native oracles. `Public.lean`, `Json.lean`: the public API and JSON tests.
- `tests/`: pytest. `test-out/` holds generated code (ignored by git).

## Conventions

- The toolchain in `lean-toolchain` matches nixpkgs-unstable's `lean4`.
- When the CLI reports externs not in the runtime, find the extern in the Lean sources
  (`grep -rn 'extern "<symbol>"'` under the toolchain's `src/lean`), implement it following `lean.h`
  (same argument order, erased arguments dropped; never consume a borrowed argument; `inc` values
  read out of containers), and run `make gen-externs`.
- New runtime behaviour gets a case in `LeanPythonTest/Vectors.lean` or `Io.lean`; the diff test
  must match the C backend byte for byte. New public types get a test in `tests/test_public.py`, and
  a JSON case in `LeanPythonTest/Json.lean` when they derive `ToJson`.
- Raise `generatorVersion` in `Main.lean` and `GENERATOR_VERSION` in `src/lean_python/embed.py`
  together when the generated code changes.

## Verification

```
nix develop --command make check
```
