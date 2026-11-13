# Contributing

Install GNU Make and Nix with flakes enabled. From the repository root:

```sh
make build
make check
make format
make check BACKENDS="Python TypeScript"
```

The root `flake.nix` and `flake.lock` define all development environments and compiler packages. The root Makefile selects a named environment for each backend. `BACKENDS` defaults to `Rust Python TypeScript Clojure`. To use backend-specific commands, run `nix develop .#python` (or `rust`, `typescript`, `clojure`) at the root, then enter the backend directory. `nix develop` provides all toolsets.

Build compiler packages with `nix build .#python`, `.#typescript`, `.#clojure` or `.#rust`. The Rust package includes the compiler, Cargo CLI and Aeneas. `nix fmt` formats Nix, Rust and Python across the repository; `make format` also formats TypeScript and Clojure. Maintenance scripts live in `maint/`, with backend-specific scripts in its language subdirectories.

## Backend development

| Backend    | Source and usage                             | Implementation guide                                     |
| ---------- | -------------------------------------------- | -------------------------------------------------------- |
| Rust       | [langs/Rust/README.md](langs/Rust/README.md)             | [Rust development](docs/rust-development.md)             |
| Python     | [langs/Python/README.md](langs/Python/README.md)         | [Python development](docs/python-development.md)         |
| TypeScript | [langs/TypeScript/README.md](langs/TypeScript/README.md) | [TypeScript development](docs/typescript-development.md) |
| Clojure    | [langs/Clojure/README.md](langs/Clojure/README.md)       | [Clojure development](docs/clojure-development.md)       |

Keep native-oracle differential tests, host-language tests and sample verification in the backend's `make check`. CI executes that command for all backends and builds the Python, TypeScript and Clojure Nix packages.

## Packaging

[LICENSE](LICENSE) applies to all backends. Cargo inherits its path from the Rust workspace; Hatch includes it in Python wheels and source distributions; the TypeScript `make pack` target copies it into `dist/LICENSE`; the Clojure JAR builder includes it as `META-INF/LICENSE`.

Run `make pack` in TypeScript before `npm pack` or `npm publish`, and `clojure -T:build jar` in Clojure to build its JAR. Build Python distributions with `uv build` and Rust crates with `cargo package` inside their backend environments.

## Releases

The GitHub Actions Release workflow selects one next version for all backends, updates it through `maint/set-version.sh`, verifies all backends and creates `vX.Y.Z`. Publish distributes that tag to all registries. A retry skips versions already published. Generator versions track emitted-code compatibility separately from package versions.
