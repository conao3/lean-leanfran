"""Conversion between Python values and the runtime's Lean values, and the pydantic types of Lean types.

Generated modules describe each public type with a descriptor (``NAT``, ``ListD(...)``, ``NamedD``)
and each structure and constructor with a ``CtorInfo``. Values going to Lean are checked against
the Lean type (ranges, invariants) while they are converted; values coming back are built with
``model_construct``, since a Lean value already satisfies its invariants.
"""

import enum
import json
from typing import Annotated, Any, ClassVar

import pydantic
from pydantic import AfterValidator, BaseModel, ConfigDict, GetCoreSchemaHandler, GetJsonSchemaHandler
from pydantic_core import PydanticCustomError, SchemaSerializer, SchemaValidator, ValidationError, core_schema

from leanfran.runtime import _RC, PERSISTENT, Ctor, LArray, _f32, _list_to_py, _py_to_list, lean_dec, lean_inc

Field = pydantic.Field
"""Used by generated models for the field options (``alias``, ``exclude_if``)."""


class LeanIOError(OSError):
    """An `IO.Error` raised by a Lean `IO` action."""


class _Fail(Exception):
    def __init__(self, msg, value, loc=()):
        super().__init__(msg)
        self.msg = msg
        self.value = value
        self.loc = loc


def _fail(msg, value):
    raise _Fail(msg, value)


def _validation_error(title, f):
    return ValidationError.from_exception_data(
        title,
        [{"type": PydanticCustomError("lean_type", f.msg), "loc": f.loc, "input": f.value}],
    )


# ---------------------------------------------------------------------------
# Descriptors


class Desc:
    def to_lean(self, v):
        raise NotImplementedError

    def to_py(self, x):
        raise NotImplementedError

    def key(self):
        """A value equal for the descriptors of the same Lean type (also across generated modules)."""
        return (self.__class__,)


def _is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


class _Nat(Desc):
    def to_lean(self, v):
        if not _is_int(v):
            _fail("expected an int (Lean `Nat`)", v)
        if v < 0:
            _fail("expected a non-negative int (Lean `Nat`)", v)
        return v

    def to_py(self, x):
        return x


class _Int(Desc):
    def to_lean(self, v):
        if not _is_int(v):
            _fail("expected an int (Lean `Int`)", v)
        return v

    def to_py(self, x):
        return x


class UIntD(Desc):
    def __init__(self, bits):
        self.bits = bits
        self.limit = 1 << bits

    def key(self):
        return (UIntD, self.bits)

    def to_lean(self, v):
        if not _is_int(v) or not 0 <= v < self.limit:
            _fail(f"expected an int in [0, 2^{self.bits}) (Lean `UInt{self.bits}`)", v)
        return v

    def to_py(self, x):
        return x


class SIntD(Desc):
    def __init__(self, bits):
        self.bits = bits
        self.half = 1 << (bits - 1)
        self.mask = (1 << bits) - 1

    def key(self):
        return (SIntD, self.bits)

    def to_lean(self, v):
        if not _is_int(v) or not -self.half <= v < self.half:
            _fail(f"expected an int in [-2^{self.bits - 1}, 2^{self.bits - 1}) (Lean `Int{self.bits}`)", v)
        return v & self.mask

    def to_py(self, x):
        return x - (1 << self.bits) if x >= self.half else x


class FinD(Desc):
    def __init__(self, n):
        self.n = n

    def key(self):
        return (FinD, self.n)

    def to_lean(self, v):
        if not _is_int(v) or not 0 <= v < self.n:
            _fail(f"expected an int in [0, {self.n}) (Lean `Fin {self.n}`)", v)
        return v

    def to_py(self, x):
        return x


class _Bool(Desc):
    def to_lean(self, v):
        if not isinstance(v, bool):
            _fail("expected a bool", v)
        return 1 if v else 0

    def to_py(self, x):
        return bool(x)


