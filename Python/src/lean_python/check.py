"""``lean-py check`` and ``lean-py status``: the proofs of the ``@model`` functions of a package.

``check`` syncs the package's Lean blocks, translates every ``@model`` function into
``LeanPythonModel.<module>`` with one obligation per specification (``<function>.obligation.<label>``),
builds them with the proofs in ``<project>/lean/Proofs/`` (theorems ``<function>.proof.<label>``),
and asks the Lean CLI for the state of each obligation: proved, sorry, axioms, missing,
mismatch. The result and a hash of each function's source go to ``<project>/lean-python.lock``.
``status`` reads the lock without Lean and marks a function stale when its source changed.
"""

import ast
import hashlib
import importlib
import inspect
import json
import pathlib
import shutil
import subprocess
import sys
import textwrap

from lean_python import models, sync, translate, verify

LAKEFILE_EXTRA = """
[[lean_lib]]
name = "LeanPythonLib"

[[lean_lib]]
name = "LeanPythonModel"

[[lean_lib]]
name = "Proofs"
globs = ["Proofs.+"]
"""

STATUSES = ("proved", "sorry", "axioms", "failed", "missing", "mismatch", "unextracted", "stale")


def model_module(module):
    return ["LeanPythonModel", *module.split(".")]


def function_name(fn):
    return models.dotted([*model_module(fn.__module__), fn.__qualname__])


def source_hash(fn):
    src = textwrap.dedent(inspect.getsource(fn))
    return hashlib.sha256(ast.dump(ast.parse(src)).encode()).hexdigest()


def lean_name_of(spec_fn, label, fn):
    name = getattr(spec_fn, "__lean_name__", None)
    if name is None:
        raise sync.SyncError(
            f"{fn.__qualname__}: the {label} specification is not a function of a lean(...) block", 252
        )
    return name, getattr(spec_fn, "__lean_module__", None)


def obligations(spec, tfn):
    """The Lean statements of the obligations of one function, by label."""
    fn = spec.fn
    binders = []
    args = []
    for name, ann in tfn.params:
        t = translate.py_type(ann, fn)
        ty = "Nat" if translate.is_nat(ann) else translate.lean_type(t)
        binders.append(f"({translate.lean_ident(name)} : {ty})")
        args.append(translate.lean_ident(name))
    call = f"({tfn.lean_name} {' '.join(args)})"
    a = " ".join(args)
    imports = set()
    pre = ""
    if spec.requires is not None:
        r, m = lean_name_of(spec.requires, "requires", fn)
        imports.add(m)
        pre = f"{r} {a} = true → "
    out = {}

    def wrap(body):
        return f"∀ {' '.join(binders)}, {pre}{body}" if binders else f"{pre}{body}"

    if spec.refines is not None:
        s, m = lean_name_of(spec.refines, "refines", fn)
        imports.add(m)
        ret = getattr(spec.refines, "__annotations__", {}).get("return")
        expected = f"(({s} {a} : Nat) : Int)" if ret == "Nat" else f"({s} {a})"
        out["refines"] = wrap(f"{call} = Except.ok {expected}" if tfn.fails else f"{call} = {expected}")
    for label, e in spec.ensures.items():
        en, m = lean_name_of(e, label, fn)
        imports.add(m)
        out[label] = wrap(f"∀ r, {call} = Except.ok r → {en} {a} r = true" if tfn.fails else f"{en} {a} {call} = true")
    if tfn.ret_nat:
        out["returns_nat"] = wrap(f"∀ r, {call} = Except.ok r → 0 ≤ r" if tfn.fails else f"0 ≤ {call}")
    return out, {i for i in imports if i}


def reimport(pkg):
    for name in [m for m in sys.modules if m == pkg or m.startswith(pkg + ".")]:
        del sys.modules[name]
    importlib.invalidate_caches()


