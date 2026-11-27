<p align="center">
  <img src="docs/assets/banner.svg" alt="leanfran — prove in Lean, run in your language" width="100%">
</p>

<p align="center"><strong>Write it in Lean. Prove it in Lean. Run it in your language.</strong></p>

<p align="center">
  <a href="https://github.com/conao3/lean-leanfran/tags"><img src="https://img.shields.io/github/v/tag/conao3/lean-leanfran?sort=semver&amp;label=release" alt="Latest release"></a>
  <a href="https://github.com/conao3/lean-leanfran/actions/workflows/ci.yml"><img src="https://github.com/conao3/lean-leanfran/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue.svg" alt="License: Apache-2.0"></a>
  <a href="lean-toolchain"><img src="https://img.shields.io/badge/Lean-v4.35.0-0f4c81.svg" alt="Lean v4.35.0"></a>
  <a href="https://github.com/conao3/lean-leanfran/stargazers"><img src="https://img.shields.io/github/stars/conao3/lean-leanfran?style=flat" alt="GitHub stars"></a>
</p>

<p align="center">
  <a href="https://crates.io/crates/leanfran"><img src="https://img.shields.io/crates/v/leanfran?label=Rust" alt="Rust on crates.io"></a>
  <a href="https://pypi.org/project/leanfran/"><img src="https://img.shields.io/pypi/v/leanfran?label=Python" alt="Python on PyPI"></a>
  <a href="https://www.npmjs.com/package/leanfran"><img src="https://img.shields.io/npm/v/leanfran?label=TypeScript" alt="TypeScript on npm"></a>
  <a href="https://clojars.org/io.github.conao3/leanfran"><img src="https://img.shields.io/clojars/v/io.github.conao3/leanfran.svg?label=Clojure" alt="Clojure on Clojars"></a>
  <a href="https://packagist.org/packages/conao3/leanfran"><img src="https://img.shields.io/packagist/v/conao3/leanfran?label=PHP" alt="PHP on Packagist"></a>
  <a href="https://pkg.go.dev/github.com/conao3/leanfran-go"><img src="https://pkg.go.dev/badge/github.com/conao3/leanfran-go.svg" alt="Go on pkg.go.dev"></a>
  <a href="langs/C/README.md"><img src="https://img.shields.io/github/v/tag/conao3/lean-leanfran?sort=semver&amp;label=C" alt="C from Git tags"></a>
</p>

<p align="center">
  <a href="#quick-look">Quick look</a> |
  <a href="#get-started">Get started</a> |
  <a href="#lean-at-the-core">Languages</a> |
  <a href="#what-you-can-build">Features</a> |
  <a href="#documentation">Documentation &amp; examples</a> |
  <a href="#contribution">Contribution</a>
</p>

# leanfran

leanfran brings Lean 4 to Rust, Python, TypeScript, Clojure, PHP, Go, and C. Write functions and proofs together, compile them to your application's language, and call them through native types. The generated code runs with a small host-language runtime, or with Lean's runtime library for C; Lean is needed to check and generate code, not to run the result.

## Quick look

Install the compiler `leanfran` and Lean 4.35.0, and start a project:

```console
$ nix profile install 'github:conao3/lean-leanfran#leanfran'
$ elan default leanprover/lean4:v4.35.0
$ uv init --lib myapp && cd myapp
$ uv add leanfran
```

Put a Lean function and its proof in a Python file:

```python
# src/myapp/arith.py
from leanfran import lean

arith = lean("arith", r"""
def double (n : Nat) : Nat := n + n

theorem double_eq (n : Nat) : double n = 2 * n := by
  unfold double; omega
""")
```

Generate the module and call it as Python:

```console
$ uv run leanfran --lang python sync --package src/myapp
leanfran: 1 blocks of myapp checked and generated
$ uv run python -c 'from myapp.arith import arith; print(arith.double(21))'
42
```

Change the theorem to `double n = 3 * n` and generation stops at the proof:

```console
$ uv run leanfran --lang python sync --package src/myapp
leanfran: /tmp/myapp/src/myapp/arith.py:7: error: (lean block arith, Lean 5:17) omega could not prove the goal:
a possible counterexample may satisfy the constraints
  a ≥ 1
where
 a := ↑n
leanfran: lake build failed
```

Every supported language embeds Lean the same way (see the table below). The output above is from leanfran 0.7.0 (PyPI and the Nix compiler) in `/tmp/myapp`.

## Lean at the core

leanfran compiles Lean's compiler IR into source code for the selected language. For C, it uses Lean's C emitter and adds headers, conversion code and link settings. You can generate code from a Lean project or embed Lean blocks directly in host-language source files. Proofs are checked by Lean during generation and erased from the executable code.

