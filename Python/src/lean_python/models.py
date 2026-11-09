"""Lean structures for the user's pydantic models (``lean(..., models=[...])``).

A model becomes a ``structure`` named ``LeanPythonModels.<python module>.<class>``. Field
constraints that Lean can state (``ge``/``gt``/``le``/``lt`` on ``int``, ``min_length``/``max_length``
on ``str`` and ``list``) become proof fields, so Lean proofs may assume them; an ``int`` field with
a lower bound of at least 0 becomes a ``Nat``. Other constraints and validators are listed in the
structure's docstring and are not assumed.

Other field types: an ``enum.Enum`` becomes an inductive type ``LeanPythonModels.<module>.<class>``
with a constructor per member; ``Literal["a", "b"]`` becomes ``LeanPythonLiterals.<module>.<model>_<field>``;
a union of models becomes ``LeanPythonUnions.<module>.<model>_<field>`` with a constructor per model.
"""

import enum
import re
import types
import typing

import annotated_types as at
from pydantic import BaseModel

LEAN_KEYWORDS = {
    "at", "by", "do", "else", "end", "fun", "have", "if", "in", "let", "match", "mut", "namespace", "open",
    "section", "then", "theorem", "def", "structure", "inductive", "where", "with", "from", "import",
    "instance", "class", "variable", "universe", "deriving", "show", "calc", "for", "return", "try",
    "catch", "finally", "unless", "break", "continue", "macro", "syntax", "local", "private", "protected",
    "partial", "unsafe", "noncomputable", "abbrev", "example", "axiom", "opaque", "extends", "notation",
    "Type", "Sort", "Prop",
}  # fmt: skip

_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_']*$")


class ModelError(Exception):
    pass


def ident(s):
    """A Lean identifier component, escaped with «» when needed."""
    if _IDENT.match(s) and s not in LEAN_KEYWORDS:
        return s
    return f"«{s}»"


def dotted(parts):
    return ".".join(ident(p) for p in parts)


def models_namespace(module):
    return ["LeanPythonModels", *module.split(".")]


def _strip_annotated(t):
    metadata = []
    while typing.get_origin(t) is typing.Annotated:
        args = typing.get_args(t)
        t = args[0]
        metadata.extend(args[1:])
    return t, metadata


def _flatten(metadata):
    out = []
    for m in metadata:
        if isinstance(m, at.Interval):
            for v, c in ((m.gt, at.Gt), (m.ge, at.Ge), (m.lt, at.Lt), (m.le, at.Le)):
                if v is not None:
                    out.append(c(v))
        elif isinstance(m, at.Len):
            if m.min_length:
                out.append(at.MinLen(m.min_length))
            if m.max_length is not None:
                out.append(at.MaxLen(m.max_length))
        else:
            out.append(m)
    return out


def _is_model(t):
    return isinstance(t, type) and issubclass(t, BaseModel)


def _is_enum(t):
    return isinstance(t, type) and issubclass(t, enum.Enum)


def _union_args(t):
    if typing.get_origin(t) in (typing.Union, types.UnionType):
        return typing.get_args(t)
    return None


class Collector:
    """The models and enums reachable from the roots, dependencies first."""

    def __init__(self, roots):
        self.order = []
        self.seen = set()
        self.in_progress = set()
        for cls in roots:
            self.add(cls)

    def add(self, cls):
        if cls in self.seen:
            return
        if cls in self.in_progress:
            raise ModelError(f"recursive models are not supported: {cls.__qualname__}")
        self.in_progress.add(cls)
        if _is_model(cls):
            for f in cls.model_fields.values():
                self._visit(f.annotation)
        self.in_progress.discard(cls)
        self.seen.add(cls)
        self.order.append(cls)

    def _visit(self, t):
        t, _ = _strip_annotated(t)
        if _is_model(t) or _is_enum(t):
            self.add(t)
            return
        for a in typing.get_args(t):
            if not isinstance(a, str):
                self._visit(a)


def class_name(cls):
    return dotted([*models_namespace(cls.__module__), cls.__qualname__])


class Context:
    """Declarations a model's fields need before its structure (literal and union types)."""

    def __init__(self, model):
        self.model = model
        self.decls = []

    def literal(self, field, values):
        if not all(isinstance(v, str) for v in values):
            raise ModelError(f"{self.model.__qualname__}.{field}: only Literal of strings is supported")
        name = dotted(["LeanPythonLiterals", *self.model.__module__.split("."), f"{self.model.__qualname__}_{field}"])
        ctors = "\n".join(f"  | {ident(v)}" for v in values)
        self.decls.append(f"inductive {name} where\n{ctors}")
        return name

    def union(self, field, classes):
        name = dotted(["LeanPythonUnions", *self.model.__module__.split("."), f"{self.model.__qualname__}_{field}"])
        ctors = "\n".join(f"  | {ident(c.__qualname__)} (val : {class_name(c)})" for c in classes)
        self.decls.append(f"inductive {name} where\n{ctors}")
        return name


