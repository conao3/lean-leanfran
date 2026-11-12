"""Translation of a typed, pure Python function into a Lean definition (``lean-py check``).

The body becomes Lean ``do`` notation, which has Python's statements: ``let mut`` for local
variables, ``for``/``while`` with ``break``/``continue``, ``if``, early ``return``. A function that
may fail (indexing, ``//``, ``%``, ``assert``, ``raise``, or a call of such a function) returns
``Py.M α`` (``Except Py.Exc α``); the others return ``α`` through ``Id.run do``. Python's ``int``
is ``Int``; a ``Nat`` parameter is converted to ``Int`` on entry.
"""

import ast
import inspect
import textwrap
import typing

from pydantic import BaseModel

from lean_python import models
from lean_python.types import Nat


class TranslateError(Exception):
    def __init__(self, msg, fn=None, node=None):
        where = ""
        if fn is not None:
            line = fn.__code__.co_firstlineno + (node.lineno - 1 if node is not None and hasattr(node, "lineno") else 0)
            where = f"{fn.__code__.co_filename}:{line}: "
        super().__init__(f"{where}{msg}")


INT, BOOL, STR, FLOAT, NONE = "int", "bool", "str", "float", "none"


def py_type(t, fn):
    """A small type descriptor of a Python annotation."""
    if t is Nat or (typing.get_origin(t) is typing.Annotated and typing.get_args(t)[0] is int):
        return INT
    if t is int:
        return INT
    if t is bool:
        return BOOL
    if t is str:
        return STR
    if t is float:
        return FLOAT
    if t is type(None) or t is None:
        return NONE
    origin = typing.get_origin(t)
    if origin is list:
        return ("list", py_type(typing.get_args(t)[0], fn))
    if origin is tuple:
        return ("tuple", tuple(py_type(a, fn) for a in typing.get_args(t)))
    args = typing.get_args(t)
    if args and type(None) in args and len(args) == 2:
        return ("opt", py_type(next(a for a in args if a is not type(None)), fn))
    if isinstance(t, type) and issubclass(t, BaseModel):
        return ("model", t)
    raise TranslateError(f"unsupported type {t!r}", fn)


def lean_type(t):
    if t == INT:
        return "Int"
    if t == BOOL:
        return "Bool"
    if t == STR:
        return "String"
    if t == FLOAT:
        return "Float"
    if t == NONE:
        return "Unit"
    kind = t[0]
    if kind == "list":
        return f"(List {lean_type(t[1])})"
    if kind == "tuple":
        return "(" + " × ".join(lean_type(a) for a in t[1]) + ")"
    if kind == "opt":
        return f"(Option {lean_type(t[1])})"
    return models.class_name(t[1])


def is_nat(annotation):
    if annotation is Nat:
        return True
    if typing.get_origin(annotation) is typing.Annotated:
        import annotated_types as at

        base, *meta = typing.get_args(annotation)
        return base is int and any(isinstance(m, at.Ge) and m.ge >= 0 for m in meta)
    return False


def field_info(cls, name):
    """The Python type of a model field and whether its Lean field is a `Nat`."""
    f = cls.model_fields.get(name)
    if f is None:
        raise TranslateError(f"{cls.__name__} has no field {name}")
    t = py_type(f.annotation, None)
    nat = False
    if t == INT:
        import annotated_types as at

        lo = [m.ge for m in f.metadata if isinstance(m, at.Ge)] + [m.gt + 1 for m in f.metadata if isinstance(m, at.Gt)]
        nat = is_nat(f.annotation) or (bool(lo) and max(lo) >= 0)
    return t, nat


class Fn:
    """A function to translate: its signature and the names Lean knows it by."""

    def __init__(self, fn, lean_name):
        self.fn = fn
        self.lean_name = lean_name
        self.hints = typing.get_type_hints(fn, include_extras=True)
        sig = inspect.signature(fn)
        self.params = []
        for p in sig.parameters.values():
            if p.name not in self.hints:
                raise TranslateError(f"parameter {p.name} of {fn.__qualname__} has no type annotation", fn)
            self.params.append((p.name, self.hints[p.name]))
        if "return" not in self.hints:
            raise TranslateError(f"{fn.__qualname__} has no return annotation", fn)
        self.ret = py_type(self.hints["return"], fn)
        self.ret_nat = is_nat(self.hints["return"])
        src = textwrap.dedent(inspect.getsource(fn))
        tree = ast.parse(src)
        self.node = next(n for n in tree.body if isinstance(n, ast.FunctionDef))
        self.fails = None


