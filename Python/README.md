# lean-py

Write and prove functions in Lean 4, run them as Python, and pass pydantic models across.

```python
from pydantic import BaseModel, Field
from lean_python import lean


class LineItem(BaseModel):
    sku: str
    qty: int = Field(ge=1)
    unitPrice: int = Field(ge=0)


pricing = lean("pricing", r"""
inductive Discount where
  | none
  | percent (p : Nat) (h : p ≤ 100)
  | fixed (amount : Nat)

def subtotal (items : List LineItem) : Nat :=
  items.foldl (fun acc i => acc + i.qty * i.unitPrice) 0

def total (items : List LineItem) (d : Discount) : Nat :=
  match d with
  | .none => subtotal items
  | .percent p _ => subtotal items - subtotal items * p / 100
  | .fixed a => subtotal items - a

theorem total_le (items : List LineItem) (d : Discount) : total items d ≤ subtotal items := by
  unfold total; split <;> omega
""", models=[LineItem])

items = [LineItem(sku="a", qty=2, unitPrice=100)]
pricing.total(items, pricing.Discount.percent(p=10))  # 180
pricing.Discount.percent(p=150)                       # pydantic.ValidationError: p: Input should be less than or equal to 100
```

- `lean-py sync` checks the proofs with Lake and compiles the Lean code from Lean's IR to plain
  Python. The generated modules are written to `<package>/_lean/` and ship with your package; running
  them needs only the `lean-python` wheel (and pydantic), not Lean.
- The generated Python computes what the C backend computes: a diff test runs the same Lean
  programs natively and as Python and compares the output byte for byte. Reference counting is
  kept, so `Array` updates happen in place as in C.
- Lean structures and inductive types become pydantic models. A proof field (`h : p ≤ 100`) becomes
  a validator that runs a decision procedure compiled from the proposition, so every value that
  reaches Lean satisfies the invariants the proofs rely on; a comparison with a constant also becomes
  an annotated-types constraint (`Le(100)`), checked by pydantic-core and shown in the JSON Schema. The JSON of the models is the JSON of
  Lean's `deriving ToJson, FromJson`.
- Your own pydantic models can be used from Lean (`models=[...]`). Their field constraints
  (`ge`, `gt`, `le`, `lt`, `min_length`, `max_length`) become proof fields that Lean proofs may assume.
- The models work wherever pydantic does: `TypeAdapter`, `model_validate_json`, JSON Schema, FastAPI
  request and response types.

## Install

The Python package and the Lean CLI:

```sh
uv add lean-python                            # the runtime, lean(), lean-py sync
nix profile install github:conao3/lean-py     # the Lean CLI `lean-python`
```

`lean-py sync` also needs `lake` and the Lean toolchain of `lean-toolchain` (v4.35.0) on `PATH`.

## Lean blocks

`lean(name, source, *, imports=(), uses=(), models=())` defines a Lean block of the calling module
(which must belong to a package). The block's definitions are in the namespace
`LeanPythonEmbed.<module>.<name>`; the returned module exposes them under their names relative to it
(`Discount.percent`, `total`).

```sh
lean-py sync --package src/myapp
```

imports every module of the package, writes each block to a Lake workspace in
`.lean-python/workspace/`, builds it, and generates `src/myapp/_lean/<module>__<name>.py` and
`src/myapp/_lean/blocks.json`. Lean errors point at the Python file:

```
lean-py: src/myapp/m.py:6: error: (lean block m, Lean 4:28) Tactic `rfl` failed: ...
```

Add `.lean-python/` to `.gitignore` and commit `<package>/_lean/`.

At run time `lean(...)` compares a hash of the block (its source, imports, uses, the Lean structures
of its models and the generator version) with `blocks.json` and raises `LeanBlockStale` when the
block changed since the last sync. With `LEAN_PYTHON_AUTO_SYNC=1` it runs `lean-py sync` instead.

- `imports=["Std.Data.HashMap"]`: Lean modules to import.
- `uses=["geometry"]`: other blocks of the module (or `"pkg.mod:name"`), imported and opened; their
  types are shared, not generated again.
- `models=[LineItem]`: pydantic models available as Lean structures (below).

## Values

| Lean | Python |
|---|---|
| `Nat` | `int` (`lean_python.types.Nat` = `Annotated[int, Ge(0)]`) |
| `Int` | `int` |
| `UInt8` … `UInt64`, `USize`, `Int8` … `Int64` | `int` with the range as `Ge`/`Le` |
| `Fin n` | `Annotated[int, Ge(0), Lt(n)]` |
| `Bool` | `bool` |
| `Char` | `str` of one character |
| `String` | `str` |
| `Float`, `Float32` | `float` |
| `Unit` | `None` |
| `Option α` | `α \| None` |
| `List α`, `Array α` | `list[α]` |
| `α × β` | `tuple[α, β]` |
| `{x : α // p x}` | `Annotated[α, AfterValidator(p)]` |
| structure | a frozen, strict pydantic model |
| inductive type, constructors without arguments | `enum.StrEnum` |
| other inductive type | a model per constructor, subclasses of the type's class |
| `IO α` | `α`; an `IO.Error` is raised as `LeanIOError` (an `OSError`) |

