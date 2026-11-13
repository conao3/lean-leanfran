# lean-leanfran

Write and prove functions in Lean 4, run them as Rust, Python, TypeScript and Clojure.

Each backend reads the IR of the Lean compiler and emits source code that runs on a small runtime of its target language, without Lean at run time. Each one also embeds Lean in its host language and verifies host-language functions against Lean specifications.

| Directory                    | Target     | Packages                                                                                                                              |
| ---------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| [`Rust/`](Rust/)             | Rust       | crates.io: [`leanfran`](https://crates.io/crates/leanfran), `leanfran-runtime`, `leanfran-macros`, `leanfran-build`, `cargo-leanfran` |
| [`Python/`](Python/)         | Python     | PyPI: [`leanfran`](https://pypi.org/project/leanfran/)                                                                                |
| [`TypeScript/`](TypeScript/) | TypeScript | npm: [`leanfran`](https://www.npmjs.com/package/leanfran)                                                                             |
| [`Clojure/`](Clojure/)       | Clojure    | Clojars: [`io.github.conao3/leanfran`](https://clojars.org/io.github.conao3/leanfran)                                                 |

Run `make check` at the repository root to verify all backends, or `make check BACKENDS=Python` to select one. Each backend has a pinned Nix environment and Lake project; all use Lean `v4.35.0`. See [CONTRIBUTING.md](CONTRIBUTING.md) for development, packaging and verification.

The four backends are released together under one version: the `Release` workflow writes the version into all of them (`scripts/set-version.sh`), runs their `make check`, and tags `vX.Y.Z`, and the `Publish` workflow publishes the tag to crates.io, PyPI, npm and Clojars.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
