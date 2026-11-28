"""``translate``: the ``@model`` functions of a package as Lean, for ``leanfran --lang python check``.

The package is imported as usual, after ``sync`` placed its generated modules, so the
specifications are the functions of the generated modules. Every function becomes a definition of
``LeanPythonModel.<module>`` with one obligation per label (``<function>.obligation.<label>``); the
proofs in ``lean/Proofs/`` prove ``<function>.proof.<label>``.
"""

import ast
import pathlib

from leanfran import models, scan, translate, verify


def model_module(module):
    return ["LeanPythonModel", *module.split(".")]


def function_name(fn):
    return models.dotted([*model_module(fn.__module__), fn.__qualname__])


def plain(name):
    return name.replace("«", "").replace("»", "")


def lean_name_of(spec_fn, label, fn):
    name = getattr(spec_fn, "__lean_name__", None)
    if name is None:
        raise translate.TranslateError(f"the {label} specification is not a function of a lean(...) block", fn)
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


def located(root, spec, error):
    fn = spec.fn
    file = error.file or fn.__code__.co_filename
    line = error.line or fn.__code__.co_firstlineno
    return {"file": scan.relative(root, file), "line": line, "column": error.column, "message": error.message}


def calls(tfn, by_name):
    return sorted(
        {
            by_name[n.func.id]
            for stmt in tfn.node.body
            for n in ast.walk(stmt)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in by_name
        }
    )


def translate_package(root, request):
    root = pathlib.Path(root).resolve()
    pkg_dir = root / request["scan"]["scope"][0]
    wanted = {f["id"] for f in request["scan"]["functions"]}
    verify.REGISTRY.clear()
    scan.import_package(root, pkg_dir)
    specs = [s for s in scan.model_specs(pkg_dir) if s.qualname in wanted]

    by_module = {}
    for s in specs:
        by_module.setdefault(s.fn.__module__, []).append(s)
    modules = []
    functions = []
    for module, ss in sorted(by_module.items()):
        errors = {}
        tfns = {}
        for s in ss:
            try:
                tfns[s.qualname] = translate.Fn(s.fn, function_name(s.fn))
            except translate.TranslateError as e:
                errors[s.qualname] = located(root, s, e)
        tr = translate.Translator(list(tfns.values()))
        ids = {s.fn.__name__: s.qualname for s in ss}
        dependencies = {q: [d for d in calls(t, ids) if d != q] for q, t in tfns.items()}
        texts = {}
        imports = {"LeanPythonLib.Py"}
        model_classes = set()
        for s in ss:
            t = tfns.get(s.qualname)
            if t is None:
                continue
            try:
                definition = tr.definition(t)
                obls, extra = obligations(s, t)
            except translate.TranslateError as e:
                errors[s.qualname] = located(root, s, e)
                continue
            for _, ann in t.params:
                scan.collect_models(ann, model_classes)
            scan.collect_models(t.hints["return"], model_classes)
            imports |= extra
            texts[s.qualname] = "\n\n".join(
                [
                    definition,
                    *(f"abbrev {t.lean_name}.obligation.{label} : Prop :=\n  {prop}" for label, prop in obls.items()),
                ]
            )
        excluded = set(errors)
        grew = True
        while grew:
            grew = False
            for q, deps in dependencies.items():
                if q not in excluded and any(d in excluded for d in deps):
                    excluded.add(q)
                    grew = True
        if model_classes:
            imports |= {models.dotted(models.models_namespace(m)) for m in models.modules_source(list(model_classes))}
        defined = [s.qualname for s in ss if s.qualname in texts and s.qualname not in excluded]
        if defined:
            head = "".join(f"import {i}\n" for i in sorted(imports))
            modules.append(
                {
                    "module": ".".join(model_module(module)),
                    "path": pathlib.PurePosixPath(*model_module(module)).with_suffix(".lean").as_posix(),
                    "text": head + "\n" + "\n\n".join(texts[q] for q in defined) + "\n",
                    "functions": defined,
                }
            )
        for s in ss:
            entry = {
                "id": s.qualname,
                "model": plain(function_name(s.fn)),
                "dependencies": dependencies.get(s.qualname, []),
            }
            if s.qualname in errors:
                entry["error"] = errors[s.qualname]
            functions.append(entry)

    aggregates = []
    if modules:
        aggregates.append(
            {
                "module": "LeanPythonModel",
                "path": "LeanPythonModel.lean",
                "text": "".join(f"import {m['module']}\n" for m in modules),
            }
        )
    return {"format": 1, "modules": modules, "aggregates": aggregates, "functions": functions}