class _Char(Desc):
    def to_lean(self, v):
        if not isinstance(v, str) or len(v) != 1:
            _fail("expected a str of one character (Lean `Char`)", v)
        c = ord(v)
        if 0xD800 <= c <= 0xDFFF:
            _fail("a surrogate is not a Lean `Char`", v)
        return c

    def to_py(self, x):
        return chr(x)


class _String(Desc):
    def to_lean(self, v):
        if not isinstance(v, str):
            _fail("expected a str", v)
        try:
            return v.encode("utf-8")
        except UnicodeEncodeError:
            _fail("a str with a surrogate is not a Lean `String`", v)

    def to_py(self, x):
        return x.decode("utf-8")


class _Float(Desc):
    def to_lean(self, v):
        if isinstance(v, bool) or not isinstance(v, (int, float)):
            _fail("expected a float", v)
        return float(v)

    def to_py(self, x):
        return x


class _Float32(_Float):
    def to_lean(self, v):
        return _f32(super().to_lean(v))


class _Unit(Desc):
    def to_lean(self, v):
        if v is not None:
            _fail("expected None (Lean `Unit`)", v)
        return 0

    def to_py(self, x):
        return None


def _at(i, f):
    f.loc = (i, *f.loc)
    return f


class ListD(Desc):
    def __init__(self, d):
        self.d = d

    def key(self):
        return (self.__class__, self.d.key())

    def _items(self, v):
        if not isinstance(v, (list, tuple)):
            _fail("expected a list", v)
        out = []
        for i, x in enumerate(v):
            try:
                out.append(self.d.to_lean(x))
            except _Fail as f:
                raise _at(i, f) from None
        return out

    def to_lean(self, v):
        return _py_to_list(self._items(v))

    def to_py(self, x):
        return [self.d.to_py(e) for e in _list_to_py(x)]


class ArrayD(ListD):
    def to_lean(self, v):
        return LArray(self._items(v))

    def to_py(self, x):
        return [self.d.to_py(e) for e in x.data]


class OptionD(Desc):
    def __init__(self, d):
        self.d = d

    def key(self):
        return (OptionD, self.d.key())

    def to_lean(self, v):
        if v is None:
            return 0
        return Ctor(1, [self.d.to_lean(v)])

    def to_py(self, x):
        if isinstance(x, int):
            return None
        return self.d.to_py(x.objs[0])


class ProdD(Desc):
    def __init__(self, a, b):
        self.a = a
        self.b = b

    def key(self):
        return (ProdD, self.a.key(), self.b.key())

    def to_lean(self, v):
        if not isinstance(v, (tuple, list)) or len(v) != 2:
            _fail("expected a pair", v)
        try:
            a = self.a.to_lean(v[0])
        except _Fail as f:
            raise _at(0, f) from None
        try:
            b = self.b.to_lean(v[1])
        except _Fail as f:
            raise _at(1, f) from None
        return Ctor(0, [a, b])

    def to_py(self, x):
        return (self.a.to_py(x.objs[0]), self.b.to_py(x.objs[1]))


class NamedD(Desc):
    """A generated type, looked up by name in the generated module (types may be recursive)."""

    def __init__(self, g, name):
        self.g = g
        self.name = name
        self._info = None

    def info(self):
        if self._info is None:
            first, *rest = self.name.split(".")
            t = self.g[first]
            for r in rest:
                t = getattr(t, r)
            meta = getattr(t, "__metadata__", ())
            infos = [m for m in meta if isinstance(m, SubtypeInfo)]
            self._info = infos[0] if infos else t.__lean__
        return self._info

    def key(self):
        return (NamedD, id(self.info()))

    def to_lean(self, v):
        return self.info().to_lean(v)

    def to_py(self, x):
        return self.info().to_py(x)


NAT = _Nat()
INT = _Int()
BOOL = _Bool()
CHAR = _Char()
STRING = _String()
FLOAT = _Float()
FLOAT32 = _Float32()
UNIT = _Unit()


def to_lean(desc, v, name):
    try:
        return desc.to_lean(v)
    except _Fail as f:
        f.loc = (name, *f.loc)
        raise _validation_error("leanfran-python", f) from None


def to_py(desc, x):
    return desc.to_py(x)


