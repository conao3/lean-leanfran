# Python guide

[leanfran](../README.md) | [Python quick start](../langs/Python/README.md)

Commands and source paths below are relative to `langs/Python/`.

## Installation

See the [Python quick start](../langs/Python/README.md) for installation.

## Lean blocks

`lean(name, source, *, imports=(), uses=(), models=())` defines a Lean block of the calling module,
which must belong to a package. The block's definitions live in the namespace
`LeanPythonEmbed.<module>.<name>`. The returned module exposes them under their names relative to it
(`Discount.percent`, `total`).

```sh
uv run leanfran --lang python sync --package src/myapp
```

`leanfran --lang python sync` imports every module of the package, writes each block to a Lake
workspace in `.leanfran/python/workspace/` next to `pyproject.toml`, builds it, and generates
`src/myapp/_lean/<module>__<name>.py` and `src/myapp/_lean/blocks.json`. It records the blocks and
the generated files in `leanfran.manifest.json` next to `pyproject.toml` and prints
`leanfran: <N> blocks checked and generated`. Lean errors point at the Python file:

```
src/myapp/m.py:6:54: error: (lean block myapp.m:m, Lean 4:53) Tactic `rfl` failed: The left-hand side ...
```

Commit `<package>/_lean/` and `leanfran.manifest.json`. `sync` writes `.leanfran/.gitignore`, which
keeps the workspace and the lock file `.leanfran/lock` out of git.

At run time `lean(...)` compares a hash of the block (its source, imports, uses, the Lean structures
of its models and the generator version) with `blocks.json`. If the block changed since the last
sync, it raises `LeanBlockStale`. With `LEANFRAN_PYTHON_AUTO_SYNC=1` it runs `leanfran --lang python sync` instead.

- `imports=["Std.Data.HashMap"]`: Lean modules to import.
- `uses=["geometry"]`: other blocks of the module (or `"pkg.mod:name"`) to import and open. The
  block shares their types and does not generate them again.
- `models=[LineItem]`: pydantic models available as Lean structures (below).

## Values

| Lean                                           | Python                                                       |
| ---------------------------------------------- | ------------------------------------------------------------ |
| `Nat`                                          | `int` (`leanfran.types.Nat` = `Annotated[int, Ge(0)]`)       |
| `Int`                                          | `int`                                                        |
| `UInt8` … `UInt64`, `USize`, `Int8` … `Int64`  | `int` with the range as `Ge`/`Le`                            |
| `Fin n`                                        | `Annotated[int, Ge(0), Lt(n)]`                               |
| `Bool`                                         | `bool`                                                       |
| `Char`                                         | `str` of one character                                       |
| `String`                                       | `str`                                                        |
| `Float`, `Float32`                             | `float`                                                      |
| `Unit`                                         | `None`                                                       |
| `Option α`                                     | `α \| None`                                                  |
| `List α`, `Array α`                            | `list[α]`                                                    |
| `α × β`                                        | `tuple[α, β]`                                                |
| `Except ε α`                                   | `leanfran.Ok[α] \| leanfran.Err[ε]`                          |
| `{x : α // p x}`                               | `Annotated[α, AfterValidator(p)]`                            |
| structure                                      | a frozen, strict pydantic model                              |
| inductive type, constructors without arguments | `enum.StrEnum`                                               |
| other inductive type                           | a model per constructor, subclasses of the type's class      |
| `IO α`                                         | `α`; an `IO.Error` is raised as `LeanIOError` (an `OSError`) |

The generated functions check arguments while they convert them: `pub.double(-1)` raises
`ValidationError` with the location of the bad value. Constants are functions without arguments
(`answer()`).

Constructors and structures take keyword arguments (`Shape.rect(width=1, height=2)`); unnamed
constructor arguments are `a0`, `a1`, …. Inductive values work with `match`:

```python
match shape:
    case geometry.Shape.rect(width=w, height=h):
        ...
```

A function returning `Except ε α` returns `Ok(value=…)` or `Err(error=…)`, and an `Except`
argument or field takes either:

