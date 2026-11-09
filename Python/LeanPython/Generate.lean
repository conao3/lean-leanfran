import Lean
import LeanPython.EmitPy
import LeanPython.Marshal

/-! # Generation of a Python module: internal functions, public types and wrappers -/

open Lean Meta

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

structure PublicFn where
  lean : Name
  path : Array String
  target : Name
  sig : PublicSig

/-- Hoists descriptor expressions into module-level names. -/
structure DescTable where
  names : Std.HashMap String String := {}
  defs : Array String := #[]

def DescTable.get (t : DescTable) (code : String) : String × DescTable :=
  match t.names[code]? with
  | some n => (n, t)
  | none =>
    let n := s!"_D{t.defs.size}"
    (n, { names := t.names.insert code n, defs := t.defs.push s!"{n} = {code}" })

def pyList (xs : Array String) : String := "[" ++ ", ".intercalate (xs.toList.map quoteString) ++ "]"

def emitPublicFn (decls : Std.HashMap Name IR.Decl) (f : PublicFn) (tbl : DescTable) :
    Except String (String × DescTable) := do
  let some d := decls[f.target]? | throw s!"function was not collected: {f.target}"
  let mut tbl := tbl
  let mut sigParams := #[]
  let mut stmts := #[]
  let mut args := #[]
  for h : i in [0:f.sig.params.size] do
    match f.sig.params[i] with
    | .world => args := args.push "0"
    | .erased => args := args.push "0"
    | .value nm desc =>
      let (dn, t) := tbl.get desc.pyDesc
      tbl := t
      sigParams := sigParams.push s!"{nm}: {quoteString desc.pyType}"
      stmts := stmts.push s!"    __a{i} = _m.to_lean({dn}, {nm}, {quoteString nm})"
      args := args.push s!"__a{i}"
  let irArgs := (d.params.zip args).filter (fun (p, _) => !p.ty.isVoid) |>.map (·.2)
  let call := if isConst d then s!"{fnName f.target}()" else s!"{fnName f.target}({joinArgs irArgs})"
  let (rn, t) := tbl.get f.sig.result.pyDesc
  tbl := t
  let ret := if f.sig.est then s!"_m.io_result({call}, {rn}, {fnName ``IO.Error.toString})"
    else s!"_m.to_py({rn}, {call})"
  let pyName := "_pub_" ++ "_".intercalate f.path.toList
  let doc := quoteString s!"Lean `{f.lean}`."
  let src := s!"def {pyName}({joinArgs sigParams}) -> {quoteString f.sig.result.pyType}:\n    {doc}\n" ++
    String.join (stmts.toList.map (· ++ "\n")) ++ s!"    return {ret}\n\n\n"
  let attach := s!"_m.attach(globals(), {pyList f.path}, {pyName})\n"
  return (src ++ attach, tbl)

def generate (roots : Array Name) (strip : Name) (internalOnly : Bool)
    (typeModules : Array (Name × String × Bool) := #[]) : CoreM (Except String GenOutput) := do
  let env ← getEnv
  if internalOnly then
    return match generateInternal env roots with
      | .error e => .error e
      | .ok out => .ok { items := out.items, externs := out.externs, decls := out.decls }
  let mut publics : Array PublicFn := #[]
  let mut skipped : Array Skipped := #[]
  let mut st : MarshalState := {}
  for r in roots do
    let target := csimpTarget env r
    let some d := IR.findEnvDecl (← getEnv) target | skipped := skipped.push { name := r, reason := "no IR" }; continue
    let saved := st
    let res : Except String (PublicSig × MarshalState) ← try
        let r ← (((publicSig r d.params).run st).run { strip, typeModules }).run'
        pure (.ok r)
      catch e => pure (.error (← e.toMessageData.toString))
    match res with
    | .ok (sig, st') => st := st'; publics := publics.push { lean := r, path := pyPath strip r, target, sig }
    | .error e =>
      st := saved
      skipped := skipped.push { name := r, reason := e }
  let usesIO := publics.any (·.sig.est)
  let extraRoots := st.deciders ++ (if usesIO then #[``IO.Error.toString] else #[])
  match generateInternal (← getEnv) (publics.map (·.target) ++ extraRoots) with
  | .error e => return .error e
  | .ok out =>
    let declMap := out.decls.foldl (fun m d => m.insert d.name d) ({} : Std.HashMap Name IR.Decl)
    let mut fns := ""
    let mut tbl : DescTable := {}
    for f in publics do
      match emitPublicFn declMap f tbl with
      | .ok (s, t) => fns := fns ++ s; tbl := t
      | .error e => return .error e
    let types := String.join (st.types.toList.map (emitTypeDef · ++ "\n\n"))
    let imports := String.join (st.extImports.toList.map fun (a, m) => s!"import {m} as {a}  # noqa: E402\n")
    let pub := "\n# Public types and functions\n\nfrom typing import Annotated  # noqa: E402\n\nfrom annotated_types import Ge, Lt  # noqa: E402\n\nfrom lean_python import marshal as _m  # noqa: E402\nfrom lean_python.types import Char, Int8, Int16, Int32, Int64, Nat, UInt8, UInt16, UInt32, UInt64  # noqa: E402\n" ++
      imports ++ "\n\n" ++ types ++ String.join (tbl.defs.toList.map (· ++ "\n")) ++ "\n\n" ++ fns ++ "_m.finish(globals())\n"
    return .ok { items := out.items, publicItems := pub, externs := out.externs, decls := out.decls,
                 publics := publics.map fun f => (f.lean, ".".intercalate f.path.toList), skipped }

end LeanPython