# ---------------------------------------------------------------------------
# Handles: Lean values kept without converting them

_SHARED = PERSISTENT // 2


def _share(x):
    """Marks ``x`` and what it reaches as never updated in place (a persistent reference count),
    stopping at objects that are already marked."""
    stack = [x]
    while stack:
        o = stack.pop()
        c = o.__class__
        if c is Ctor:
            if o.rc < _SHARED:
                o.rc = PERSISTENT
                stack.extend(o.objs)
        elif c is LArray:
            if o.rc < _SHARED:
                o.rc = PERSISTENT
                stack.extend(o.data)
        elif c in _RC:
            o.rc = PERSISTENT
    return x


class LeanType:
    """A Lean type of a public function: ``new`` makes a handle of a Python value."""

    __slots__ = ("desc", "python")

    def __init__(self, desc, python):
        self.desc = desc
        self.python = python

    def new(self, value):
        """The handle of the Lean value of ``value``, checked like an argument."""
        return Lean(self, _share(to_lean(self.desc, value, "value")))

    def new_local(self, value):
        """The local handle of the Lean value of ``value``, checked like an argument."""
        return Local(self, to_lean(self.desc, value, "value"))

    def __eq__(self, other):
        return isinstance(other, LeanType) and self.desc.key() == other.desc.key()

    def __hash__(self):
        return hash(self.desc.key())

    def __repr__(self):
        return f"LeanType({self.python})"


class Lean[T]:
    """A Lean value kept as the runtime's object, without converting it to a Python value.

    The ``lean`` attribute of a generated function takes handles (or Python values) and returns a
    handle; ``get`` converts a handle to the Python value. A handle is immutable.
    """

    __slots__ = ("_obj", "type")

    def __init__(self, type_, obj):
        self.type = type_
        self._obj = obj

    def get(self) -> T:
        """The Python value of the handle."""
        return self.type.desc.to_py(self._obj)

    def __repr__(self):
        return f"Lean({self.get()!r})"


_GONE = object()


class Local[T]:
    """A Lean value kept as the runtime's object, for one thread at a time.

    The ``local`` attribute of a generated function returns this handle. Its objects keep their
    reference counts, so a function that receives the only reference to an object updates it in
    place. Passing a local handle keeps it; passing ``handle.take()`` gives the reference to the
    function and empties the handle. ``share`` gives the ``Lean`` handle of the value.
    """

    __slots__ = ("_obj", "type")

    def __init__(self, type_, obj):
        self.type = type_
        self._obj = obj

    def _value(self):
        if self._obj is _GONE:
            raise ValueError("this local handle was given away with take()")
        return self._obj

    def get(self) -> T:
        """The Python value of the handle."""
        return self.type.desc.to_py(self._value())

    def take(self):
        """This handle as an argument that gives its reference to the function: the handle is
        empty after the call."""
        self._value()
        return _Taken(self)

    def share(self) -> Lean[T]:
        """The ``Lean`` handle of the value. The value is immutable from then on."""
        return Lean(self.type, _share(self._value()))

    def __repr__(self):
        if self._obj is _GONE:
            return "Local(<taken>)"
        return f"Local({self.get()!r})"


class _Taken:
    __slots__ = ("local",)

    def __init__(self, local):
        self.local = local


def _check_handle(type_, v, name):
    if v.type is not type_ and v.type != type_:
        f = _Fail(f"expected a handle of {type_.python}, got a handle of {v.type.python}", v, (name,))
        raise _validation_error("leanfran-python", f)


def lean_arg(type_, v, name):
    """The runtime value of the argument ``v`` of a function on handles: a handle or a Python value."""
    c = v.__class__
    if c is Lean:
        _check_handle(type_, v, name)
        return v._obj
    if c is Local or c is _Taken:
        local = v.local if c is _Taken else v
        _check_handle(type_, local, name)
        return _share(local._value())
    return to_lean(type_.desc, v, name)


def handle(type_, x):
    return Lean(type_, _share(x))