```python
from leanfran import Err, Ok

match kernel.transition(actor, snapshot, command):
    case Ok(value=(write, reply)):
        ...
    case Err(error=e):
        ...
```

### Handles

A generated function converts its arguments to Lean values and its result back on every call,
which costs time in proportion to their size. `fn.lean` is the same function on handles
(`leanfran.Lean`): it takes Python values or handles and returns a handle, which keeps the Lean
value without converting it.

```python
snapshot = kernel.init.lean()
result = kernel.transition.lean(actor, snapshot, command).get()
snapshot = kernel.apply.lean(snapshot, write)
rows = snapshot.get()
snapshot = kernel.apply.lean.params["snap"].new(rows)
```

- `handle.get()` converts a handle to the Python value.
- `fn.lean.params[name]` and `fn.lean.result` are the Lean types of the function
  (`leanfran.LeanType`), and `handle.type` is the type of a handle. `type.new(value)` checks a
  Python value like an argument and makes a handle. A handle of another Lean type is rejected
  with `ValidationError`.
- A handle is immutable: Lean functions that receive it build new values instead of updating in
  place.

`fn.local` is the function on local handles (`leanfran.Local`). A local handle keeps the
reference counts of its objects, so a Lean function can update the value in place when it gets
the only reference. Passing a local handle keeps it valid; `handle.take()` gives its reference
to the function and leaves the handle empty:

```python
snapshot = kernel.init.local()
result = kernel.transition.local(actor, snapshot, command).get()
snapshot = kernel.apply.local(snapshot.take(), write)  # the list is updated in place
```

- `type.new_local(value)` makes a local handle of a Python value and `local.share()` the `Lean`
  handle of a local one. `fn.local` and `fn.lean` take both kinds.
- Use a local handle, and the local handles made from it, from one thread at a time: the
  reference counts are plain Python integers, also on free-threaded builds. A `Lean` handle can
  be read from several threads, since its objects are never updated.

`IO` actions have no `lean` and no `local`. One `transition` and `apply` on a snapshot of 100
two-number structures in a `List` takes 0.84 ms with Python values, 0.09 ms with `Lean` handles
and 0.06 ms with a local handle.

### JSON

The JSON of a generated model is the JSON of Lean's derived `ToJson`: a structure is an object, a
constructor without arguments is its name (`"dot"`), a constructor with named arguments is
`{"rect": {"width": 1, "height": 2}}`, with unnamed arguments `{"num": 7}` or `{"pair": [1, "x"]}`.
`Ok` is `{"ok": value}` and `Err` is `{"error": error}`, the JSON of `deriving instance ToJson for Except`.
`tests/test_json.py` compares the generated models with a native Lean program that prints `toJson`.

### Your pydantic models in Lean

`models=[LineItem]` writes a Lean structure for each model (and the models its fields use) to the
namespace `LeanPythonModels.<python module>`, and the block opens that namespace:

```lean
structure LineItem where
  sku : String
  qty : Nat
  qty_ge : 1 ≤ qty
  unitPrice : Nat
```

`int` with a lower bound of at least 0 becomes `Nat`; the other bounds and `min_length`/`max_length`
become proof fields. Field types:

- `int`, `bool`, `str`, `float`, `list[T]`, `tuple[...]`, `T | None`, other models
- enums: an inductive type `LeanPythonModels.<module>.<Enum>` with a constructor per member
- `Literal["a", "b"]`: `LeanPythonLiterals.<module>.<Model>_<field>`
- unions of models: `LeanPythonUnions.<module>.<Model>_<field>`, a constructor per model holding it
  as `val`

Lean proofs cannot assume `multiple_of`, `pattern` or validators; the structure's docstring lists
them. Generated functions take and return your classes. Values that skipped validation
(`model_construct`) go through validation again on the way to Lean.

## Verifying Python functions

`@model` binds a typed, pure Python function to specifications written in a Lean block. The function
stays ordinary Python. `leanfran --lang python check` translates it to Lean and checks your proofs, and
`check_model` runs the same specifications as a Hypothesis property test.

