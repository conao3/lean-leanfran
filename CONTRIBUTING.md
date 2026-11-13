# Contributing

Install GNU Make and Nix with flakes enabled. From the repository root:

```sh
make build
make check
make format
make check BACKENDS="Python TypeScript"
```

The root Makefile runs each selected backend in its own pinned Nix environment. `BACKENDS` defaults to `Rust Python TypeScript Clojure`. To use backend-specific commands, enter that directory and run `nix develop`.

## Backend development

| Backend    | Source and usage                             | Implementation guide                                     |
| ---------- | -------------------------------------------- | -------------------------------------------------------- |
| Rust       | [Rust/README.md](Rust/README.md)             | [Rust development](docs/rust-development.md)             |
| Python     | [Python/README.md](Python/README.md)         | [Python development](docs/python-development.md)         |
| TypeScript | [TypeScript/README.md](TypeScript/README.md) | [TypeScript development](docs/typescript-development.md) |
| Clojure    | [Clojure/README.md](Clojure/README.md)       | [Clojure development](docs/clojure-development.md)       |

Keep native-oracle differential tests, host-language tests and sample verification in the backend's `make check`. CI executes that command for all four backends and builds the Python, TypeScript and Clojure Nix packages.

## Packaging

[LICENSE](LICENSE) applies to all four backends. Cargo inherits its path from the Rust workspace; Hatch includes it in Python wheels and source distributions; the TypeScript `make pack` target copies it into `dist/LICENSE`; the Clojure JAR builder includes it as `META-INF/LICENSE`.

Run `make pack` in TypeScript before `npm pack` or `npm publish`, and `clojure -T:build jar` in Clojure to build its JAR. Build Python distributions with `uv build` and Rust crates with `cargo package` inside their backend environments.

## Releases

The GitHub Actions Release workflow selects one next version for all backends, updates it through `scripts/set-version.sh`, verifies all backends and creates `vX.Y.Z`. Publish distributes that tag to all four registries. A retry skips versions already published. Generator versions track emitted-code compatibility separately from package versions.