def local_arg(type_, v, name, owned):
    """The runtime value of the argument ``v`` of a function on local handles. ``owned`` says
    that the function consumes a reference: a local handle that is kept gets one more."""
    c = v.__class__
    if c is Local:
        _check_handle(type_, v, name)
        obj = v._value()
        if owned:
            lean_inc(obj)
        return obj
    if c is _Taken:
        local = v.local
        _check_handle(type_, local, name)
        return local._value()
    if c is Lean:
        _check_handle(type_, v, name)
        return v._obj
    return to_lean(type_.desc, v, name)


def give(*args):
    """Empties the handles passed with ``take()``, once every argument of the call is converted."""
    for v in args:
        if v.__class__ is _Taken:
            v.local._value()
            v.local._obj = _GONE


def local_done(v, obj):
    """Releases the reference of a taken handle that the function borrowed."""
    if v.__class__ is _Taken:
        lean_dec(obj)


def local_handle(type_, x):
    return Local(type_, x)


def io_result(r, desc, error_to_string):
    if r.tag == 0:
        return desc.to_py(r.objs[0])
    raise LeanIOError(error_to_string(r.objs[0]).decode("utf-8"))


# ---------------------------------------------------------------------------
# Structures and constructors


class Obj:
    __slots__ = ("i",)

    def __init__(self, i):
        self.i = i


class Scalar:
    __slots__ = ("key",)

    def __init__(self, key):
        self.key = key


ERASED = None


class FieldInfo:
    __slots__ = ("desc", "loc", "name")

    def __init__(self, name, loc, desc):
        self.name = name
        self.loc = loc
        self.desc = desc


class Invariant:
    __slots__ = ("args", "field", "fn", "prop")

    def __init__(self, field, prop, fn, args):
        self.field = field
        self.prop = prop
        self.fn = fn
        self.args = args

    def holds(self, values):
        return bool(self.fn(*[values[i] for i in self.args]))


class CtorInfo:
    def __init__(self, name, cidx, size, unit, fields, invariants, positional):
        self.name = name
        self.cidx = cidx
        self.size = size
        self.unit = unit
        self.fields = fields
        self.invariants = invariants
        self.positional = positional

    def lean_values(self, v):
        values = []
        for f in self.fields:
            try:
                values.append(f.desc.to_lean(getattr(v, f.name)))
            except _Fail as e:
                raise _at(f.name, e) from None
        for inv in self.invariants:
            if not inv.holds(values):
                _fail(f"{inv.field}: {inv.prop} does not hold", v)
        return values

    def build(self, values):
        if self.unit:
            return self.cidx
        objs = [0] * self.size
        o = Ctor(self.cidx, objs)
        for f, x in zip(self.fields, values, strict=True):
            loc = f.loc
            if loc.__class__ is Obj:
                objs[loc.i] = x
            elif loc.__class__ is Scalar:
                o.sc[loc.key] = x
        return o

    def read(self, cls, x):
        kw = {}
        for f in self.fields:
            loc = f.loc
            if loc.__class__ is Obj:
                kw[f.name] = f.desc.to_py(x.objs[loc.i])
            elif loc.__class__ is Scalar:
                kw[f.name] = f.desc.to_py(x.sc[loc.key])
        return cls.model_construct(**kw)


class StructInfo:
    def __init__(self, cls, ctor, trivial=False):
        self.cls = cls
        self.ctor = ctor
        self.trivial = trivial
        cls.__lean_ctor__ = ctor

    def to_lean(self, v):
        if not isinstance(v, self.cls):
            try:
                v = self.cls.model_validate(v)
            except ValidationError as e:
                _fail(str(e), v)
        values = self.ctor.lean_values(v)
        if self.trivial:
            return values[0]
        return self.ctor.build(values)

    def to_py(self, x):
        if self.trivial:
            f = self.ctor.fields[0]
            return self.cls.model_construct(**{f.name: f.desc.to_py(x)})
        return self.ctor.read(self.cls, x)


