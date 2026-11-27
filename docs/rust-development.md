# Rust development

Paths in this guide are relative to `langs/Rust/`.

- `LeanRust/` and `LeanRust/Cli.lean`: Lean IR emitter and compiler CLI.
- `crates/leanfran-runtime/`: runtime and C-symbol externs.
- `crates/leanfran-build/`: embedding, generation and verification.
- `crates/leanfran-macros/`: host-language macros.
- `crates/leanfran/`: public API.
- `crates/cargo-leanfran/`: Cargo CLI.
- `tests/`, `LeanRustTest/`, `samples/`: host tests, native oracles and examples.

Build the shared compiler with `lake --dir ../.. build leanfran` and run `../../.lake/build/bin/leanfran --lang rust help`. Install it on your PATH with `nix profile install 'github:conao3/lean-leanfran#leanfran'`.

Run `nix develop ../..#rust -c make check`. Verification through Aeneas has its own `make check-verify` target. `make gen-externs` regenerates the extern table. See the [backend README](../langs/Rust/README.md) for supported features and examples.
