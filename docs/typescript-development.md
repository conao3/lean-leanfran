# TypeScript development

Paths in this guide are relative to `langs/TypeScript/`.

- `LeanTs/`, `Main.lean`: emitter, public-type generation and compiler CLI.
- `src/runtime/`: runtime and externs; `make gen-externs` updates `LeanTs/RuntimeExterns.lean`.
- `src/embed.ts`, `sync.ts`, `cli.ts`: embedding and CLI.
- `src/schema/`, `models.ts`: schemas and host-model integration.
- `src/verify/`, `src/lean/`: verification and Lean-side host models.
- `LeanTsTest/`, `test/`, `samples/`: native oracles, host tests and examples.

Update `Main.lean`'s `generatorVersion` and `src/embed.ts`'s `GENERATOR_VERSION` together when changing generated code.

Run `nix develop ../..#typescript -c make check` for formatting, extern validation, differential tests, fuzzing, generated-code type checking, embedding freshness, verification and samples. Run `make pack` to build the npm distribution. Format Markdown with `vp fmt` inside the development environment. See the [backend README](../langs/TypeScript/README.md) for usage.