class SubtypeInfo:
    def __init__(self, desc, invariant):
        self.desc = desc
        self.invariant = invariant

    def to_lean(self, v):
        x = self.desc.to_lean(v)
        if not self.invariant.holds([x]):
            _fail(f"{self.invariant.prop} does not hold", v)
        return x

    def to_py(self, x):
        return self.desc.to_py(x)

    def __call__(self, v):
        try:
            self.to_lean(v)
        except _Fail as f:
            raise ValueError(f.msg) from None
        return v


def adopt(cls, ctor, trivial=False):
    """Attaches the layout of the Lean structure made from the user's pydantic model ``cls``."""
    cls.__lean__ = StructInfo(cls, ctor, trivial)


def subtype(pytype, desc, invariant, annotations=()):
    info = SubtypeInfo(desc, invariant)
    return Annotated[pytype, *annotations, AfterValidator(info), info]


def is_none(v):
    return v is None


class LeanModel(BaseModel):
    """A Lean structure or constructor: frozen, strict, no extra fields."""

    model_config = ConfigDict(
        frozen=True,
        strict=True,
        extra="forbid",
        validate_by_name=True,
        validate_by_alias=True,
        serialize_by_alias=True,
    )

    @pydantic.model_validator(mode="after")
    def _lean_invariants(self):
        ctor = type(self).__dict__.get("__lean_ctor__")
        if ctor is not None and ctor.invariants:
            try:
                ctor.lean_values(self)
            except _Fail as f:
                raise ValueError(f.msg) from None
        return self


class LeanEnum(enum.StrEnum):
    """A Lean inductive type whose constructors take no arguments."""


class EnumInfo:
    def __init__(self, cls, plain=False):
        self.cls = cls
        self.plain = plain
        self.members = list(cls)
        self.index = {m: i for i, m in enumerate(self.members)}

    def to_lean(self, v):
        if not isinstance(v, self.cls):
            try:
                v = self.cls(v)
            except ValueError:
                _fail(f"expected a {self.cls.__name__}", v)
        return self.index[v]

    def to_py(self, x):
        m = self.members[x]
        return m.value if self.plain else m


def adopt_enum(cls):
    """Attaches the Lean inductive type made from the user's enum ``cls`` (a constructor per member)."""
    cls.__lean__ = EnumInfo(cls)


class ModelUnion:
    """A union of the user's models (``Cat | Dog``): a Lean inductive type with a constructor per model."""

    def __init__(self, alternatives):
        self.alternatives = alternatives
        self.__lean__ = self

    def to_lean(self, v):
        for cidx, d in self.alternatives:
            if isinstance(v, d.info().cls):
                return Ctor(cidx, [d.to_lean(v)])
        _fail("expected one of " + ", ".join(d.info().cls.__name__ for _, d in self.alternatives), v)

    def to_py(self, x):
        for cidx, d in self.alternatives:
            if cidx == x.tag:
                return d.to_py(x.objs[0])
        raise AssertionError(x.tag)


# ---------------------------------------------------------------------------
# `Except ε α`: `Ok[α] | Err[ε]`


class Ok[T](LeanModel):
    """Lean `Except.ok value`. JSON: ``{"ok": value}``."""

    value: T = Field(alias="ok")

    __match_args__ = ("value",)


class Err[E](LeanModel):
    """Lean `Except.error error`. JSON: ``{"error": error}``."""

    error: E

    __match_args__ = ("error",)


class ExceptD(Desc):
    """Lean `Except ε α`. ``err_type`` and ``ok_type`` are the Python types of `ε` and `α`, as
    source evaluated in the generated module ``g`` (they may name types defined later)."""

    def __init__(self, g, err, ok, err_type, ok_type):
        self.g = g
        self.err = err
        self.ok = ok
        self.err_type = err_type
        self.ok_type = ok_type
        self._classes = None

    def key(self):
        return (ExceptD, self.err.key(), self.ok.key())

    def classes(self):
        if self._classes is None:
            err = Err[eval(self.err_type, self.g)]
            ok = Ok[eval(self.ok_type, self.g)]
            self._classes = (err, ok, pydantic.TypeAdapter(ok | err))
        return self._classes

    def to_lean(self, v):
        if not isinstance(v, (Ok, Err)):
            try:
                v = self.classes()[2].validate_python(v)
            except ValidationError as e:
                _fail(str(e), v)
        if isinstance(v, Ok):
            try:
                return Ctor(1, [self.ok.to_lean(v.value)])
            except _Fail as f:
                raise _at("value", f) from None
        try:
            return Ctor(0, [self.err.to_lean(v.error)])
        except _Fail as f:
            raise _at("error", f) from None

    def to_py(self, x):
        err, ok, _ = self.classes()
        if x.tag == 1:
            return ok.model_construct(value=self.ok.to_py(x.objs[0]))
        return err.model_construct(error=self.err.to_py(x.objs[0]))


