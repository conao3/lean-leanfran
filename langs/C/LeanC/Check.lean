import Lean

open Lean

namespace LeanC

private partial def importChain (env : Environment) (root : Name)
    (isTarget : Name → Bool) : Option (List Name) := Id.run do
  let mut seen : Std.HashSet Name := {}
  let mut pending := [(root, [])]
  while let (name, path) :: rest := pending do
    pending := rest
    if seen.contains name then continue
    seen := seen.insert name
    let path := name :: path
    if isTarget name then return some path.reverse
    if let some idx := env.getModuleIdx? name then
      let imports := env.header.moduleData[idx.toNat]!.imports
      pending := (imports.toList.filter (!·.isMeta)).map (fun imp => (imp.module, path)) ++ pending
  return none

def leanImportChain (env : Environment) (root : Name) : Option (List Name) :=
  importChain env root fun n => (`Lean).isPrefixOf n

def importsStd (env : Environment) (root : Name) : Bool :=
  (importChain env root fun n => (`Std).isPrefixOf n).isSome

def usesSorry (env : Environment) (name : Name) : IO Bool := do
  let axioms ← (collectAxioms (m := CoreM) name).toIO'
    {fileName := "leanfran --lang c", fileMap := default} {env}
  return axioms.contains ``sorryAx

private partial def callees (body : IR.FnBody) (pending : Array Name) : Array Name :=
  match body with
  | .vdecl _ _ (.fap fn _) next | .vdecl _ _ (.pap fn _) next => callees next (pending.push fn)
  | .jdecl _ _ value next => callees next (callees value pending)
  | .case _ _ _ alternatives => alternatives.foldl (fun acc alt => callees alt.body acc) pending
  | .ret _ | .jmp .. | .unreachable => pending
  | body => callees body.body pending

structure ForeignCalls where
  externs : Std.HashSet String := {}
  implementations : Array (Name × Name) := #[]
  deriving Inhabited

def foreignCalls (env : Environment) (roots : Array Name) : Except String ForeignCalls := do
  let mut pending := roots
  let mut seen : Std.HashSet Name := {}
  let mut calls : ForeignCalls := {}
  while let some name := pending.back? do
    pending := pending.pop
    if seen.contains name then continue
    seen := seen.insert name
    if let some impl := Compiler.getImplementedBy? env name then
      calls := {calls with implementations := calls.implementations.push (name, impl)}
      pending := pending.push impl
      continue
    if let some symbol := getExternNameFor env `c name then
      if ["rs:", "py:", "ts:", "clj:", "php:", "go:"].any (symbol.startsWith ·) then
        throw s!"'{name}' uses an extern for another backend: '{symbol}'"
      calls := {calls with externs := calls.externs.insert symbol}
      continue
    if let some (.fdecl _ _ _ body _) := IR.findEnvDecl env name then
      pending := callees body pending
    if let some value := (env.find? name).bind (·.value? (allowOpaque := true)) then
      pending := pending ++ value.getUsedConstants
  return calls

end LeanC
