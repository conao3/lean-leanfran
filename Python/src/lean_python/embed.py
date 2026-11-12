"""``lean(name, source)``: Lean code in a Python module.

``lean-py sync`` checks the proofs of every block of a package with Lake and writes the Python it
generates to ``<package>/_lean/``. At run time ``lean(...)`` only imports that module, after
checking that it was generated from the same source; Lean is not needed to run the package.
"""

import hashlib
import importlib
import json
import os
import subprocess
import sys
import typing
from dataclasses import dataclass, field

GENERATOR_VERSION = "2"


class LeanBlockStale(RuntimeError):
    """The generated module of a block is missing or was generated from a different source."""


@dataclass
class Block:
    module: str
    name: str
    source: str
    imports: tuple
    uses: tuple
    models: tuple
    file: str
    line: int
    key: str = field(default="")

    @property
    def qualname(self):
        return f"{self.module}:{self.name}"

    @property
    def stem(self):
        return "__".join([*self.module.split("."), self.name])

    @property
    def lean_module(self):
        return ["LeanPythonEmbed", *self.module.split("."), self.name]

    @property
    def top_package(self):
        return self.module.split(".")[0]


def block_key(block):
    from lean_python import models

    model_sources = models.modules_source(list(block.models)) if block.models else {}
    data = {
        "module": block.module,
        "name": block.name,
        "source": block.source,
        "imports": list(block.imports),
        "uses": list(block.uses),
        "models": model_sources,
        "generator": GENERATOR_VERSION,
    }
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


_recording = None
_registries = {}


class _Placeholder:
    """What `lean(...)` returns while `lean-py sync` records the blocks: names are `Any`."""

    def __getattr__(self, name):
        return typing.Any


def _registry(pkg):
    reg = _registries.get(pkg)
    if reg is None:
        try:
            base = sys.modules[pkg].__path__[0]
        except (KeyError, AttributeError, IndexError):
            raise LeanBlockStale(f"lean(...) must be called from a module of a package (got {pkg!r})") from None
        path = os.path.join(base, "_lean", "blocks.json")
        try:
            with open(path, encoding="utf-8") as f:
                reg = json.load(f)
        except FileNotFoundError:
            reg = {}
        _registries[pkg] = reg
    return reg


def lean(name, source, *, imports=(), uses=(), models=()):
    """Defines the Lean block ``name`` of the calling module; returns its generated module."""
    frame = sys._getframe(1)
    block = Block(
        module=frame.f_globals["__name__"],
        name=name,
        source=source,
        imports=tuple(imports),
        uses=tuple(uses),
        models=tuple(models),
        file=frame.f_code.co_filename,
        line=frame.f_lineno,
    )
    if _recording is not None:
        _recording.append(block)
        return _Placeholder()
    block.key = block_key(block)
    pkg = block.top_package
    if _registry(pkg).get(block.qualname) != block.key:
        if os.environ.get("LEAN_PYTHON_AUTO_SYNC") == "1":
            r = subprocess.run(
                [sys.executable, "-m", "lean_python.cli", "sync", "--package", sys.modules[pkg].__path__[0]],
                check=False,
                env={**os.environ, "LEAN_PYTHON_AUTO_SYNC": "0"},
            )
            if r.returncode != 0:
                raise LeanBlockStale(f"`lean-py sync` of {pkg} failed (exit {r.returncode})")
            _registries.pop(pkg, None)
            importlib.invalidate_caches()
        if _registry(pkg).get(block.qualname) != block.key:
            raise LeanBlockStale(
                f"the Lean block {name!r} of {block.module} has changed since `lean-py sync` generated it;"
                " run `lean-py sync` (or set LEAN_PYTHON_AUTO_SYNC=1)"
            )
    return importlib.import_module(f"{pkg}._lean.{block.stem}")
