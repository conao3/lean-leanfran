# PHP development

leanfran compiles Lean 4 IR into PHP classes with a Composer runtime. See the [backend README](../langs/PHP/README.md) for the quick start. Paths in Layout and Conventions are relative to `langs/PHP/`.

## Layout

- `Main.lean` implements the `leanfran-php` CLI. `LeanPhp/EmitPhp.lean` collects the IR reachable from the roots, emits PHP, and assembles initializers and entry points.
- `src/Runtime/` contains Lean's C ABI functions as namespaced PHP functions. The `autoload.files` list in `composer.json` loads them. `phpstan.neon` defines the runtime value type shared by container, scalar, and closure code.
- `LeanPhp/RuntimeExterns.lean` is the generated inventory of runtime symbols. The compiler checks the symbols a job needs before emitting PHP.
- `LeanPhpTest/Vectors.lean` and `Io.lean` contain differential fixtures. The corresponding Lake executables run the native C oracles. `LeanPhpTest/Control*.lean` covers IR constructors, call depth, and complexity. `tests/Differential/` holds PHP drivers, `tests/Runtime/` holds PHPUnit tests, and `test-out/` holds generated test artifacts.
- `make/control.mk` and `make/io.mk` register additional checks. `../../maint/PHP/` holds the oracle, fuzz, and extern scripts. `samples/` has a library example and a generated CLI.

## Conventions

- The root `lean-toolchain` selects Lean for the compiler and the C oracle. Use the Lean sources and `lean.h` to check the C symbol, argument order, erased parameters, and ownership when implementing an extern. Increment a retained value read out of a container, and leave borrowed arguments owned by the caller.
- Add new runtime behavior to `LeanPhpTest/Vectors.lean` or `Io.lean`. Register a new IO case in `../../maint/PHP/test-io.sh` with its expected exit status. The differential check compares stdout, stderr, and status with the C oracle. The IO check also compares the resulting files.
- After adding an extern, add any new runtime file to Composer's `autoload.files`, run `make gen-externs` in the PHP shell, and commit the generated `LeanPhp/RuntimeExterns.lean` with the runtime change. `make externs-check` regenerates the list for comparison.
- When emitted code changes, raise `generatorVersion` in `Main.lean` and regenerate the checked-in classes under `samples/`. Their generator headers are the PHP-side freshness stamps. `make test` regenerates `test-out/samples/LeanSumTo.php` and compares it with `samples/sum-to/src/_lean/LeanSumTo.php`. Review the generated file before copying it into the sample.
- Use `declare(strict_types=1);` in handwritten PHP. Mago formats the runtime, tests, and maintenance scripts. PHPStan checks all of `src/` at level max.

## Verification

From the repository root, run both PHP versions with the root Makefile.

```sh
nix shell nixpkgs#gnumake -c make check BACKENDS=PHP
nix shell nixpkgs#gnumake -c make format-check BACKENDS=PHP
nix build .#php
```

The check runs differential, numeric, depth, complexity, IR coverage, and fuzz tests, plus PHPUnit, PHPStan, the extern inventory comparison, and the samples. The named shells `.#php` and `.#php85` provide PHP 8.4 and 8.5 with matching Composer, PHPStan, and PHPUnit. Select the shell when running a backend target directly.

```sh
nix develop .#php -c make -C langs/PHP gen-externs
nix develop .#php85 -c make -C langs/PHP test
```

## Publishing

The PHP Publish job snapshots the tagged checkout into the root of the read-only mirror `conao3/leanfran-php`, updates its `main` branch and applies the same `vX.Y.Z` tag. Packagist reads the mirror's Composer manifest and tags for `conao3/leanfran`. For the first release, set `PHP_MIRROR_DEPLOY_KEY` in the `packagist` environment so Publish can push the first snapshot. Once the mirror has the snapshot, register `https://github.com/conao3/leanfran-php` on Packagist and set `PACKAGIST_USERNAME` and `PACKAGIST_API_TOKEN` in the same environment. If the initial run stopped at the registry step, rerun Publish with the same tag. To exercise the snapshot, tag retries, and Composer installation with a local bare mirror, run `nix develop .#php -c make -C langs/PHP test-publish`.
