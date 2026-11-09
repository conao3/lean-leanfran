from pydantic import BaseModel, Field


class LineItem(BaseModel):
    sku: str
    qty: int = Field(ge=1)
    unitPrice: int = Field(ge=0)
