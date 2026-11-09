from pydantic import BaseModel, Field


class LineItem(BaseModel):
    sku: str = Field(min_length=1)
    qty: int = Field(ge=1)
    unitPrice: int = Field(ge=0)