# ---------------------------------------------------------------------------
# Inductive types: a model per constructor, JSON as Lean's `deriving ToJson, FromJson`


class LeanInductive(BaseModel):
    """Base class of the constructor models of a Lean inductive type.

    As a pydantic type it accepts an instance of a constructor model or Lean's JSON encoding:
    ``"ctor"`` for a constructor without arguments, ``{"ctor": {...}}`` for named arguments,
    ``{"ctor": value}`` or ``{"ctor": [v1, v2]}`` for unnamed ones.
    """

    model_config = ConfigDict(frozen=True, strict=True, extra="forbid")

    __lean_ctors__: ClassVar[dict] = {}

    @classmethod
    def _lean_payload(cls, sub, payload):
        info = sub.__lean_ctor__
        names = [f.name for f in info.fields]
        if info.positional and names:
            if len(names) == 1:
                return {names[0]: payload}
            if not isinstance(payload, (list, tuple)) or len(payload) != len(names):
                raise PydanticCustomError("lean_tag", "expected {n} arguments", {"n": len(names)})
            return dict(zip(names, payload, strict=True))
        if not names and payload in (None, {}):
            return {}
        return payload

    @classmethod
    def __get_pydantic_core_schema__(cls, source: Any, handler: GetCoreSchemaHandler):
        if "__lean_ctors__" not in cls.__dict__:
            return handler(source)
        ctors = cls.__lean_ctors__

        def validate(v, info):
            if isinstance(v, cls):
                return v
            if isinstance(v, str):
                tag, payload = v, None
            elif isinstance(v, dict) and len(v) == 1:
                ((tag, payload),) = v.items()
            else:
                raise PydanticCustomError(
                    "lean_tag", "expected a constructor of {t}: a name or an object with one key", {"t": cls.__name__}
                )
            sub = ctors.get(tag)
            if sub is None:
                raise PydanticCustomError(
                    "lean_tag", "unknown constructor {tag} of {t}", {"tag": tag, "t": cls.__name__}
                )
            data = cls._lean_payload(sub, payload)
            if info.mode == "json":
                return sub.model_validate_json(json.dumps(data))
            return sub.model_validate(data)

        def serialize(v, info):
            sub = type(v)
            ci = sub.__lean_ctor__
            if ci.unit or not ci.fields:
                return ci.name
            d = v.model_dump(mode="json" if info.mode == "json" else "python")
            if ci.positional:
                vals = [d[f.name] for f in ci.fields]
                return {ci.name: vals[0] if len(vals) == 1 else vals}
            return {ci.name: d}

        def json_schema(_schema, handler):
            return cls._lean_json_schema(handler)

        return core_schema.with_info_plain_validator_function(
            validate,
            serialization=core_schema.plain_serializer_function_ser_schema(serialize, info_arg=True),
            metadata={"pydantic_js_functions": [json_schema]},
        )

    @classmethod
    def __get_pydantic_json_schema__(cls, schema, handler: GetJsonSchemaHandler):
        if "__lean_ctors__" not in cls.__dict__:
            return super().__get_pydantic_json_schema__(schema, handler)
        return cls._lean_json_schema(handler)

    @classmethod
    def _lean_json_schema(cls, handler: GetJsonSchemaHandler):
        variants = []
        for tag, sub in cls.__lean_ctors__.items():
            ci = sub.__lean_ctor__
            if ci.unit or not ci.fields:
                variants.append({"const": tag})
                continue
            payload = _inline_defs(sub.model_json_schema(mode=getattr(handler, "mode", "validation")))
            if ci.positional:
                props = payload.get("properties", {})
                items = [props.get(f.name, {}) for f in ci.fields]
                payload = (
                    items[0]
                    if len(items) == 1
                    else {"type": "array", "prefixItems": items, "minItems": len(items), "maxItems": len(items)}
                )
            variants.append(
                {"type": "object", "properties": {tag: payload}, "required": [tag], "additionalProperties": False}
            )
        return {"oneOf": variants, "title": cls.__name__, "description": cls.__doc__}


