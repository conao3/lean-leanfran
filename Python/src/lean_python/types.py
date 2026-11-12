"""Python types of Lean's scalar types, as ``Annotated`` aliases with annotated-types constraints."""

from typing import Annotated

from annotated_types import Ge, Le, MaxLen, MinLen

Nat = Annotated[int, Ge(0)]
UInt8 = Annotated[int, Ge(0), Le(2**8 - 1)]
UInt16 = Annotated[int, Ge(0), Le(2**16 - 1)]
UInt32 = Annotated[int, Ge(0), Le(2**32 - 1)]
UInt64 = Annotated[int, Ge(0), Le(2**64 - 1)]
USize = UInt64
Int8 = Annotated[int, Ge(-(2**7)), Le(2**7 - 1)]
Int16 = Annotated[int, Ge(-(2**15)), Le(2**15 - 1)]
Int32 = Annotated[int, Ge(-(2**31)), Le(2**31 - 1)]
Int64 = Annotated[int, Ge(-(2**63)), Le(2**63 - 1)]
ISize = Int64
Char = Annotated[str, MinLen(1), MaxLen(1)]

__all__ = [
    "Char",
    "ISize",
    "Int8",
    "Int16",
    "Int32",
    "Int64",
    "Nat",
    "UInt8",
    "UInt16",
    "UInt32",
    "UInt64",
    "USize",
]