| Language   | Start here                                     | Package                                                                               | Integration                                    |
| ---------- | ---------------------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Rust       | [Rust quick start](langs/Rust/README.md)             | [leanfran on crates.io](https://crates.io/crates/leanfran)                            | `lean!`, Rust types, Cargo build integration   |
| Python     | [Python quick start](langs/Python/README.md)         | [leanfran on PyPI](https://pypi.org/project/leanfran/)                                | `lean(...)`, pydantic models, Python modules   |
| TypeScript | [TypeScript quick start](langs/TypeScript/README.md) | [leanfran on npm](https://www.npmjs.com/package/leanfran)                             | `lean(...)`, TypeScript types, Standard Schema |
| Clojure    | [Clojure quick start](langs/Clojure/README.md)       | [io.github.conao3/leanfran on Clojars](https://clojars.org/io.github.conao3/leanfran) | `deflean`, Clojure values, JVM namespaces      |
| PHP        | [PHP quick start](langs/PHP/README.md)               | [conao3/leanfran on Packagist](https://packagist.org/packages/conao3/leanfran) | `#[Lean]`, `#[Model]`, Composer CLI |
| Go         | [Go quick start](langs/Go/README.md)                 | [leanfran-go on pkg.go.dev](https://pkg.go.dev/github.com/conao3/leanfran-go) | `go get github.com/conao3/leanfran-go`, embedded Lean, Go module tool |
| C          | [C quick start](langs/C/README.md)                   | [Git tags](https://github.com/conao3/lean-leanfran/tags), Nix flake output `#leanfran` | `leanfran:lean` comments, C headers, pkg-config, Make and CMake |

## What you can build

- **Proved Lean functions in your application.** Keep an algorithm and its correctness proof together in Lean, then call the function generated from it.
- **Validated data at the boundary.** Lean structures and inductive types map to host-language values. Supported proof fields become runtime checks for the invariants your proofs assume.
- **Specifications for host-language code.** Bind supported Rust, Python, TypeScript, Clojure, PHP, Go, or C functions to Lean specifications, translate them to Lean, and check proof obligations. Each language guide describes its supported subset and verification tools.

The backends share Lean's semantics and are tested against Lean's native C backend. Their supported types, externs and host-language integrations are documented in the [language guides](#documentation).

Proofs are theorems about Lean definitions. The code that runs is generated from those definitions, and tests cover the step from proof to running code: each backend's emitter and runtime (for C, Lean's own C emitter and runtime and leanfran's conversion code) is tested against Lean's native C backend. A proof about a host-language function is a theorem about its translation to Lean, so the translator is outside the proof. The [C proof scope](docs/c-guide.md#c-subset-and-proof-scope) and the [Go proof scope](docs/go-guide.md#go-subset-and-proof-scope) list what their proofs trust.

## Get started

Choose a language above and install its host package and the compiler. Lean 4.35.0 is required for generation and proof checking. One executable, `leanfran`, compiles to every language; `--lang` selects the language. With Nix, install it from this repository:

```sh
nix profile install 'github:conao3/lean-leanfran#leanfran'
leanfran --lang python module generate --module-name MyModule --search-path .lake/build/lib/lean --output-file my_module.py
```

`--lang` takes `rust`, `python`, `typescript`, `clojure`, `php`, `go` or `c`. The package also holds the Lean library of the Go backend and the C support files. The `#rust` package adds the Cargo CLI and the Aeneas verification tools to the compiler. Without Nix, build the compiler from a checkout of a release tag with `lake build leanfran`.

To compile the modules of a Lake package to several languages, list them in `leanfran.toml` and run `leanfran generate`. It binds the types the generated modules share. See the [generate guide](docs/generate-guide.md).

Follow the [Go quick start](langs/Go/README.md) to add the Go module and tool to your application, and the [C quick start](langs/C/README.md) to generate and link a C library. Follow the other language quick starts for their dependencies, project setup, and generation commands.

## Documentation

| Language   | Quick start                                   | Full guide                                                | Examples                                           |
| ---------- | --------------------------------------------- | --------------------------------------------------------- | -------------------------------------------------- |
| Rust       | [Setup and first block](langs/Rust/README.md)       | [Types, verification and CLI](docs/rust-guide.md)         | [Rust samples](langs/Rust/samples/README.md)             |
| Python     | [Setup and first block](langs/Python/README.md)     | [Models, verification and CLI](docs/python-guide.md)      | [Python samples](langs/Python/samples/README.md)         |
| TypeScript | [Setup and first block](langs/TypeScript/README.md) | [Schemas, verification and CLI](docs/typescript-guide.md) | [TypeScript samples](langs/TypeScript/samples/README.md) |
| Clojure    | [Setup and first block](langs/Clojure/README.md)    | [Types, verification and CLI](docs/clojure-guide.md)      | [Clojure samples](langs/Clojure/samples/README.md)       |
| PHP        | [Setup and first block](langs/PHP/README.md)       | [Embedding, types, verification and CLI](docs/php-guide.md)     | [PHP samples](langs/PHP/samples/README.md)               |
| Go         | [Setup and first block](langs/Go/README.md)         | [Embedding, types, verification and CLI](docs/go-guide.md) | [Go samples](langs/Go/samples/) |
| C          | [Setup and generation](langs/C/README.md)           | [Embedding, types, verification and linking](docs/c-guide.md) | [C samples](langs/C/samples/) |

## Contribution

New language support is welcome! Use the latest [Claude Opus](https://www.anthropic.com/claude/opus),
[OpenAI Sol](https://developers.openai.com/api/docs/models), or a model with a comparable
score on the [Artificial Analysis Intelligence Index](https://artificialanalysis.ai/models#intelligence),
and ask your coding agent to follow [this guide](docs/add-language.md):

```text
Read docs/add-language.md and add support for <LANGUAGE> to leanfran.
```

### Development

The repository has a shared Nix environment and Lean toolchain, with language-specific source and packages under `langs/`. Use `.#php` and `.#php85` for PHP 8.4 and 8.5, and `.#go` and `.#go126` for Go 1.27 and 1.26.

```sh
nix develop
make check
make check BACKENDS=Python
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for build targets, formatting, packaging and the coordinated release process. Implementation notes live in [docs/](docs/); maintenance tools live in [maint/](maint/).

## License

[Apache-2.0](LICENSE).