def _inline_defs(schema):
    """The JSON Schema with its ``$defs`` inlined (a recursive reference stays a ``$ref``)."""
    defs = schema.pop("$defs", {})

    def go(node, seen):
        if isinstance(node, dict):
            ref = node.get("$ref")
            if isinstance(ref, str) and ref.startswith("#/$defs/"):
                name = ref.removeprefix("#/$defs/")
                if name in seen or name not in defs:
                    return node
                return go(defs[name], seen | {name})
            return {k: go(v, seen) for k, v in node.items()}
        if isinstance(node, list):
            return [go(v, seen) for v in node]
        return node

    return go(schema, frozenset())


class InductiveInfo:
    def __init__(self, base, pairs):
        self.base = base
        self.by_tag = {}
        for sub, ci in pairs:
            self.by_tag[ci.cidx] = (sub, ci)

    def to_lean(self, v):
        if not isinstance(v, self.base):
            try:
                v = pydantic.TypeAdapter(self.base).validate_python(v)
            except ValidationError as e:
                _fail(str(e), v)
        ci = type(v).__lean_ctor__
        return ci.build(ci.lean_values(v))

    def to_py(self, x):
        tag = x if isinstance(x, int) else x.tag
        sub, ci = self.by_tag[tag]
        if ci.unit:
            return sub.model_construct()
        return ci.read(sub, x)


def register_inductive(base, pairs):
    ctors = {}
    for sub, ci in pairs:
        sub.__lean_ctor__ = ci
        sub.__name__ = ci.name
        setattr(base, ci.name, sub)
        ctors[ci.name] = sub
    base.__lean_ctors__ = ctors
    base.__lean__ = InductiveInfo(base, pairs)
    schema = base.__get_pydantic_core_schema__(base, None)
    base.__pydantic_core_schema__ = schema
    base.__pydantic_validator__ = SchemaValidator(schema)
    base.__pydantic_serializer__ = SchemaSerializer(schema)


# ---------------------------------------------------------------------------
# Module assembly


def attach(g, path, fn, lean_name=None, lean=None, params=None, result=None, local=None):
    fn.__name__ = path[-1]
    fn.__qualname__ = ".".join(path)
    fn.__lean_name__ = lean_name
    fn.__lean_module__ = g.get("__lean_module__")
    if lean is not None:
        lean.__name__ = path[-1]
        lean.__qualname__ = ".".join([*path, "lean"])
        lean.params = params
        lean.result = result
        fn.lean = lean
    if local is not None:
        local.__name__ = path[-1]
        local.__qualname__ = ".".join([*path, "local"])
        local.params = params
        local.result = result
        fn.local = local
    if len(path) == 1:
        g[path[0]] = fn
        return
    holder = g.get(path[0])
    if holder is None:
        holder = type(path[0], (), {"__module__": g.get("__name__")})
        g[path[0]] = holder
    for p in path[1:-1]:
        nxt = getattr(holder, p, None)
        if nxt is None:
            nxt = type(p, (), {"__module__": g.get("__name__")})
            setattr(holder, p, nxt)
        holder = nxt
    setattr(holder, path[-1], staticmethod(fn))


def finish(g):
    for v in list(g.values()):
        if isinstance(v, type) and issubclass(v, LeanModel) and v not in (LeanModel, Ok, Err):
            v.model_rebuild(force=True, _types_namespace=g)
            v.__match_args__ = tuple(v.model_fields)