def lean_type(t, ctx, field):
    t, metadata = _strip_annotated(t)
    if metadata:
        base, _ = lean_field_type(t, _flatten(metadata), ctx, field)
        return base
    origin = typing.get_origin(t)
    if t is int:
        return "Int"
    if t is bool:
        return "Bool"
    if t is str:
        return "String"
    if t is float:
        return "Float"
    if t is type(None):
        return "Unit"
    if origin is list:
        (a,) = typing.get_args(t)
        return f"(List {lean_type(a, ctx, field)})"
    if origin is tuple:
        args = typing.get_args(t)
        if len(args) < 2 or Ellipsis in args:
            raise ModelError(f"{ctx.model.__qualname__}.{field}: only tuples of fixed length 2 or more are supported")
        return "(" + " × ".join(lean_type(a, ctx, field) for a in args) + ")"
    if origin is typing.Literal:
        return ctx.literal(field, typing.get_args(t))
    args = _union_args(t)
    if args is not None:
        rest = [a for a in args if a is not type(None)]
        inner = rest[0] if len(rest) == 1 else None
        if inner is None:
            if not all(_is_model(_strip_annotated(a)[0]) for a in rest):
                raise ModelError(
                    f"{ctx.model.__qualname__}.{field}: only `T | None` and unions of models are supported"
                )
            inner_t = ctx.union(field, [_strip_annotated(a)[0] for a in rest])
        else:
            inner_t = lean_type(inner, ctx, field)
        return f"(Option {inner_t})" if len(rest) < len(args) else inner_t
    if _is_model(t) or _is_enum(t):
        return class_name(t)
    raise ModelError(f"{ctx.model.__qualname__}.{field}: unsupported field type {t!r}")


def lean_field_type(t, constraints, ctx, name):
    """The Lean type of a field and its proof fields as ``(suffix, proposition)``."""
    t, inner = _strip_annotated(t)
    constraints = _flatten(constraints) + _flatten(inner)
    proofs = []
    unmapped = []
    if t is int:
        lo = None
        for c in constraints:
            if isinstance(c, at.Ge):
                lo = c.ge if lo is None else max(lo, c.ge)
            elif isinstance(c, at.Gt):
                lo = c.gt + 1 if lo is None else max(lo, c.gt + 1)
        nat = lo is not None and lo >= 0
        base = "Nat" if nat else "Int"

        def lit(v):
            return str(v) if nat else f"({v} : Int)"

        for c in constraints:
            if isinstance(c, at.Ge):
                if not (nat and c.ge == 0):
                    proofs.append(("ge", f"{lit(c.ge)} ≤ {ident(name)}"))
            elif isinstance(c, at.Gt):
                if not (nat and c.gt == -1):
                    proofs.append(("gt", f"{lit(c.gt)} < {ident(name)}"))
            elif isinstance(c, at.Le):
                proofs.append(("le", f"{ident(name)} ≤ {lit(c.le)}"))
            elif isinstance(c, at.Lt):
                proofs.append(("lt", f"{ident(name)} < {lit(c.lt)}"))
            else:
                unmapped.append(repr(c))
        return base, (proofs, unmapped)
    base = lean_type(t, ctx, name)
    for c in constraints:
        if isinstance(c, at.MinLen) and (t is str or typing.get_origin(t) is list):
            proofs.append(("min_length", f"{c.min_length} ≤ {ident(name)}.length"))
        elif isinstance(c, at.MaxLen) and (t is str or typing.get_origin(t) is list):
            proofs.append(("max_length", f"{ident(name)}.length ≤ {c.max_length}"))
        else:
            unmapped.append(repr(c))
    return base, (proofs, unmapped)


def enum_source(cls):
    ctors = "\n".join(f"  | {ident(m.name)}" for m in cls)
    return f"/-- The enum `{cls.__module__}.{cls.__qualname__}`. -/\ninductive {class_name(cls)} where\n{ctors}"


def structure(cls):
    ctx = Context(cls)
    fields = []
    unmapped_all = []
    for name, f in cls.model_fields.items():
        if f.alias is not None and f.alias != name:
            raise ModelError(f"{cls.__qualname__}.{name}: aliases are not supported")
        base, (proofs, unmapped) = lean_field_type(f.annotation, list(f.metadata), ctx, name)
        fields.append(f"  {ident(name)} : {base}")
        for suffix, prop in proofs:
            fields.append(f"  {ident(name + '_' + suffix)} : {prop}")
        unmapped_all.extend(f"{name}: {u}" for u in unmapped)
    decorators = cls.__pydantic_decorators__
    validators = [*decorators.field_validators, *decorators.model_validators]
    doc = [f"The pydantic model `{cls.__module__}.{cls.__qualname__}`."]
    if unmapped_all or validators:
        doc.append("Not assumed in Lean: " + ", ".join([*unmapped_all, *(f"validator {v}" for v in validators)]) + ".")
    lines = [*ctx.decls, f"/-- {' '.join(doc)} -/", f"structure {class_name(cls)} where", *fields]
    return "\n\n".join(lines[: len(ctx.decls)] + ["\n".join(lines[len(ctx.decls) :])])


def modules_source(roots):
    """Lean source per Python module of the models (and the models and enums their fields use)."""
    order = Collector(roots).order
    by_module = {}
    for cls in order:
        by_module.setdefault(cls.__module__, []).append(cls)
    out = {}
    for module, classes in by_module.items():
        deps = sorted({c.__module__ for cls in classes for c in _referenced(cls)} - {module})
        header = "".join(f"import {dotted(models_namespace(d))}\n" for d in deps)
        body = "\n\n".join(enum_source(c) if _is_enum(c) else structure(c) for c in classes)
        out[module] = f"{header}\n{body}\n"
    return out


def _referenced(cls):
    found = []
    if not _is_model(cls):
        return found

    def visit(t):
        t, _ = _strip_annotated(t)
        if _is_model(t) or _is_enum(t):
            found.append(t)
            return
        for a in typing.get_args(t):
            if not isinstance(a, str):
                visit(a)

    for f in cls.model_fields.values():
        visit(f.annotation)
    return found
