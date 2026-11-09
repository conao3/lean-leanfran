from calc.spec import spec
from lean_python import Nat
from lean_python.verify import model


@model(refines=spec.clampSpec, requires=spec.ordered, ensures={"in_range": spec.inRange})
def clamp(x: int, lo: int, hi: int) -> int:
    if x < lo:
        return lo
    if x > hi:
        return hi
    return x


@model(refines=spec.firstOr)
def first_or(xs: list[int], d: int) -> int:
    if len(xs) == 0:
        return d
    return xs[0]


@model(refines=spec.sumTo)
def sum_to(n: Nat) -> Nat:
    total = 0
    for i in range(n + 1):
        total += i
    return total


@model(ensures={"nonneg": spec.nonneg})
def sum_abs(xs: list[int]) -> int:
    total = 0
    for x in xs:
        total += abs(x)
    return total
