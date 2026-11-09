import Lean
import LeanPython.EmitPy

/-! # Generation of a Python module: internal functions and public wrappers -/

open Lean

namespace LeanPython

structure Skipped where
  name : Name
  reason : String

structure GenOutput where
  items : String
  publicItems : String := ""
  externs : Array String
  decls : Array IR.Decl
  publics : Array (Name × String) := #[]
  skipped : Array Skipped := #[]

def generate (roots : Array Name) (_strip : Name) (internalOnly : Bool) : CoreM (Except String GenOutput) := do
  let env ← getEnv
  match generateInternal env roots with
  | .error e => return .error e
  | .ok out =>
    if internalOnly then
      return .ok { items := out.items, externs := out.externs, decls := out.decls }
    return .ok { items := out.items, externs := out.externs, decls := out.decls }

end LeanPython
