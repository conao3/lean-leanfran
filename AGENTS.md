# Development

This repository contains Lean 4 compiler backends released together as leanfran.

## Repository layout

- The backends in `langs/` each have a Lake project. Rust, Python, TypeScript, Clojure, PHP, and Go provide emitters, host runtimes, language packages, tests, and samples. `langs/C/` uses Lean's C emitter and runtime and provides C API generation, link configuration, and tests.
- `docs/`: development documentation. Read `CONTRIBUTING.md` and the relevant backend guide before editing a backend.
- `maint/`: repository maintenance, version management, differential tests and extern-list generators.
- `.github/`: CI and release automation.
- `flake.nix`, `flake.lock`, `lean-toolchain`: shared development dependencies, compiler packages and Lean version.
- `LICENSE`: the Apache-2.0 text for the entire repository. Package builds include this file in their artifacts.

## Shared conventions

- The root `lean-toolchain` selects Lean for all backends.
- Runtime externs follow Lean's C symbols, argument order, erased arguments and ownership conventions. Inspect the toolchain's Lean sources and `lean.h` when implementing an extern.
- Add runtime behavior to the backend's native-oracle differential tests; compare the generated program with Lean's C backend.
- Regenerate runtime extern lists with the backend's `make gen-externs` where available.
- When generated code changes, update both the emitter's generator version and its host-side freshness version together. The C backend has one `generatorVersion`, which keys `leanfran.manifest.json` and `leanfran.lock`; raise it when the generated C, the C translation, or the obligations change.
- Keep shared development rules here and backend implementation details in `docs/`.

## Verification and releases

For PHP models, maintain proof and translation fixtures alongside the native-oracle comparisons. Run property tests against the generated specs in the shared verification fixture. `make check BACKENDS=PHP` runs the PHP checks under PHP 8.4 and 8.5. `make check BACKENDS=Go` runs the Go checks under Go 1.27 and 1.26, including a local mirror publish and consumer install.

`make check BACKENDS=C` tests the C API, initialization, ownership, and static and shared linking. Its `check-model`, `check-translate`, `check-verify`, `check-random`, and `check-samples` targets compare the C operation model and the translation with compiled C, check the obligation states and the lock, run the model tests, and run the samples.

Run `make check` from the repository root, or `make check BACKENDS=Python` for selected backends. Run `make format` before committing.

Start the `Release` workflow once per release. It writes the shared version, pushes the release commit and the `vX.Y.Z` tag to `master` in one atomic push, checks every backend on the tag, and starts `Publish` when the checks pass. A tag whose checks fail stays unpublished, and the next `Release` takes the following version; `Publish` creates a GitHub Release only for published tags. Rerun a check that failed for a transient reason with `gh run rerun <run-id> --failed`. Concurrent `Release` runs execute one at a time. If publishing to any registry fails, rerun `Publish` with the same tag. It skips versions already published or verifies that the Go mirror tag matches the release snapshot. The Go job also verifies that Go resolves the tagged module.
