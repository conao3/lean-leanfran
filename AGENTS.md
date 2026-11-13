# Development

This repository contains Lean 4 compiler backends released together as leanfran.

## Repository layout

- `langs/Rust/`, `langs/Python/`, `langs/TypeScript/`, `langs/Clojure/`: emitters, host runtimes, language packages, tests and samples. Each has a Lake project.
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
- When generated code changes, update both the emitter's generator version and its host-side freshness version together.
- Keep shared development rules here and backend implementation details in `docs/`.

## Verification and releases

Run `make check` from the repository root, or `make check BACKENDS=Python` for selected backends. Run `make format` before committing.

The Release and Publish workflows manage the package versions and the `vX.Y.Z` tag together. Start them only in the session where the user requested a release.
