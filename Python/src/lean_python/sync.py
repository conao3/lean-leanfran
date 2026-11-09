"""``lean-py sync``: check the Lean blocks of a package and generate their Python modules."""

import ast
import importlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

from lean_python import embed, models

LAKEFILE = """name = "lean-python-workspace"
defaultTargets = ["LeanPythonEmbed"]

[[lean_lib]]
name = "LeanPythonEmbed"

[[lean_lib]]
name = "LeanPythonModels"
"""

_LAKE_ERROR = re.compile(r"^(error|warning): (?:\./)*(LeanPython(?:Embed|Models)/[^:]+\.lean):(\d+):(\d+): (.*)$")


class SyncError(Exception):
    def __init__(self, msg, code=254):
        super().__init__(msg)
        self.code = code


def project_root(pkg_dir):
    p = pkg_dir.resolve()
    for d in [p, *p.parents]:
        if (d / "pyproject.toml").exists():
            return d
    return p.parent


def record_blocks(pkg_dir):
    """Imports every module of the package and returns the blocks their `lean(...)` calls define."""
    pkg_dir = pkg_dir.resolve()
    pkg = pkg_dir.name
    sys.path.insert(0, str(pkg_dir.parent))
    embed._recording = []
    errors = []
    try:
        for path in sorted(pkg_dir.rglob("*.py")):
            rel = path.relative_to(pkg_dir)
            if rel.parts[0] == "_lean" or "__pycache__" in rel.parts or rel.name == "__main__.py":
                continue
            parts = [pkg, *rel.with_suffix("").parts]
            if parts[-1] == "__init__":
                parts = parts[:-1]
            name = ".".join(parts)
            try:
                importlib.import_module(name)
            except Exception as e:  # noqa: BLE001
                errors.append(f"{name}: {type(e).__name__}: {e}")
        return list(embed._recording), errors
    finally:
        embed._recording = None


def resolve_use(block, use, by_name):
    q = use if ":" in use else f"{block.module}:{use}"
    b = by_name.get(q)
    if b is None:
        raise SyncError(f"{block.file}:{block.line}: lean block {block.name!r} uses unknown block {use!r}", 252)
    return b


def block_file(block, by_name):
    imports = list(block.imports)
    opens = []
    if block.models:
        for module in models.modules_source(list(block.models)):
            ns = models.dotted(models.models_namespace(module))
            imports.append(ns)
            opens.append(ns)
    for use in block.uses:
        other = resolve_use(block, use, by_name)
        ns = models.dotted(other.lean_module)
        imports.append(ns)
        opens.append(ns)
    ns = models.dotted(block.lean_module)
    head = "".join(f"import {i}\n" for i in dict.fromkeys(imports))
    head += f"\nnamespace {ns}\n"
    head += "".join(f"open {o}\n" for o in opens)
    head += "\n"
    return head, head + block.source + f"\n\nend {ns}\n"


def source_line(block):
    """The line of the Python file where the block's source string starts."""
    try:
        tree = ast.parse(pathlib.Path(block.file).read_text())
    except (OSError, SyntaxError):
        return block.line
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and node.lineno <= block.line <= (node.end_lineno or node.lineno):
            args = [*node.args, *(k.value for k in node.keywords if k.arg == "source")]
            for a in args:
                if isinstance(a, ast.Constant) and a.value == block.source:
                    return a.lineno
    return block.line


def map_error(line, offsets):
    m = _LAKE_ERROR.match(line.strip())
    if not m:
        return None
    sev, path, ln, col, msg = m.groups()
    info = offsets.get(path)
    if info is None:
        return f"{path}:{ln}:{col}: {sev}: {msg}"
    block, head_lines, start = info
    k = int(ln) - head_lines
    if k < 1:
        return f"{block.file}:{block.line}: {sev}: (lean block {block.name}, Lean {ln}:{col}) {msg}"
    return f"{block.file}:{start + k - 1}: {sev}: (lean block {block.name}, Lean {k}:{col}) {msg}"


def lake_messages(output, offsets):
    """The messages of a Lake build mapped to the Python files, with their continuation lines."""
    out = []
    lines = output.splitlines()
    i = 0
    while i < len(lines):
        mapped = map_error(lines[i], offsets)
        i += 1
        if mapped is None:
            continue
        body = [mapped]
        while (
            i < len(lines)
            and lines[i].strip()
            and map_error(lines[i], offsets) is None
            and (
                lines[i].startswith(" ")
                or not re.match(r"^(✖|✔|⣿|trace:|info:|error:|warning:|Some required|- )", lines[i])
            )
        ):
            body.append(lines[i])
            i += 1
        out.append("\n".join(body))
    return out


