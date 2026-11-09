
/-- The pydantic model `step08.code.Account`. -/
structure LeanPythonModels.step08.code.Account where
  owner : String
  owner_min_length : 1 ≤ owner.length
  balance : Nat
