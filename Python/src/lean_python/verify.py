"""``@model``: bind a Python function to Lean specifications.

``@model(refines=spec.f)`` says the function computes ``spec.f`` (a function of a ``lean(...)``
block); ``requires=`` and ``ensures=`` name ``Bool`` functions of blocks (the precondition takes
the arguments, the postcondition the arguments and the result). ``lean-py check`` translates the
function into Lean and reports whether the obligations are proved; ``check_model`` runs the same
specifications as a property test with Hypothesis. The decorator returns the function unchanged.
"""

import inspect
import typing

REGISTRY = []


class ModelSpec:
    def __init__(self, fn, refines, requires, ensures):
        self.fn = fn
        self.refines = refines
        self.requires = requires
        if ensures is None:
            self.ensures = {}
        elif isinstance(ensures, dict):
            self.ensures = dict(ensures)
        else:
            self.ensures = {"ensures": ensures}

    @property
    def qualname(self):
        return f"{self.fn.__module__}:{self.fn.__qualname__}"

    def specs(self):
        out = {}
        if self.refines is not None:
            out["refines"] = self.refines
        if self.requires is not None:
            out["requires"] = self.requires
        out.update(self.ensures)
        return out


def model(*, refines=None, requires=None, ensures=None):
    """Binds the decorated function to Lean specifications (see the module docstring)."""

    def deco(fn):
        spec = ModelSpec(fn, refines, requires, ensures)
        fn.__lean_model__ = spec
        REGISTRY.append(spec)
        return fn

    return deco


def models_of(module):
    return [v.__lean_model__ for v in vars(module).values() if callable(v) and hasattr(v, "__lean_model__")]


# ---------------------------------------------------------------------------
# Property tests


def strategy(annotation, metadata=()):
    """A Hypothesis strategy of the values of a parameter or field type."""
    import annotated_types as at
    from hypothesis import strategies as st
    from pydantic import BaseModel

    metadata = list(metadata)
    while typing.get_origin(annotation) is typing.Annotated:
        annotation, *more = typing.get_args(annotation)
        metadata.extend(more)
    if annotation is int:
        lo = hi = None
        for m in metadata:
            if isinstance(m, at.Ge):
                lo = m.ge if lo is None else max(lo, m.ge)
            elif isinstance(m, at.Gt):
                lo = m.gt + 1 if lo is None else max(lo, m.gt + 1)
            elif isinstance(m, at.Le):
                hi = m.le if hi is None else min(hi, m.le)
            elif isinstance(m, at.Lt):
                hi = m.lt - 1 if hi is None else min(hi, m.lt - 1)
        return st.integers(min_value=lo if lo is not None else -1000, max_value=hi if hi is not None else 1000)
    if annotation is bool:
        return st.booleans()
    if annotation is str:
        lo = max([m.min_length for m in metadata if isinstance(m, at.MinLen)], default=0)
        hi = min([m.max_length for m in metadata if isinstance(m, at.MaxLen)], default=lo + 8)
        return st.text(min_size=lo, max_size=hi)
    if annotation is float:
        return st.floats(allow_nan=False, allow_infinity=False, width=64)
    origin = typing.get_origin(annotation)
    if origin is list:
        (a,) = typing.get_args(annotation)
        return st.lists(strategy(a), max_size=8)
    if origin is tuple:
        return st.tuples(*(strategy(a) for a in typing.get_args(annotation)))
    args = typing.get_args(annotation)
    if args and type(None) in args:
        rest = [a for a in args if a is not type(None)]
        return st.none() | st.one_of(*(strategy(a) for a in rest))
    if isinstance(annotation, type) and issubclass(annotation, BaseModel):
        fields = {n: strategy(f.annotation, f.metadata) for n, f in annotation.model_fields.items()}
        return st.builds(annotation, **fields)
    raise TypeError(f"no strategy for {annotation!r}")


class PropertyFailure(AssertionError):
    pass


def check_model(fn, max_examples=200):
    """Runs the function against its specifications on generated arguments; raises on a counterexample."""
    from hypothesis import given, settings
    from hypothesis import strategies as st

    spec = fn.__lean_model__
    hints = typing.get_type_hints(fn, include_extras=True)
    params = list(inspect.signature(fn).parameters)
    strategies = st.tuples(*(strategy(hints[p]) for p in params))

    @settings(max_examples=max_examples, deadline=None, database=None)
    @given(strategies)
    def run(args):
        from hypothesis import assume

        if spec.requires is not None:
            assume(spec.requires(*args))
        try:
            result = fn(*args)
        except Exception as e:  # noqa: BLE001
            raise PropertyFailure(f"{fn.__qualname__}{args} raised {e!r}") from None
        if spec.refines is not None:
            expected = spec.refines(*args)
            if result != expected:
                raise PropertyFailure(f"{fn.__qualname__}{args} = {result!r}, the spec gives {expected!r}")
        for label, e in spec.ensures.items():
            if not e(*args, result):
                raise PropertyFailure(f"{fn.__qualname__}{args} = {result!r} breaks {label}")

    run()


def check_module(module, max_examples=200):
    """``check_model`` for every ``@model`` function of the module."""
    for spec in models_of(module):
        check_model(spec.fn, max_examples)
