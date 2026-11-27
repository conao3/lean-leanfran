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
  shared : SharedTypes := {}

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

/-- The `LeanType` of the descriptor named `dn`. -/
def leanTypeCode (dn : String) (d : Desc) : String := s!"_m.LeanType({dn}, {quoteString d.pyType})"

def pyList (xs : Array String) : String := "[" ++ ", ".intercalate (xs.toList.map quoteString) ++ "]"

def emitPublicFn (decls : Std.HashMap Name IR.Decl) (f : PublicFn) (tbl : DescTable) :
    Except String (String × DescTable) := do
  let some d := decls[f.target]? | throw s!"function was not collected: {f.target}"
  let mut tbl := tbl
  let mut sigParams := #[]
  let mut stmts := #[]
  let mut args := #[]
  let mut leanParams := #[]
  let mut leanStmts := #[]
  let mut localParams := #[]
  let mut localStmts := #[]
  let mut localDone := #[]
  let mut names := #[]
  let mut leanTypes := #[]
  for h : i in [0:f.sig.params.size] do
    match f.sig.params[i] with
    | .world => args := args.push "0"
    | .erased => args := args.push "0"
    | .value nm desc =>
      let (dn, t) := tbl.get desc.pyDesc
      let (tn, t) := t.get (leanTypeCode dn desc)
      tbl := t
      sigParams := sigParams.push s!"{nm}: {quoteString desc.pyType}"
      stmts := stmts.push s!"    __a{i} = _m.to_lean({dn}, {nm}, {quoteString nm})"
      leanParams := leanParams.push s!"{nm}: {quoteString s!"{desc.pyType} | Lean[{desc.pyType}]"}"
      leanStmts := leanStmts.push s!"    __a{i} = _m.lean_arg({tn}, {nm}, {quoteString nm})"
      let borrowed := d.params[i]!.borrow
      names := names.push nm
      localParams := localParams.push s!"{nm}: {quoteString s!"{desc.pyType} | Lean[{desc.pyType}] | Local[{desc.pyType}]"}"
      localStmts := localStmts.push s!"    __a{i} = _m.local_arg({tn}, {nm}, {quoteString nm}, {if borrowed then "False" else "True"})"
      if borrowed then localDone := localDone.push s!"    _m.local_done({nm}, __a{i})"
      leanTypes := leanTypes.push s!"{quoteString nm}: {tn}"
      args := args.push s!"__a{i}"
  let irArgs := (d.params.zip args).filter (fun (p, _) => !p.ty.isVoid) |>.map (·.2)
  let call := if isConst d then s!"{fnName f.target}()" else s!"{fnName f.target}({joinArgs irArgs})"
  let (rn, t) := tbl.get f.sig.result.pyDesc
  let (rt, t) := t.get (leanTypeCode rn f.sig.result)
  tbl := t
  let ret := if f.sig.est then s!"_m.io_result({call}, {rn}, {fnName ``IO.Error.toString})"
    else s!"_m.to_py({rn}, {call})"
  let pyName := "_pub_" ++ "_".intercalate f.path.toList
  let doc := quoteString s!"Lean `{f.lean}`."
  let src := s!"def {pyName}({joinArgs sigParams}) -> {quoteString f.sig.result.pyType}:\n    {doc}\n" ++
    String.join (stmts.toList.map (· ++ "\n")) ++ s!"    return {ret}\n\n\n"
  let give := if names.isEmpty then "" else s!"    _m.give({joinArgs names})\n"
  let leanSrc := if f.sig.est then "" else
    s!"def {pyName}__lean({joinArgs leanParams}) -> {quoteString s!"Lean[{f.sig.result.pyType}]"}:\n    {quoteString s!"Lean `{f.lean}`, on handles."}\n" ++
    String.join (leanStmts.toList.map (· ++ "\n")) ++ give ++ s!"    return _m.handle({rt}, {call})\n\n\n"
  let localSrc := if f.sig.est then "" else
    s!"def {pyName}__local({joinArgs localParams}) -> {quoteString s!"Local[{f.sig.result.pyType}]"}:\n    {quoteString s!"Lean `{f.lean}`, on local handles."}\n" ++
    String.join (localStmts.toList.map (· ++ "\n")) ++ give ++
    (if localDone.isEmpty then s!"    return _m.local_handle({rt}, {call})\n\n\n"
     else s!"    __r = {call}\n" ++ String.join (localDone.toList.map (· ++ "\n")) ++ s!"    return _m.local_handle({rt}, __r)\n\n\n")
  let leanArgs := if f.sig.est then "" else
    s!", {pyName}__lean, \{{", ".intercalate leanTypes.toList}}, {rt}, {pyName}__local"
  let attach := s!"_m.attach(globals(), {pyList f.path}, {pyName}, {quoteString (toString f.lean)}{leanArgs})\n"
  return (src ++ leanSrc ++ localSrc ++ attach, tbl)

def generate (roots : Array Name) (strip : Name) (internalOnly : Bool)
    (typeModules : Array (Name × String × Bool) := #[]) (declaredTypes : Array Name := #[])
    (pythonPath : Option String := none) (shared : SharedTypes := {}) : CoreM (Except String GenOutput) := do
  let env ← getEnv
  if internalOnly then
    return match generateInternal env roots with
      | .error e => .error e
      | .ok out => .ok { items := out.items, externs := out.externs, decls := out.decls }
  let mut publics : Array PublicFn := #[]
  let mut skipped : Array Skipped := #[]
  let mut st : MarshalState := {}
  let cfg : MarshalCfg := { strip, typeModules, pythonPath, shared }
  for name in declaredTypes do
    let savedEnv ← getEnv
    try
      let (_, next) ← (((do
        let ty ← mkConstWithLevelParams name
        if ← isProp ty then throwError "proposition `{ty}`"
        if isClass env name then throwError "type class `{ty}`"
        descOf ty : MarshalM Desc).run st).run cfg).run'
      st := next
    catch e =>
      setEnv savedEnv
      skipped := skipped.push { name, reason := ← e.toMessageData.toString }
  for r in roots do
    let target := csimpTarget env r
    let some d := IR.findEnvDecl (← getEnv) target | skipped := skipped.push { name := r, reason := "no IR" }; continue
    let saved := st
    let res : Except String (PublicSig × MarshalState) ← try
        let r ← (((publicSig r d.params).run st).run cfg).run'
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
    let pub := "\n# Public types and functions\n\nfrom typing import Annotated  # noqa: E402\n\nfrom annotated_types import Ge, Gt, Le, Lt, MaxLen, MinLen  # noqa: E402\n\nfrom leanfran import marshal as _m  # noqa: E402\nfrom leanfran.marshal import Err, Lean, Local, Ok  # noqa: E402\nfrom leanfran.types import Char, Int8, Int16, Int32, Int64, Nat, UInt8, UInt16, UInt32, UInt64  # noqa: E402\n" ++
      imports ++ "\n\n" ++ types ++ String.join (tbl.defs.toList.map (· ++ "\n")) ++ "\n\n" ++ fns ++ "_m.finish(globals())\n"
    let shared := pythonPath.map (fun path =>
      st.defined.fold (fun types name ty => types.insert ty (path, name)) shared) |>.getD shared
    return .ok { items := out.items, publicItems := pub, externs := out.externs, decls := out.decls,
                 publics := publics.map fun f => (f.lean, ".".intercalate f.path.toList), skipped, shared }

end LeanPython