```python
from leanfran import lean
from leanfran.verify import model

spec = lean("spec", r"""
def clampSpec (x lo hi : Int) : Int := max lo (min hi x)
def ordered (_x lo hi : Int) : Bool := lo ≤ hi
def inRange (_x lo hi : Int) (r : Int) : Bool := lo ≤ r && r ≤ hi
""")

@model(refines=spec.clampSpec, requires=spec.ordered, ensures={"in_range": spec.inRange})
def clamp(x: int, lo: int, hi: int) -> int:
    if x < lo:
        return lo
    if x > hi:
        return hi
    return x
```

`leanfran --lang python check --package calc` runs `sync`, then writes the translation and one
obligation per specification to `.leanfran/python/workspace/LeanPythonModel/calc/calc.lean`. In
`tests/verify`, where the block is in `calc/spec.py`, the file starts:

```lean
import LeanPythonEmbed.calc.spec.spec
import LeanPythonLib.Py

/-- `calc.calc.clamp`, translated from Python. -/
def LeanPythonModel.«calc».«calc».clamp (x : Int) (lo : Int) (hi : Int) : Int := Id.run do
  if ((decide (x < lo))) then
    return lo
  if ((decide (x > hi))) then
    return hi
  return x

abbrev LeanPythonModel.«calc».«calc».clamp.obligation.refines : Prop :=
  ∀ (x : Int) (lo : Int) (hi : Int), LeanPythonEmbed.calc.spec.spec.ordered x lo hi = true → (LeanPythonModel.«calc».«calc».clamp x lo hi) = (LeanPythonEmbed.calc.spec.spec.clampSpec x lo hi)
```

Then it judges the theorems `<function>.proof.<label>` of `lean/Proofs/*.lean` next to
`pyproject.toml`:

```lean
import LeanPythonModel.calc.calc
open LeanPythonEmbed.calc.spec.spec
namespace LeanPythonModel.«calc».«calc»

theorem clamp.proof.refines : clamp.obligation.refines := by
  intro x lo hi h
  simp only [ordered, decide_eq_true_eq] at h
  simp only [clamp, clampSpec]
  split <;> (try split) <;> simp_all <;> omega
```

It prints a row `<id> [<label>]: <state>` per obligation (`tests/verify`):

```
calc.calc:clamp [in_range]: proved
calc.calc:clamp [refines]: proved
calc.calc:first_or [refines]: proved
calc.calc:sum_abs [nonneg]: proved
calc.calc:sum_to [refines]: sorry
calc.calc:sum_to [returns_nat]: missing
```

Under `simp`, a `for` loop over a list becomes `List.foldl` (`forIn_pure_yield_eq_foldl`), so you
prove a loop by induction on the list (`tests/verify/lean/Proofs/Calc.lean` proves `sum_abs`).

The states:

| state         | meaning                                   |
| ------------- | ----------------------------------------- |
| `proved`      | the theorem holds                         |
| `sorry`       | the proof uses `sorry`                    |
| `axioms`      | the proof uses non-standard axioms        |
| `failed`      | the proof file does not build             |
| `missing`     | no theorem for the obligation             |
| `mismatch`    | the theorem states something else         |
| `unextracted` | the obligation's statement is not defined |

A function that cannot be translated also prints
`<file>:<line>:<column>: unextracted <id>: <message>` on stderr, for example
`calc/calc.py:40:16: unextracted calc.calc:distinct: unsupported expression SetComp`.
`check` exits 1 when an obligation is `unextracted` or `failed`, and with `--require proved` when
an obligation is not `proved`. It writes the results to `leanfran.lock` next to `pyproject.toml`;
commit the lock with the manifest.

`leanfran --lang python status` runs without Lean and Lake. It compares the blocks with the manifest
and checks that the generated files exist, then compares the functions with the lock. It prints
`<block>: stale`, `<block>: missing <path>` and `<block>: removed` for blocks
(`calc.spec:spec: stale`), `python: missing <path>` for a missing `_lean/__init__.py` or
`_lean/blocks.json`, and the function rows of `check`, with `stale` for a function whose source,
blocks or proofs changed and `<id>: removed` for a locked function without `@model`. It prints no
row for a fresh block. `status` exits 1 when it prints a block row or a `stale` or `removed`
function, and with `--require proved` when an obligation is not `proved`. It hashes with
`sha256sum` (`shasum` on macOS), so that command must be on `PATH`.

