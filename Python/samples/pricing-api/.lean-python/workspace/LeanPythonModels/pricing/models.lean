
/-- The pydantic model `pricing.models.LineItem`. -/
structure LeanPythonModels.pricing.models.LineItem where
  sku : String
  sku_min_length : 1 ≤ sku.length
  qty : Nat
  qty_ge : 1 ≤ qty
  unitPrice : Nat