class Translator:
    def __init__(self, fns):
        self.fns = {f.fn.__name__: f for f in fns}
        for f in fns:
            f.fails = self._may_fail(f.node)
        changed = True
        while changed:
            changed = False
            for f in fns:
                if not f.fails and any(
                    isinstance(n, ast.Call)
                    and isinstance(n.func, ast.Name)
                    and n.func.id in self.fns
                    and self.fns[n.func.id].fails
                    for stmt in f.node.body
                    for n in ast.walk(stmt)
                ):
                    f.fails = True
                    changed = True

    def _may_fail(self, node):
        for stmt in node.body:
            for n in ast.walk(stmt):
                if isinstance(n, (ast.Subscript, ast.Assert, ast.Raise)):
                    return True
                if isinstance(n, ast.BinOp) and isinstance(n.op, (ast.FloorDiv, ast.Mod)):
                    return True
        return False

    # -- expressions -------------------------------------------------------

    def expr(self, e, env, fn):
        """Lean source and type of a Python expression."""
        f = fn.fn
        if isinstance(e, ast.Constant):
            v = e.value
            if isinstance(v, bool):
                return ("true" if v else "false"), BOOL
            if isinstance(v, int):
                return (f"({v} : Int)"), INT
            if isinstance(v, str):
                return json_str(v), STR
            if isinstance(v, float):
                return repr(v), FLOAT
            if v is None:
                return "none", ("opt", None)
            raise TranslateError(f"unsupported constant {v!r}", f, e)
        if isinstance(e, ast.Name):
            if e.id not in env:
                raise TranslateError(f"unknown name {e.id}", f, e)
            return lean_ident(e.id), env[e.id]
        if isinstance(e, ast.BinOp):
            a, ta = self.expr(e.left, env, fn)
            b, _ = self.expr(e.right, env, fn)
            op = e.op
            if isinstance(op, ast.Add):
                if ta in (STR,) or (isinstance(ta, tuple) and ta[0] == "list"):
                    return f"({a} ++ {b})", ta
                return f"({a} + {b})", ta
            if isinstance(op, ast.Sub):
                return f"({a} - {b})", ta
            if isinstance(op, ast.Mult):
                return f"({a} * {b})", ta
            if isinstance(op, ast.FloorDiv):
                return f"(← Py.floordiv {a} {b})", INT
            if isinstance(op, ast.Mod):
                return f"(← Py.mod {a} {b})", INT
            raise TranslateError(f"unsupported operator {type(op).__name__}", f, e)
        if isinstance(e, ast.UnaryOp):
            a, ta = self.expr(e.operand, env, fn)
            if isinstance(e.op, ast.USub):
                return f"(-{a})", ta
            if isinstance(e.op, ast.Not):
                return f"(!{a})", BOOL
            raise TranslateError("unsupported unary operator", f, e)
        if isinstance(e, ast.BoolOp):
            parts = [self.expr(v, env, fn)[0] for v in e.values]
            op = " && " if isinstance(e.op, ast.And) else " || "
            return "(" + op.join(parts) + ")", BOOL
        if isinstance(e, ast.Compare):
            parts = []
            left, _ = self.expr(e.left, env, fn)
            for op, right in zip(e.ops, e.comparators, strict=True):
                r, _ = self.expr(right, env, fn)
                if isinstance(op, ast.In):
                    parts.append(f"({r}.contains {left})")
                elif isinstance(op, ast.NotIn):
                    parts.append(f"(!{r}.contains {left})")
                else:
                    sym = {ast.Eq: "==", ast.NotEq: "!=", ast.Lt: "<", ast.LtE: "≤", ast.Gt: ">", ast.GtE: "≥"}.get(
                        type(op)
                    )
                    if sym is None:
                        raise TranslateError("unsupported comparison", f, e)
                    parts.append(f"({left} {sym} {r})" if sym in ("==", "!=") else f"(decide ({left} {sym} {r}))")
                left = r
            return "(" + " && ".join(parts) + ")", BOOL
        if isinstance(e, ast.IfExp):
            c, _ = self.expr(e.test, env, fn)
            a, ta = self.expr(e.body, env, fn)
            b, _ = self.expr(e.orelse, env, fn)
            return f"(if {c} then {a} else {b})", ta
        if isinstance(e, ast.Attribute):
            obj, to = self.expr(e.value, env, fn)
            if isinstance(to, tuple) and to[0] == "model":
                t, nat = field_info(to[1], e.attr)
                s = f"{obj}.{lean_ident(e.attr)}"
                return (f"({s} : Int)" if nat else s), t
            raise TranslateError(f"attribute {e.attr} of a non-model value", f, e)
        if isinstance(e, ast.Subscript):
            obj, to = self.expr(e.value, env, fn)
            if isinstance(to, tuple) and to[0] == "tuple" and isinstance(e.slice, ast.Constant):
                i = e.slice.value
                n = len(to[1])
                proj = obj
                for _ in range(i):
                    proj = f"{proj}.2"
                if i < n - 1:
                    proj = f"{proj}.1"
                return proj, to[1][i]
            if isinstance(to, tuple) and to[0] == "list":
                i, _ = self.expr(e.slice, env, fn)
                return f"(← Py.getItem {obj} {i})", to[1]
            raise TranslateError("unsupported subscript", f, e)
        if isinstance(e, ast.Tuple):
            parts = [self.expr(v, env, fn) for v in e.elts]
            return "(" + ", ".join(p for p, _ in parts) + ")", ("tuple", tuple(t for _, t in parts))
        if isinstance(e, ast.List):
            parts = [self.expr(v, env, fn) for v in e.elts]
            t = parts[0][1] if parts else INT
            return "[" + ", ".join(p for p, _ in parts) + "]", ("list", t)
        if isinstance(e, ast.ListComp):
            return self.listcomp(e, env, fn)
        if isinstance(e, ast.Call):
            return self.call(e, env, fn)
        raise TranslateError(f"unsupported expression {type(e).__name__}", f, e)

    def listcomp(self, e, env, fn):
        if len(e.generators) != 1 or e.generators[0].is_async or not isinstance(e.generators[0].target, ast.Name):
            raise TranslateError("only list comprehensions with one `for x in ...` are supported", fn.fn, e)
        g = e.generators[0]
        src, ts = self.iterable(g.iter, env, fn)
        x = g.target.id
        inner = {**env, x: ts}
        for cond in g.ifs:
            c, _ = self.expr(cond, inner, fn)
            src = f"({src}.filter (fun {lean_ident(x)} => {c}))"
        body, t_body = self.expr(e.elt, inner, fn)
        if "←" in body:
            raise TranslateError("a list comprehension must not fail", fn.fn, e)
        return f"({src}.map (fun {lean_ident(x)} => {body}))", ("list", t_body)

    def iterable(self, e, env, fn):
        if isinstance(e, ast.Call) and isinstance(e.func, ast.Name) and e.func.id == "range":
            args = [self.expr(a, env, fn)[0] for a in e.args]
            if len(args) == 1:
                return f"(Py.range 0 {args[0]})", INT
            if len(args) == 2:
                return f"(Py.range {args[0]} {args[1]})", INT
            raise TranslateError("range with a step is not supported", fn.fn, e)
        src, t = self.expr(e, env, fn)
        if isinstance(t, tuple) and t[0] == "list":
            return src, t[1]
        raise TranslateError("iteration over a non-list", fn.fn, e)

    def call(self, e, env, fn):
        f = fn.fn
        if e.keywords and not (isinstance(e.func, ast.Name) and e.func.id not in ("len", "abs", "min", "max", "sum")):
            raise TranslateError("keyword arguments are not supported", f, e)
        if isinstance(e.func, ast.Name):
            name = e.func.id
            args = [self.expr(a, env, fn) for a in e.args]
            if name == "len":
                ((a, ta),) = args
                return (f"(Py.strLen {a})" if ta == STR else f"(Py.len {a})"), INT
            if name == "abs":
                return f"(Py.abs {args[0][0]})", INT
            if name in ("min", "max") and len(args) == 2:
                return f"({name} {args[0][0]} {args[1][0]})", args[0][1]
            if name == "sum":
                return f"(Py.sum {args[0][0]})", INT
            if name in self.fns:
                target = self.fns[name]
                call = f"({target.lean_name} {' '.join(self.arg_for(target, i, a) for i, (a, _) in enumerate(args))})"
                return (f"(← {call})" if target.fails else call), target.ret
        raise TranslateError("unsupported call (only len, abs, min, max, sum and @model functions of the module)", f, e)

    def arg_for(self, target, i, a):
        if is_nat(target.params[i][1]):
            return f"({a}).toNat"
        return a

    # -- statements --------------------------------------------------------

    def body(self, stmts, env, fn, indent, declared):
        out = []
        pad = "  " * indent
        for s in stmts:
            if isinstance(s, ast.Return):
                if s.value is None:
                    raise TranslateError("a function must return a value", fn.fn, s)
                v, _ = self.expr(s.value, env, fn)
                out.append(f"{pad}return {v}")
            elif isinstance(s, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
                out.extend(self.assign(s, env, fn, pad, declared))
            elif isinstance(s, ast.If):
                c, _ = self.expr(s.test, env, fn)
                out.append(f"{pad}if {c} then")
                out.extend(self.body(s.body, env, fn, indent + 1, declared) or [f"{pad}  pure ()"])
                if s.orelse:
                    out.append(f"{pad}else")
                    out.extend(self.body(s.orelse, env, fn, indent + 1, declared))
            elif isinstance(s, ast.For):
                if not isinstance(s.target, ast.Name):
                    raise TranslateError("only `for x in ...` is supported", fn.fn, s)
                src, t = self.iterable(s.iter, env, fn)
                inner = dict(env)
                inner[s.target.id] = t
                out.append(f"{pad}for {lean_ident(s.target.id)} in {src} do")
                out.extend(self.body(s.body, inner, fn, indent + 1, declared) or [f"{pad}  pure ()"])
            elif isinstance(s, ast.While):
                c, _ = self.expr(s.test, env, fn)
                out.append(f"{pad}while {c} do")
                out.extend(self.body(s.body, env, fn, indent + 1, declared) or [f"{pad}  pure ()"])
            elif isinstance(s, ast.Break):
                out.append(f"{pad}break")
            elif isinstance(s, ast.Continue):
                out.append(f"{pad}continue")
            elif isinstance(s, ast.Pass):
                out.append(f"{pad}pure ()")
            elif isinstance(s, ast.Assert):
                c, _ = self.expr(s.test, env, fn)
                out.append(f"{pad}Py.assert {c}")
            elif isinstance(s, ast.Raise):
                msg = '""'
                if isinstance(s.exc, ast.Call) and s.exc.args and isinstance(s.exc.args[0], ast.Constant):
                    msg = json_str(str(s.exc.args[0].value))
                out.append(f"{pad}throw (.valueError {msg})")
            elif (
                isinstance(s, ast.Expr)
                and isinstance(s.value, ast.Call)
                and isinstance(s.value.func, ast.Attribute)
                and s.value.func.attr == "append"
            ):
                target = s.value.func.value
                if not (isinstance(target, ast.Name) and target.id in declared):
                    raise TranslateError("append only to a list created in the function", fn.fn, s)
                v, _ = self.expr(s.value.args[0], env, fn)
                out.append(f"{pad}{lean_ident(target.id)} := {lean_ident(target.id)} ++ [{v}]")
            elif isinstance(s, ast.Expr) and isinstance(s.value, ast.Constant) and isinstance(s.value.value, str):
                continue
            else:
                raise TranslateError(f"unsupported statement {type(s).__name__}", fn.fn, s)
        return out

    def assign(self, s, env, fn, pad, declared):
        if isinstance(s, ast.AugAssign):
            target = s.target
            op = {ast.Add: "+", ast.Sub: "-", ast.Mult: "*"}.get(type(s.op))
            if not isinstance(target, ast.Name) or target.id not in declared:
                raise TranslateError("augmented assignment to an undefined local", fn.fn, s)
            v, tv = self.expr(s.value, env, fn)
            t = env[target.id]
            if op == "+" and (t == STR or (isinstance(t, tuple) and t[0] == "list")):
                op = "++"
            if op is None:
                if isinstance(s.op, ast.FloorDiv):
                    return [f"{pad}{lean_ident(target.id)} := (← Py.floordiv {lean_ident(target.id)} {v})"]
                if isinstance(s.op, ast.Mod):
                    return [f"{pad}{lean_ident(target.id)} := (← Py.mod {lean_ident(target.id)} {v})"]
                raise TranslateError("unsupported augmented assignment", fn.fn, s)
            return [f"{pad}{lean_ident(target.id)} := {lean_ident(target.id)} {op} {v}"]
        targets = [s.target] if isinstance(s, ast.AnnAssign) else s.targets
        if len(targets) != 1:
            raise TranslateError("chained assignment is not supported", fn.fn, s)
        target = targets[0]
        v, tv = self.expr(s.value, env, fn)
        if isinstance(s, ast.AnnAssign):
            tv = py_type(eval(compile(ast.Expression(s.annotation), "<annotation>", "eval"), fn.fn.__globals__), fn.fn)
        names = [target] if isinstance(target, ast.Name) else (target.elts if isinstance(target, ast.Tuple) else None)
        if names is None or not all(isinstance(n, ast.Name) for n in names):
            raise TranslateError("only assignment to names is supported", fn.fn, s)
        if isinstance(target, ast.Tuple):
            types = tv[1] if isinstance(tv, tuple) and tv[0] == "tuple" else [None] * len(names)
            out = []
            tmp = "__t"
            out.append(f"{pad}let {tmp} := {v}")
            for i, (n, t) in enumerate(zip(names, types, strict=True)):
                proj = tmp + ".2" * i + (".1" if i < len(names) - 1 else "")
                out.extend(self._bind(n.id, proj, t, env, pad, declared))
            return out
        return self._bind(target.id, v, tv, env, pad, declared)

    def _bind(self, name, v, t, env, pad, declared):
        if name in declared:
            return [f"{pad}{lean_ident(name)} := {v}"]
        declared.add(name)
        env[name] = t
        ty = f" : {lean_type(t)}" if t is not None and not (isinstance(t, tuple) and t[1] is None) else ""
        return [f"{pad}let mut {lean_ident(name)}{ty} := {v}"]

    # -- definitions -------------------------------------------------------

    def definition(self, fn):
        env = {}
        binders = []
        prelude = []
        for name, ann in fn.params:
            t = py_type(ann, fn.fn)
            env[name] = t
            if is_nat(ann):
                binders.append(f"({lean_ident(name)} : Nat)")
                prelude.append(f"  let {lean_ident(name)} : Int := {lean_ident(name)}")
            else:
                binders.append(f"({lean_ident(name)} : {lean_type(t)})")
        declared = set()
        ret = lean_type(fn.ret)
        rty = f"Py.M {ret}" if fn.fails else ret
        head = "do" if fn.fails else "Id.run do"
        lines = self.body(fn.node.body, env, fn, 1, declared)
        doc = f"/-- `{fn.fn.__module__}.{fn.fn.__qualname__}`, translated from Python. -/"
        return "\n".join([doc, f"def {fn.lean_name} {' '.join(binders)} : {rty} := {head}", *prelude, *lines])


def lean_ident(name):
    return models.ident(name)


def json_str(s):
    out = '"'
    for c in s:
        if c == '"':
            out += '\\"'
        elif c == "\\":
            out += "\\\\"
        elif c == "\n":
            out += "\\n"
        else:
            out += c
    return out + '"'
