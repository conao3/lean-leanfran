# Python

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) for Python: write Lean blocks with `lean(...)`, expose Lean types as pydantic models, and verify supported Python functions against Lean specifications.

## Install

```sh
uv add leanfran
nix profile install 'github:conao3/lean-leanfran#python'
```

Generation also requires Lean 4.35.0 (`lean` and `lake`) on `PATH`. Generated modules run with the Python package and pydantic.

## First Lean block

Create `src/myapp/__init__.py` and put this in `src/myapp/arith.py`:

```python
from leanfran import lean

arith = lean("arith", r"""
def double (n : Nat) : Nat := n + n

theorem double_eq (n : Nat) : double n = 2 * n := by
  unfold double; omega
""")
```

Generate the Python modules:

```sh
leanfran sync --package src/myapp
```

Then call the function from your application:

```python
from myapp.arith import arith

assert arith.double(21) == 42
```

Commit `src/myapp/_lean/` with your package, and add `.leanfran/` to `.gitignore`. Run sync again when you change a Lean block.

## Next steps

- [Full Python guide](https://github.com/conao3/lean-leanfran/blob/master/docs/python-guide.md): pydantic models, JSON, `@model`, verification, CLI and limitations.
- [Samples](https://github.com/conao3/lean-leanfran/blob/master/langs/Python/samples/README.md), including pricing, word count and step-by-step examples.
- [Development](https://github.com/conao3/lean-leanfran/blob/master/CONTRIBUTING.md) and [implementation notes](https://github.com/conao3/lean-leanfran/blob/master/docs/python-development.md).
