import enum
from typing import Literal

from pydantic import BaseModel, Field


class LineItem(BaseModel):
    sku: str
    qty: int = Field(ge=1)
    unitPrice: int = Field(ge=0)


class Status(enum.StrEnum):
    open = "open"
    closed = "done"


class Cat(BaseModel):
    name: str
    lives: int = Field(ge=0, le=9)


class Dog(BaseModel):
    name: str
    good: bool


class Order(BaseModel):
    status: Status
    kind: Literal["retail", "wholesale"]
    items: list[LineItem]
    pet: Cat | Dog | None = None