def sync_package(pkg_dir, cli=None, out=sys.stderr):
    pkg_dir = pathlib.Path(pkg_dir).resolve()
    cli = cli or os.environ.get("LEAN_PYTHON_CLI") or shutil.which("lean-python")
    if cli is None:
        raise SyncError("the Lean CLI `lean-python` is not on PATH (set LEAN_PYTHON_CLI)", 255)
    gv = subprocess.run([cli, "--generator-version"], check=True, capture_output=True, text=True).stdout.strip()
    if gv != embed.GENERATOR_VERSION:
        raise SyncError(f"{cli} generates version {gv}, this package expects {embed.GENERATOR_VERSION}", 255)

    blocks, import_errors = record_blocks(pkg_dir)
    for e in import_errors:
        print(f"lean-py: warning: importing {e}", file=out)
    by_name = {}
    for b in blocks:
        if b.qualname in by_name:
            raise SyncError(f"{b.file}:{b.line}: lean block {b.name!r} is defined twice in {b.module}", 252)
        by_name[b.qualname] = b

    root = project_root(pkg_dir)
    ws = root / ".lean-python" / "workspace"
    for d in ("LeanPythonEmbed", "LeanPythonModels"):
        shutil.rmtree(ws / d, ignore_errors=True)
    ws.mkdir(parents=True, exist_ok=True)
    (ws / "lakefile.toml").write_text(LAKEFILE)

    model_modules = {}
    for b in blocks:
        if b.models:
            model_modules.update(models.modules_source(list(b.models)))
    offsets = {}
    for module, src in model_modules.items():
        p = ws / pathlib.Path(*models.models_namespace(module)).with_suffix(".lean")
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(src)
    for b in blocks:
        head, text = block_file(b, by_name)
        rel = pathlib.Path(*b.lean_module).with_suffix(".lean")
        p = ws / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        offsets[str(rel)] = (b, head.count("\n"), source_line(b))
    (ws / "LeanPythonEmbed.lean").write_text(
        "".join(f"import {models.dotted(b.lean_module)}\n" for b in blocks) or "\n"
    )
    (ws / "LeanPythonModels.lean").write_text(
        "".join(f"import {models.dotted(models.models_namespace(m))}\n" for m in model_modules) or "\n"
    )

    r = subprocess.run(
        ["lake", "build", "LeanPythonEmbed", "LeanPythonModels"], cwd=ws, capture_output=True, text=True, check=False
    )
    failed = r.returncode != 0
    messages = lake_messages(r.stdout + r.stderr, offsets)
    for m in messages:
        if failed or ": warning:" in m.split("\n")[0]:
            print(f"lean-py: {m}", file=out)
    if failed:
        if not messages:
            print(r.stdout + r.stderr, file=out)
        raise SyncError("lake build failed", 254)

    out_dir = pkg_dir / "_lean"
    shutil.rmtree(out_dir, ignore_errors=True)
    out_dir.mkdir()
    jobs = []
    for b in blocks:
        type_modules = [
            {"namespace": ".".join(models.models_namespace(m)), "module": m, "adopt": True}
            for m in (models.modules_source(list(b.models)) if b.models else {})
        ]
        for use in b.uses:
            other = resolve_use(b, use, by_name)
            type_modules.append(
                {"namespace": ".".join(other.lean_module), "module": f"{other.top_package}._lean.{other.stem}"}
            )
        jobs.append(
            {
                "module": ".".join(b.lean_module),
                "namespace": ".".join(b.lean_module),
                "output_file": str(out_dir / f"{b.stem}.py"),
                "type_modules": type_modules,
            }
        )
    batch = ws / "batch.json"
    batch.write_text(json.dumps(jobs))
    r = subprocess.run(
        [
            cli,
            "module",
            "generate",
            "--batch",
            str(batch),
            "--search-path",
            str(ws / ".lake/build/lib/lean"),
            "--output",
            "json",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if r.returncode != 0:
        print(r.stderr + r.stdout, file=out)
        raise SyncError("lean-python module generate failed", r.returncode)
    summaries = json.loads(r.stdout)
    for s in summaries:
        for sk in s.get("skipped", []):
            print(f"lean-py: skipped {sk['name']}: {sk['reason']}", file=out)
    (out_dir / "__init__.py").write_text('"""Python modules generated by `lean-py sync`. Do not edit."""\n')
    registry = {}
    for b in blocks:
        registry[b.qualname] = embed.block_key(b)
    (out_dir / "blocks.json").write_text(json.dumps(registry, indent=2, sort_keys=True) + "\n")
    print(f"lean-py: {len(blocks)} blocks of {pkg_dir.name} checked and generated", file=out)