Arguments are checked while they are converted (`pub.double(-1)` raises `ValidationError` with the
location of the bad value). Constants are functions without arguments (`answer()`).

Constructors and structures take keyword arguments (`Shape.rect(width=1, height=2)`); unnamed
constructor arguments are `a0`, `a1`, …. Inductive values work with `match`:

```python
match shape:
    case geometry.Shape.rect(width=w, height=h):
        ...
```

### JSON

The JSON of a generated model is the JSON of Lean's derived `ToJson`: a structure is an object, a
constructor without arguments is its name (`"dot"`), a constructor with named arguments is
`{"rect": {"width": 1, "height": 2}}`, with unnamed arguments `{"num": 7}` or `{"pair": [1, "x"]}`.
`tests/test_json.py` compares the generated models with a native Lean program that prints `toJson`.

### Your pydantic models in Lean

`models=[LineItem]` writes a Lean structure for each model (and the models its fields use) to the
namespace `LeanPythonModels.<python module>`, opened in the block:

```lean
structure LineItem where
  sku : String
  qty : Nat
  qty_ge : 1 ≤ qty
  unitPrice : Nat
```

`int` with a lower bound of at least 0 becomes `Nat`; the other bounds and `min_length`/`max_length`
become proof fields. Field types: `int`, `bool`, `str`, `float`, `list[T]`, `tuple[...]`, `T | None`,
other models, enums (an inductive type `LeanPythonModels.<module>.<Enum>` with a constructor per
member), `Literal["a", "b"]` (`LeanPythonLiterals.<module>.<Model>_<field>`), and unions of models
(`LeanPythonUnions.<module>.<Model>_<field>`, a constructor per model holding it as `val`). `multiple_of`, `pattern` and validators are not assumed in Lean; the structure's
docstring lists them. Generated functions take and return your classes; values that did not go
through validation (`model_construct`) are checked again on the way to Lean.

## The CLI

```
lean-python module generate --module-name <Name> [--roots <Name> ...] [--namespace <Name>]
  [--search-path <dir> ...] [--output-file <path>] [--internal-only] [--output json|text]
  [--type-module <Name>=<module> ...] [--model-module <Name>=<module> ...] [--batch <file>]
lean-python --version | --generator-version | help
```

`module generate` writes one Python module with the IR of the roots and of everything they call
(Init and Std included), and public functions and types for the roots. Definitions it cannot expose
(polymorphic functions, functions over functions) are reported as skipped. Exit codes: 0 success,
252 invalid parameters, 254 input that cannot be converted, 255 other errors.

## Performance

`make bench` (CPython 3.14, x86_64; the native column is the C backend):

| workload | n | Python (s) | native C (s) |
|---|---|---|---|
| `Array.push`, `set!`, sum | 10⁴ | 0.017 | 0.005 |
| `Array.push`, `set!`, sum | 10⁵ | 0.179 | 0.006 |
| `Array.push`, `set!`, sum | 10⁶ | 1.796 | 0.017 |
| `fib` (loop) | 10⁵ | 0.176 | 0.074 |
| `naiveFib` | 25 | 0.149 | 0.005 |
| `String.push` | 10⁴ | 0.012 | 0.005 |
| `String.push` | 10⁵ | 0.227 | 0.006 |
| `Array.qsort` | 10⁵ | 1.929 | 0.020 |

Passing 10⁴ models to a Lean function takes 0.036 s (pydantic's `TypeAdapter(list[Model])` validates
10⁴ dicts in 0.009 s).

## Development

```sh
nix develop -c make check   # treefmt, the diff tests against the C backend, pytest
nix develop -c make bench
```

- `LeanPython/EmitPy.lean`: IR → Python. `LeanPython/Marshal.lean`, `LeanPython/Generate.lean`: public
  types and functions. `Main.lean`: the CLI.
- `src/lean_python/runtime.py`, `io_externs.py`: the runtime (`lean_*` are the C names of Lean's
  externs). `marshal.py`, `types.py`: pydantic types. `embed.py`, `sync.py`, `models.py`, `cli.py`:
  `lean(...)` and `lean-py sync`.
- `LeanPythonTest/`: Lean programs of the tests; `test-diff.sh` runs `Vectors` and `Io` natively and
  as Python.

## Limitations

- Polymorphic functions, functions taking or returning functions, `Thunk`/`Task`/`IO.Ref`/
  `ByteArray` in public signatures are not exposed (they still run inside Lean code).
- `Task`s run synchronously.
- Building a `String` with `String.push` copies the string each time (Python `bytes`), so it grows
  quadratically.
- Python's own functions are not verified in Lean yet.

## License

Apache-2.0