def check_package(pkg_dir, cli=None, out=sys.stderr):
    pkg_dir = pathlib.Path(pkg_dir).resolve()
    cli = cli or shutil.which("lean-python")
    sync.sync_package(pkg_dir, cli=cli, out=out)
    root = sync.project_root(pkg_dir)
    ws = root / ".lean-python" / "workspace"

    reimport(pkg_dir.name)
    verify.REGISTRY.clear()
    for path in sorted(pkg_dir.rglob("*.py")):
        rel = path.relative_to(pkg_dir)
        if rel.parts[0] == "_lean" or rel.name == "__main__.py":
            continue
        parts = [pkg_dir.name, *rel.with_suffix("").parts]
        if parts[-1] == "__init__":
            parts = parts[:-1]
        importlib.import_module(".".join(parts))
    specs = list(verify.REGISTRY)

    lib = ws / "LeanPythonLib"
    shutil.rmtree(lib, ignore_errors=True)
    shutil.copytree(pathlib.Path(__file__).parent / "lean" / "LeanPythonLib", lib)
    (ws / "LeanPythonLib.lean").write_text("import LeanPythonLib.Py\n")
    shutil.rmtree(ws / "LeanPythonModel", ignore_errors=True)
    shutil.rmtree(ws / "Proofs", ignore_errors=True)
    proofs_src = root / "lean" / "Proofs"
    if proofs_src.is_dir():
        shutil.copytree(proofs_src, ws / "Proofs")
    else:
        (ws / "Proofs").mkdir()
    (ws / "Proofs" / "Empty.lean").write_text("")
    lakefile = (ws / "lakefile.toml").read_text()
    (ws / "lakefile.toml").write_text(lakefile + LAKEFILE_EXTRA)

    by_module = {}
    for s in specs:
        by_module.setdefault(s.fn.__module__, []).append(s)
    model_modules = []
    obligation_refs = []
    for module, ss in by_module.items():
        tfns = [translate.Fn(s.fn, function_name(s.fn)) for s in ss]
        tr = translate.Translator(tfns)
        model_classes = set()
        for t in tfns:
            for _, ann in t.params:
                _collect_models(ann, model_classes)
            _collect_models(t.hints["return"], model_classes)
        imports = {"LeanPythonLib.Py"}
        imports |= (
            {models.dotted(models.models_namespace(m)) for m in models.modules_source(list(model_classes))}
            if model_classes
            else set()
        )
        defs = []
        for s, t in zip(ss, tfns, strict=True):
            try:
                defs.append(tr.definition(t))
            except translate.TranslateError as e:
                raise sync.SyncError(str(e), 254) from None
            obls, extra = obligations(s, t)
            imports |= extra
            for label, prop in obls.items():
                defs.append(f"abbrev {t.lean_name}.obligation.{label} : Prop :=\n  {prop}")
                obligation_refs.append((s, label))
        missing_models = [m for m in models.modules_source(list(model_classes))] if model_classes else []
        for m in missing_models:
            p = ws / pathlib.Path(*models.models_namespace(m)).with_suffix(".lean")
            if not p.exists():
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(models.modules_source(list(model_classes))[m])
        path = ws / pathlib.Path(*model_module(module)).with_suffix(".lean")
        path.parent.mkdir(parents=True, exist_ok=True)
        head = "".join(f"import {i}\n" for i in sorted(imports))
        path.write_text(head + "\n" + "\n\n".join(defs) + "\n")
        model_modules.append(".".join(model_module(module)))
    (ws / "LeanPythonModel.lean").write_text(
        "".join(f"import {models.dotted(m.split('.'))}\n" for m in model_modules) or "\n"
    )
    (ws / "LeanPythonModels.lean").write_text(
        "".join(
            f"import {models.dotted(p.relative_to(ws).with_suffix('').parts)}\n"
            for p in sorted((ws / "LeanPythonModels").rglob("*.lean"))
        )
        if (ws / "LeanPythonModels").is_dir()
        else "\n"
    )
    proof_modules = [".".join(p.relative_to(ws).with_suffix("").parts) for p in sorted((ws / "Proofs").rglob("*.lean"))]
    (ws / "Proofs.lean").write_text("".join(f"import {models.dotted(m.split('.'))}\n" for m in proof_modules))

    r = subprocess.run(
        ["lake", "build", "LeanPythonLib", "LeanPythonModels", "LeanPythonEmbed", "LeanPythonModel"],
        cwd=ws,
        capture_output=True,
        text=True,
        check=False,
    )
    if r.returncode != 0:
        print(r.stdout + r.stderr, file=out)
        raise sync.SyncError("lake build of the translated functions failed", 254)
    failed_files = {}
    built = []
    for m in proof_modules:
        r = subprocess.run(["lake", "build", m], cwd=ws, capture_output=True, text=True, check=False)
        if r.returncode == 0:
            built.append(m)
            continue
        src = (ws / pathlib.Path(*m.split("."))).with_suffix(".lean")
        failed_files[m] = src.read_text()
        for line in (r.stdout + r.stderr).splitlines():
            if line.startswith(("error:", "  ", "⊢", "case ")) or ": error" in line:
                print(f"lean-py: {line}", file=out)
    proof_modules = built

    obl_file = ws / "obligations.json"
    obl_file.write_text(
        json.dumps([{"model": _plain(function_name(s.fn)), "label": label} for s, label in obligation_refs])
    )
    r = subprocess.run(
        [
            cli,
            "obligations",
            "check",
            "--search-path",
            str(ws / ".lake/build/lib/lean"),
            "--obligations",
            str(obl_file),
            "--modules",
            *model_modules,
            *proof_modules,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if r.returncode != 0:
        print(r.stderr, file=out)
        raise sync.SyncError("lean-python obligations check failed", r.returncode)
    results = json.loads(r.stdout)
    for (s, label), res in zip(obligation_refs, results, strict=True):
        theorem = f"{s.fn.__qualname__}.proof.{label}"
        if res["status"] == "missing" and any(theorem in text for text in failed_files.values()):
            res["status"] = "failed"
    lock = {}
    for (s, label), res in zip(obligation_refs, results, strict=True):
        entry = lock.setdefault(s.qualname, {"hash": source_hash(s.fn), "lean": function_name(s.fn), "obligations": {}})
        entry["obligations"][label] = res["status"]
    (root / "lean-python.lock").write_text(json.dumps(lock, indent=2, sort_keys=True) + "\n")
    return lock, results


def _plain(name):
    return name.replace("«", "").replace("»", "")


def _collect_models(ann, acc):
    import typing

    from pydantic import BaseModel

    while typing.get_origin(ann) is typing.Annotated:
        ann = typing.get_args(ann)[0]
    if isinstance(ann, type) and issubclass(ann, BaseModel):
        acc.add(ann)
        return
    for a in typing.get_args(ann):
        _collect_models(a, acc)


def status(pkg_dir):
    """The lock's states, with ``stale`` for functions whose source changed (no Lean needed)."""
    pkg_dir = pathlib.Path(pkg_dir).resolve()
    root = sync.project_root(pkg_dir)
    lock_path = root / "lean-python.lock"
    lock = json.loads(lock_path.read_text()) if lock_path.exists() else {}
    sys.path.insert(0, str(pkg_dir.parent))
    verify.REGISTRY.clear()
    sync.record_blocks(pkg_dir)
    rows = []
    for s in verify.REGISTRY:
        entry = lock.get(s.qualname)
        labels = list(s.specs())
        if entry is None:
            rows.extend((s.qualname, label, "stale") for label in labels if label != "requires")
            continue
        stale = entry["hash"] != source_hash(s.fn)
        for label, st in entry["obligations"].items():
            rows.append((s.qualname, label, "stale" if stale else st))
    return rows
