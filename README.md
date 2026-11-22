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
</p>

<p align="center">
  <a href="#quick-look">Quick look</a> ·
  <a href="#get-started">Get started</a> ·
  <a href="#lean-at-the-core">Languages</a> ·
  <a href="#what-you-can-build">Features</a> ·
  <a href="#documentation">Documentation &amp; examples</a> ·
  <a href="#contribution">Contribution</a>
</p>

# leanfran

leanfran brings Lean 4 to your programming language. Write functions and proofs together, compile them to your application's language, and call them through native types. The generated code runs with a small host-language runtime; Lean is needed to check and generate code, not to run the result.

## Quick look

Install the Python compiler and Lean 4.35.0, and start a project:

```console
$ nix profile install 'github:conao3/lean-leanfran#python'
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
$ uv run leanfran sync --package src/myapp
leanfran: 1 blocks of myapp checked and generated
$ uv run python -c 'from myapp.arith import arith; print(arith.double(21))'
42
```

Change the theorem to `double n = 3 * n` and generation stops at the proof:

```console
$ uv run leanfran sync --package src/myapp
leanfran: /tmp/myapp/src/myapp/arith.py:7: error: (lean block arith, Lean 5:17) omega could not prove the goal:
a possible counterexample may satisfy the constraints
  a ≥ 1
where
 a := ↑n
leanfran: lake build failed
```

Every supported language embeds Lean the same way (see the table below). The output above is from leanfran 0.6.0 (PyPI and the Nix compiler) in `/tmp/myapp`.

## Lean at the core

leanfran compiles Lean's compiler IR into source code for the selected language. You can generate code from a Lean project or embed Lean blocks directly in host-language source files. Proofs are checked by Lean during generation and erased from the executable code.

| Language   | Start here                                     | Package                                                                               | Integration                                    |
| ---------- | ---------------------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Rust       | [Rust quick start](langs/Rust/README.md)             | [leanfran on crates.io](https://crates.io/crates/leanfran)                            | `lean!`, Rust types, Cargo build integration   |
| Python     | [Python quick start](langs/Python/README.md)         | [leanfran on PyPI](https://pypi.org/project/leanfran/)                                | `lean(...)`, pydantic models, Python modules   |
| TypeScript | [TypeScript quick start](langs/TypeScript/README.md) | [leanfran on npm](https://www.npmjs.com/package/leanfran)                             | `lean(...)`, TypeScript types, Standard Schema |
| Clojure    | [Clojure quick start](langs/Clojure/README.md)       | [io.github.conao3/leanfran on Clojars](https://clojars.org/io.github.conao3/leanfran) | `deflean`, Clojure values, JVM namespaces      |
| PHP        | [PHP quick start](langs/PHP/README.md)               | Composer path repository (Packagist pending) | `#[Lean]`, `#[Model]`, Composer CLI |

## What you can build

- **Proved functions in your application.** Keep an algorithm and its correctness proof together, then call the generated function from your application.
- **Validated data at the boundary.** Lean structures and inductive types map to host-language values. Supported proof fields become runtime checks for the invariants your proofs assume.
- **Specifications for host-language code.** Bind supported Rust, Python, TypeScript, Clojure, or PHP functions to Lean specifications, translate them to Lean, and check proof obligations. Each language guide describes its supported subset and verification tools.

The backends share Lean's semantics and are tested against Lean's native C backend. Their supported types, externs and host-language integrations are documented in the [language guides](#documentation).

## Get started

Choose a language above and install its host package and compiler. Lean 4.35.0 is required for generation and proof checking. With Nix, install a compiler from this repository:

```sh
nix profile install 'github:conao3/lean-leanfran#python'
```

The compiler targets also include `#rust`, `#typescript`, `#clojure`, and `#php`. The Rust package also includes the Cargo CLI and Aeneas verification tools. For PHP, build the compiler from a checkout with `nix build .#php` and install the runtime through a Composer path repository. Follow the language quick start for dependencies, project setup, and generation commands.

## Documentation

| Language   | Quick start                                   | Full guide                                                | Examples                                           |
| ---------- | --------------------------------------------- | --------------------------------------------------------- | -------------------------------------------------- |
| Rust       | [Setup and first block](langs/Rust/README.md)       | [Types, verification and CLI](docs/rust-guide.md)         | [Rust samples](langs/Rust/samples/README.md)             |
| Python     | [Setup and first block](langs/Python/README.md)     | [Models, verification and CLI](docs/python-guide.md)      | [Python samples](langs/Python/samples/README.md)         |
| TypeScript | [Setup and first block](langs/TypeScript/README.md) | [Schemas, verification and CLI](docs/typescript-guide.md) | [TypeScript samples](langs/TypeScript/samples/README.md) |
| Clojure    | [Setup and first block](langs/Clojure/README.md)    | [Types, verification and CLI](docs/clojure-guide.md)      | [Clojure samples](langs/Clojure/samples/README.md)       |
| PHP        | [Setup and first block](langs/PHP/README.md)       | [Embedding, types, verification and CLI](docs/php-guide.md)     | [PHP samples](langs/PHP/samples/README.md)               |

## Contribution

New language support is welcome! Use the latest [Claude Opus](https://www.anthropic.com/claude/opus),
[OpenAI Sol](https://developers.openai.com/api/docs/models), or a model with a comparable
score on the [Artificial Analysis Intelligence Index](https://artificialanalysis.ai/models#intelligence),
and ask your coding agent to follow [this guide](docs/add-language.md):

```text
Read docs/add-language.md and add support for <LANGUAGE> to leanfran.
```

### Development

The repository has a shared Nix environment and Lean toolchain, with language-specific source and packages under `langs/`. The PHP development shells are `.#php` for PHP 8.4 and `.#php85` for PHP 8.5.

```sh
nix develop
make check
make check BACKENDS=Python
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for build targets, formatting, packaging and the coordinated release process. Implementation notes live in [docs/](docs/); maintenance tools live in [maint/](maint/).

## License

[Apache-2.0](LICENSE).
