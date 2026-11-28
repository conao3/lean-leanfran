# TypeScript development

Paths in this guide are relative to `langs/TypeScript/`.

- `LeanTs/`, `LeanTs/Cli.lean`: emitter, public-type generation and compiler CLI (`leanfran --lang typescript`).
- `LeanTs/Embed.lean`: the TypeScript `Backend` that `Leanfran/Embed/` runs for `sync`, `check` and `status` (the launch of `node_modules/leanfran/dist/cli.js`, the workspace's `lakefile.toml` and `LeanTsLib`, the `LeanTsCsimp` modules built from `leanfran.lock`).
- `src/runtime/`: runtime and externs; `make gen-externs` updates `LeanTs/RuntimeExterns.lean`.
- `src/index.ts`, `embed.ts`, `key.ts`: `lean(...)`, the block keys and `LEANFRAN_TS_AUTO_SYNC`.
- `src/scan.ts`, `project.ts`, `cli.ts`: the commands `scan` and `translate` of `dist/cli.js`, which the compiler runs and which print JSON.
- `src/schema/`, `models.ts`: schemas and host-model integration.
- `src/verify/`, `src/lean/`: verification (the `model(...)` functions of `scan` and the `translate` command in `check.ts`) and Lean-side host models.
- `LeanTsTest/`, `test/`, `samples/`: native oracles, host tests and examples.

Update `LeanTs/Cli.lean`'s `generatorVersion` and `src/embed.ts`'s `GENERATOR_VERSION` together when changing generated code.

Build the compiler with `lake --dir ../.. build leanfran` and invoke it with `../../.lake/build/bin/leanfran --lang typescript`.

Run `nix develop ../..#typescript -c make check` for formatting, extern validation, differential tests, fuzzing, generated-code type checking, embedding freshness, verification and samples. Run `make pack` to build the npm distribution. Format Markdown with `vp fmt` inside the development environment. See the [backend README](../langs/TypeScript/README.md) for usage.