- `refines=s`: `f x = s x` (`Except.ok (s x)` for a function that may fail); `requires=p`: `p x = true →`
  before each obligation; `ensures={"label": q}`: `q x (f x) = true`. A function annotated `-> Nat`
  also gets `returns_nat` (`0 ≤ f x`).
- The translation: `int` is `Int` (a `Nat` parameter is a `Nat` converted to `Int` on entry);
  statements become Lean `do` notation (`let mut`, `for`, `while`, `break`, `continue`, early
  `return`); indexing, `//`, `%`, `assert` and `raise` make the function return
  `Py.M α = Except Py.Exc α`, with Python's negative indices and floor division (`LeanPythonLib.Py`).
  Supported: `int`, `bool`, `str`, `float`, `list`, `tuple`, `T | None`, pydantic models (as the
  Lean structures of `models=`), `len`, `abs`, `min`, `max`, `sum`, list comprehensions, `append` on
  local lists, and calls of other `@model` functions of the module.
- `check_model(f)` / `check_module(m)` generate arguments from the annotations (pydantic constraints
  included), skip those failing `requires`, and compare with `refines` and `ensures`.

## Examples

[`samples/`](https://github.com/conao3/lean-leanfran/tree/master/langs/Python/samples) holds Python packages with Lean
blocks. `make samples` syncs each one, runs it, and compares the output with its `expected.txt`.

| sample                                                                                              | shows                                                                                          |
| --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [word-count](https://github.com/conao3/lean-leanfran/tree/master/langs/Python/samples/word-count)         | strings and lists, a proof by induction                                                        |
| [roman-numerals](https://github.com/conao3/lean-leanfran/tree/master/langs/Python/samples/roman-numerals) | a round-trip theorem checked for every number below 1000 (`decide +kernel`)                    |
| [todo-cli](https://github.com/conao3/lean-leanfran/tree/master/langs/Python/samples/todo-cli)             | an invariant over a list kept by every operation, JSON storage, tampered JSON rejected         |
| [pricing-api](https://github.com/conao3/lean-leanfran/tree/master/langs/Python/samples/pricing-api)       | FastAPI with a pydantic model and a Lean inductive type as request body, 422 for invalid input |

[`samples/steps/`](https://github.com/conao3/lean-leanfran/tree/master/langs/Python/samples/steps) introduces one
feature at a time, from functions on `Nat` (01) to types shared between blocks with `uses=` (09).

## The CLI

Every command is a command of the executable `leanfran`:

```
leanfran --lang python sync --package <dir> [--verbose]
leanfran --lang python check --package <dir> [--verbose] [--require proved]
leanfran --lang python status --package <dir> [--require proved]
```

The project root is the nearest directory at or above the package with a `pyproject.toml`. The
executable reads the package with `python3 -m leanfran.cli scan` and, during `check`,
`translate`, run in the root. These two commands print JSON and write no file; the executable
builds the Lake workspace in `.leanfran/python/workspace`, generates the Python, installs it, and
writes `leanfran.manifest.json` and `leanfran.lock`. A failed install restores the previous
files. `sync` and `check` take `.leanfran/lock` for the whole run and `status` shares it.

Run `leanfran` where `python3` imports the project's `leanfran`, for example
`uv run leanfran --lang python sync --package src/myapp`; otherwise it prints that example and
exits 255. The Python package installs no command. The release version, generator version and
Lean version of the executable must match the installed Python package, so install both from the
same release. `lean` and `lake` on `PATH` must have the executable's Lean version, Lean 4.35.0,
and a `lean-toolchain` next to `pyproject.toml` must name the same version for `sync` and `check`.
A mismatch exits 255.

`sync`, `check` and `status` exit 0 on success, 1 for the rows and states described in
[Verifying Python functions](#verifying-python-functions), 252 for an argument they cannot read,
254 for an error in the package (a Lean diagnostic, a module that fails to import such as
`src/myapp/broken.py:1: RuntimeError: boom`, a file leanfran did not generate at a path that `sync`
writes)
and 255 for an error in the environment (a missing tool, a version mismatch).

When the package generates on its own (`LEANFRAN_PYTHON_AUTO_SYNC=1`), it takes the executable
from `$LEANFRAN_CLI`, then `leanfran` on `PATH`. The same executable does the compilation:

```
leanfran --lang python module generate --module-name <Name> [--roots <Name> ...] [--namespace <Name>]
  [--import <Name> ...] [--search-path <dir> ...] [--output-file <path>] [--internal-only]
  [--output json|text] [--type-module <Name>=<module> ...] [--model-module <Name>=<module> ...]
  [--batch <file>]
leanfran --lang python obligations check --modules <Name> ... --obligations <file> [--search-path <dir> ...]
leanfran --lang python --version | --generator-version | help
```

`module generate` writes one Python module with the IR of the roots and of everything they call
(Init and Std included), and public functions and types for the roots. It reports the definitions it
cannot expose (polymorphic functions, functions over functions) as skipped. These commands use the
exit codes 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors.

## Performance

`make bench` (CPython 3.14, x86_64; the native column is the C backend):

| workload                  | n   | Python (s) | native C (s) |
| ------------------------- | --- | ---------- | ------------ |
| `Array.push`, `set!`, sum | 10⁴ | 0.017      | 0.005        |
| `Array.push`, `set!`, sum | 10⁵ | 0.179      | 0.006        |
| `Array.push`, `set!`, sum | 10⁶ | 1.796      | 0.017        |
| `fib` (loop)              | 10⁵ | 0.176      | 0.074        |
| `naiveFib`                | 25  | 0.149      | 0.005        |
| `String.push`             | 10⁴ | 0.012      | 0.005        |
| `String.push`             | 10⁵ | 0.227      | 0.006        |
| `Array.qsort`             | 10⁵ | 1.929      | 0.020        |

Passing 10⁴ models to a Lean function takes 0.036 s (pydantic's `TypeAdapter(list[Model])` validates
10⁴ dicts in 0.009 s).

## Development

```sh
nix develop ../..#python -c make check   # treefmt, the diff tests against the C backend, pytest, the samples
nix develop ../..#python -c make bench
```

- `LeanPython/EmitPy.lean`: IR → Python. `LeanPython/Marshal.lean`, `LeanPython/Generate.lean`: public
  types and functions. `LeanPython/Check.lean`: `obligations check`. `LeanPython/Cli.lean`: the CLI.
- `src/leanfran/runtime.py`, `io_externs.py`: the runtime (`lean_*` are the C names of Lean's
  externs). `marshal.py`, `types.py`: pydantic types. `embed.py`, `models.py`: `lean(...)`.
  `cli.py`, `scan.py`, `translation.py`: the commands `scan` and `translate` that
  `leanfran --lang python sync|check|status` runs. `verify.py`, `translate.py`: `@model` and its
  translation; `lean/LeanPythonLib/Py.lean` holds Python's semantics in Lean.
- `LeanPython/Embed.lean`: the Python `Backend` of the compiler's `Leanfran.Embed`, which runs
  `sync`, `check` and `status`.
- `LeanPythonTest/`: Lean programs of the tests; `../../maint/Python/test-diff.sh` runs `Vectors` and `Io` natively and
  as Python.

## Limitations

- leanfran does not expose polymorphic functions, functions taking or returning functions, or
  `Thunk`/`Task`/`IO.Ref`/`ByteArray` in public signatures. They still run inside Lean code.
- `Task`s run synchronously.
- Building a `String` with `String.push` copies the string each time (Python `bytes`), so it grows
  quadratically.
- The translation of Python functions covers the subset above; the guarantee is partial correctness.

## License

[Apache-2.0](https://github.com/conao3/lean-leanfran/blob/master/LICENSE)
