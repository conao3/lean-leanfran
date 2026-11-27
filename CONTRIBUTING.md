# Contributing

Install GNU Make and Nix with flakes enabled. From the repository root:

```sh
make build
make check
make format
make check BACKENDS="Python TypeScript"
```

The root `flake.nix` and `flake.lock` define the development environments and the compiler package. The root Makefile selects a named environment for each backend. `BACKENDS` defaults to `Rust Python TypeScript Clojure PHP Go C`. To use backend-specific commands, run `nix develop .#python` or select the `.#rust`, `.#typescript`, `.#clojure`, `.#php`, `.#php85`, `.#go`, `.#go126`, or `.#c` shell at the root, then enter the backend directory. `nix develop` provides all toolsets.

The root `lakefile.toml` builds the compiler. `lake build leanfran` writes `.lake/build/bin/leanfran`, one executable that holds every backend, and `--lang` selects the backend. The command line of a backend is the module `Lean<X>.Cli` in `langs/<language>/Lean<X>/Cli.lean`. Each backend's Makefile builds the compiler with `lake --dir ../.. build leanfran`. `leanfran generate` (`Leanfran/Generate.lean`) reads `leanfran.toml` and runs the backends' `module generate --batch`. The Rust, Python, and Go checks use `maint/test-generate.sh` to generate and build the programs in `tests/generate/`. `nix build .#leanfran` builds the compiler package, and `.#rust` adds the Cargo CLI and Aeneas to it. `nix fmt` formats Nix, Rust, and Python across the repository. `make format` also formats TypeScript, Clojure, PHP, Go, and C. Maintenance scripts live in `maint/`, with backend-specific scripts in its language subdirectories.

## Backend development

| Backend    | Source and usage                             | Implementation guide                                     |
| ---------- | -------------------------------------------- | -------------------------------------------------------- |
| Rust       | [langs/Rust/README.md](langs/Rust/README.md)             | [Rust development](docs/rust-development.md)             |
| Python     | [langs/Python/README.md](langs/Python/README.md)         | [Python development](docs/python-development.md)         |
| TypeScript | [langs/TypeScript/README.md](langs/TypeScript/README.md) | [TypeScript development](docs/typescript-development.md) |
| Clojure    | [langs/Clojure/README.md](langs/Clojure/README.md)       | [Clojure development](docs/clojure-development.md)       |
| PHP        | [langs/PHP/README.md](langs/PHP/README.md)               | [PHP development](docs/php-development.md)                |
| Go         | [langs/Go/README.md](langs/Go/README.md)                 | [Go development](docs/go-development.md)                  |
| C          | [langs/C/README.md](langs/C/README.md)                  | [C development](docs/c-development.md)                    |

Keep native-oracle differential tests, host-language tests, and sample verification in the backend's `make check`. CI executes that command for all backends, checks PHP with PHP 8.4 and 8.5 and Go with Go 1.27 and 1.26, and builds the Python, TypeScript, Clojure, PHP, Go, and C Nix packages. CI also checks Go and C on macOS arm64. The PHP check also covers embedded models, PHP-to-Lean translation and proof states, and seeded tests against generated Lean specifications. The C check covers embedded Lean blocks, compares the C operation model and the C-to-Lean translation with compiled C under GCC and Clang, checks the obligation states and `leanfran.lock`, runs the model tests under UBSan, and runs the samples.

The Rust and PHP environments contain store paths that cache.nixos.org lacks: Aeneas with Charon, and PHPStan built for the selected PHP. `maint/ci-nix-cache.sh save` exports those paths from the realised shells, and `maint/ci-nix-cache.sh restore` imports them before the CI and Release checks enter the shells. The GitHub Actions cache keeps the export under a key derived from `flake.nix` and `flake.lock`. Paths over 500 MB, the unpacked Rust toolchain parts, are rebuilt from their downloads instead of exported. The checks themselves start from clean build outputs. The version step and the crates.io and Packagist publish jobs use only the tools they need, through `nix shell --inputs-from`, without entering the development environments.

Pull requests run the checks for affected backends, including cross-backend test inputs listed in `maint/ci-backends.sh`. Shared or unrecognized paths trigger all checks. A new commit cancels the previous CI run for that pull request. Runs on `master` and release tags still check every backend.

## Packaging

[LICENSE](LICENSE) applies to all backends. Cargo inherits its path from the Rust workspace. Hatch includes it in Python wheels and source distributions. The TypeScript `make pack` target copies it into `dist/LICENSE`, and the Clojure JAR builder includes it as `META-INF/LICENSE`. The PHP runtime declares the repository's Apache-2.0 license in its Composer manifest.

Run `make pack` in TypeScript before `npm pack` or `npm publish`, and `clojure -T:build jar` in Clojure to build its JAR. Build Python distributions with `uv build` and Rust crates with `cargo package` inside their backend environments.

PHP applications install the runtime from Packagist with `composer require conao3/leanfran`. The release snapshot places the Composer manifest, runtime, README, license, and any CLI scripts at the root of the read-only mirror `conao3/leanfran-php`. Packagist derives the package version from the mirror's Git tag.

Go applications install the module with `go get github.com/conao3/leanfran-go`. The release snapshot places the module and its license at the root of the read-only mirror `conao3/leanfran-go`. Go resolves versions from the mirror's Git tags.

C applications build the compiler and support files with `nix build .#leanfran`. See the [C guide](docs/c-guide.md) for generating an API and linking it with the Lean toolchain.

## Releases

Start the `Release` workflow once per release. It chooses the next version from the version files and the `vX.Y.Z` tags, writes it into every backend, and pushes the release commit `release vX.Y.Z` on the latest `master` together with the `vX.Y.Z` tag in one atomic push. If `master` moved while the version was written, the run reapplies the version changes onto the new `master` and pushes again. It then runs every backend's `make check` on the tagged commit and starts `Publish` from the tag once all checks pass. Pull requests may merge while a release runs. A tag whose checks fail stays on `master` without a publish, and the next `Release` takes the following version. `Publish` ends by creating a GitHub Release for the tag, so a `vX.Y.Z` tag without a GitHub Release was not published. If a check fails for a runner or network reason, rerun the failed jobs of the same `Release` run with `gh run rerun <run-id> --failed`; that checks the same tag and starts `Publish`. Concurrent `Release` runs execute one at a time. If publishing to any registry fails, rerun `Publish` with the same tag. It skips versions already published.

`Publish` distributes the `vX.Y.Z` tag to crates.io, PyPI, npm, Clojars, Packagist, and the Go module mirror. PHP and Go carry the shared release version in their compiler entry points. Go also records it in the root Go package. Generator versions track emitted-code compatibility separately from release versions. The C backend keys its sync manifest and proof lock on its generator version and the Lean version.

The PHP Publish job checks the shared tag against `LeanPhp/Cli.lean`, pushes the snapshot and the same tag to the mirror, then requests and verifies the Packagist update. For the registry and required environment secrets, see the [PHP publishing guide](docs/php-development.md#publishing).

The Go Publish job checks the shared tag against `LeanGo/Cli.lean` and `leanfran.go`, pushes the snapshot and tag to the mirror, and verifies that Go resolves the tag. See the [Go publishing guide](docs/go-development.md#publishing) for the deployment environment and local consumer check.
