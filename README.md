# lean-leanfran

Write and prove functions in Lean 4, run them as Rust, Python, TypeScript and Clojure.

Each backend reads the IR of the Lean compiler and emits source code that runs on a small runtime of its target language, without Lean at run time. Each one also embeds Lean in its host language and verifies host-language functions against Lean specifications.

| Directory | Target | Packages |
|---|---|---|
| [`Rust/`](Rust/) | Rust | crates.io: [`lean-rust`](https://crates.io/crates/lean-rust), `lean-rust-runtime`, `lean-rust-macros`, `lean-rust-build`, `cargo-lean-rust` |
| [`Python/`](Python/) | Python | PyPI: [`lean-python`](https://pypi.org/project/lean-python/) |
| [`TypeScript/`](TypeScript/) | TypeScript | npm: [`lean-ts`](https://www.npmjs.com/package/lean-ts) |
| [`Clojure/`](Clojure/) | Clojure | Clojars: [`io.github.conao3/lean-clj`](https://clojars.org/io.github.conao3/lean-clj) |

Every directory is a self-contained project with its own `flake.nix`, `lakefile.toml` and README. Run `nix develop -c make check` inside a directory to build and test that backend. All of them use Lean `v4.35.0`.

Releases are tagged per backend: `rust-vX.Y.Z`, `python-vX.Y.Z`, `typescript-vX.Y.Z` and `clojure-vX.Y.Z`.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
