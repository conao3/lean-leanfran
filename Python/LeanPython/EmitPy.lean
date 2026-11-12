import Lean
import LeanPython.RuntimeExterns

/-! # lean-py: a Lean IR -> Python backend

IR `Decl`s are read from the environment with `Lean.IR.findEnvDecl`, collected
transitively from a set of root functions, and emitted as Python functions that
call into the runtime `lean_python.runtime`. The emitted code follows the C backend
(`Lean.Compiler.LCNF.EmitC`): reference counting, `reset`/`reuse` and `isShared` run
as in C, so the in-place updates of the C backend happen in the same places. `goto`
is replaced by a state machine over the join points. -/

open Lean Lean.IR

namespace LeanPython

/-! ## Names -/

/-- Python identifier of a collected Lean function (the C backend's mangling). -/
def fnName (n : Name) : String := n.mangle "l_"

def varName (x : VarId) : String := s!"x_{x.idx}"

def hex2 (n : Nat) (width : Nat) : String :=
  let s := String.ofList (Nat.toDigits 16 n)
  String.ofList (List.replicate (width - s.length) '0') ++ s

/-- A Python string literal. -/
def quoteString (s : String) : String := Id.run do
  let mut acc := "\""
  for c in s.toList do
    acc := acc ++ match c with
      | '"' => "\\\""
      | '\\' => "\\\\"
      | '\n' => "\\n"
      | '\t' => "\\t"
      | '\r' => "\\r"
      | c =>
        if c.toNat < 32 || c.toNat == 127 then "\\x" ++ hex2 c.toNat 2
        else c.toString
  return acc ++ "\""

/-- A Python bytes literal holding the UTF-8 encoding of `s` (a Lean `String` at run time). -/
def quoteBytes (s : String) : String := Id.run do
  let mut acc := "b\""
  for b in s.toUTF8.toList do
    let n := b.toNat
    acc := acc ++
      if n == 34 then "\\\""
      else if n == 92 then "\\\\"
      else if n == 10 then "\\n"
      else if n < 32 || n ≥ 127 then "\\x" ++ hex2 n 2
      else (Char.ofNat n).toString
  return acc ++ "\""

/-! ## Types -/

def defaultValue : IRType → String
  | .float | .float32 => "0.0"
  | _ => "0"

def isObjType (t : IRType) : Bool := !t.isScalar

/-! ## Emission context -/

/-- Lean functions exported under a C name (`@[export sym]`), by that name. An extern whose
    C name is one of them is implemented by Lean code, so it is called like a Lean function
    (the C backend links the extern to that function). -/
def exportedFns (env : Environment) : Std.HashMap String Name := Id.run do
  let mut m : Std.HashMap String Name := {}
  for idx in [0:env.header.moduleNames.size] do
    for (n, sym) in exportAttr.ext.getModuleEntries env idx do
      m := m.insert sym.toString n
  return m

structure Ctx where
  env : Environment
  decls : Std.HashMap Name Decl
  /-- Lean functions implementing externs, by C name. -/
  exports : Std.HashMap String Name := {}
  self : Name
  selfParams : Array Param
  /-- Join points with a single `jmp`, expanded at that site. -/
  inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}
  /-- Join points emitted as states of the state machine, by index, with their parameters. -/
  stateOf : Std.HashMap Nat (Nat × Array Param) := {}
  /-- Types of the local variables. -/
  varTypes : Std.HashMap Nat IRType := {}

structure St where
  out : String := ""
  indent : Nat := 0

abbrev EmitM := ReaderT Ctx (StateT St (Except String))

def emitLn (s : String) : EmitM Unit :=
  modify fun st => { st with out := st.out ++ String.ofList (List.replicate (4 * st.indent) ' ') ++ s ++ "\n" }

def indented (k : EmitM Unit) : EmitM Unit := do
  modify fun st => { st with indent := st.indent + 1 }
  k
  modify fun st => { st with indent := st.indent - 1 }

def argStr : Arg → String
  | .var x => varName x
  | .erased => "0"

def externSymbol (env : Environment) (c : Name) : Option String :=
  getExternNameFor env `c c

/-- An extern implemented by a Python function (`@[extern "py:module.attr"]`). -/
def isPyExtern (sym : String) : Bool := sym.startsWith "py:"

def pyExternName (c : Name) : String := fnName c ++ "__py"

def isConst (d : Decl) : Bool :=
  match d with
  | .fdecl _ xs .. => xs.isEmpty
  | _ => false

def varType (x : VarId) : EmitM IRType := do
  return (← read).varTypes.getD x.idx .object

def joinArgs (xs : Array String) : String := ", ".intercalate xs.toList

/-- Call of a collected function or an extern. Erased and void parameters are
    dropped for externs, as in the C backend. -/
def callStr (c : Name) (ys : Array Arg) : EmitM String := do
  let ctx ← read
  match ctx.decls[c]? with
  | some d@(.extern _ ps _ _) =>
    let some sym := externSymbol ctx.env c | throw s!"extern without a C symbol: {d.name}"
    if isPyExtern sym then
      let args := (ps.zip ys).filter (fun (p, _) => !(p.ty.isErased || p.ty.isVoid)) |>.map (argStr ·.2)
      return s!"{pyExternName c}({joinArgs args})"
    if let some t := ctx.exports[sym]? then
      if let some td := ctx.decls[t]? then
        if td.params.size == ps.size then
          -- an owned parameter of the Lean implementation receives a borrowed argument
          let args := (td.params.zip (ps.zip ys)).filter (fun (tp, _) => !tp.ty.isVoid) |>.map fun (tp, p, y) =>
            if p.borrow && !tp.borrow && isObjType tp.ty then
              match y with
              | .var x => s!"lean_inc_ret({varName x})"
              | .erased => argStr y
            else argStr y
          if isConst td then return s!"{fnName t}()"
          return s!"{fnName t}({joinArgs args})"
    let args := (ps.zip ys).filter (fun (p, _) => !(p.ty.isErased || p.ty.isVoid)) |>.map (argStr ·.2)
    return s!"{sym}({joinArgs args})"
  | some d =>
    if isConst d then return s!"{fnName c}()"
    let args := (d.params.zip ys).filter (fun (p, _) => !p.ty.isVoid) |>.map (argStr ·.2)
    return s!"{fnName c}({joinArgs args})"
  | none => throw s!"function was not collected: {c}"

def litStr (ty : IRType) : LitVal → String
  | .str s => quoteBytes s
  | .num v =>
    match ty with
    | .float | .float32 => s!"{v}.0"
    | _ => toString v

/-- Byte offset of a scalar field: `n` words of objects and `usize`s, then `off` bytes. -/
def scalarKey (n off : Nat) : Nat := 8 * n + off

def liftExcept (e : Except String α) : EmitM α :=
  match e with
  | .ok a => pure a
  | .error m => throw m

/-- One `let` binding: statements assigning `x`. -/
def emitVDecl (x : VarId) (ty : IRType) (e : IR.Expr) : EmitM Unit := do
  let xs := varName x
  match e with
  | .ctor i ys =>
    if i.size == 0 && i.usize == 0 && i.ssize == 0 then emitLn s!"{xs} = {i.cidx}"
    else emitLn s!"{xs} = Ctor({i.cidx}, [{joinArgs (ys.map argStr)}])"
  | .reset n y => emitLn s!"{xs} = lean_reset({varName y}, {n})"
  | .reuse y i upd ys =>
    let tag := if upd then "True" else "False"
    emitLn s!"{xs} = lean_reuse({varName y}, {i.cidx}, {tag}, [{joinArgs (ys.map argStr)}])"
  | .proj i y => emitLn s!"{xs} = {varName y}.objs[{i}]"
  | .uproj i y => emitLn s!"{xs} = {varName y}.sc[{scalarKey i 0}]"
  | .sproj n off y => emitLn s!"{xs} = {varName y}.sc[{scalarKey n off}]"
  | .fap c ys => emitLn s!"{xs} = {← callStr c ys}"
  | .pap c ys =>
    let ctx ← read
    let some d := ctx.decls[c]? | throw s!"function was not collected: {c}"
    emitLn s!"{xs} = Closure({fnName c}, {d.params.size}, [{joinArgs (ys.map argStr)}])"
  | .ap f ys => emitLn s!"{xs} = lean_apply({varName f}, [{joinArgs (ys.map argStr)}])"
  | .box _ y => emitLn s!"{xs} = {varName y}"
  | .unbox y => emitLn s!"{xs} = {varName y}"
  | .lit v => emitLn s!"{xs} = {litStr ty v}"
  | .isShared y => emitLn s!"{xs} = lean_is_shared({varName y})"

/-! ## Join points -/

/-- Join point declarations of a body, with the number of `jmp`s to each. -/
partial def joinPoints (b : FnBody) (acc : Std.HashMap Nat (Array Param × FnBody × Nat)) :
    Std.HashMap Nat (Array Param × FnBody × Nat) :=
  match b with
  | .jdecl j xs v k =>
    let acc := acc.alter j.idx fun
      | some (_, _, n) => some (xs, v, n)
      | none => some (xs, v, 0)
    joinPoints k (joinPoints v acc)
  | .case _ _ _ alts => alts.foldl (fun acc a => joinPoints a.body acc) acc
  | .jmp j _ => acc.alter j.idx fun
    | some (xs, v, n) => some (xs, v, n + 1)
    | none => some (#[], .unreachable, 1)
  | .ret _ | .unreachable => acc
  | b => joinPoints b.body acc

/-- Variables declared in a body with their types (vdecls and join point
    parameters). -/
partial def bodyVars (b : FnBody) (acc : Std.HashMap Nat IRType) : Std.HashMap Nat IRType :=
  match b with
  | .vdecl x t _ k => bodyVars k (acc.insert x.idx t)
  | .jdecl _ xs v k =>
    let acc := xs.foldl (fun a p => a.insert p.x.idx p.ty) acc
    bodyVars k (bodyVars v acc)
  | .case _ _ _ alts => alts.foldl (fun a alt => bodyVars alt.body a) acc
  | .ret _ | .jmp .. | .unreachable => acc
  | b => bodyVars b.body acc

def isSelfTailCall (self : Name) : FnBody → Option (Array Arg)
  | .vdecl x _ (.fap c ys) (.ret (.var r)) => if c == self && r == x then some ys else none
  | _ => none

/-- Parallel assignment (a Python tuple assignment). -/
def assignAll (targets : Array String) (vals : Array String) : EmitM Unit := do
  if targets.isEmpty then return
  if targets.size == 1 then emitLn s!"{targets[0]!} = {vals[0]!}"
  else emitLn s!"{joinArgs targets} = {joinArgs vals}"

partial def emitBody (b : FnBody) : EmitM Unit := do
  let ctx ← read
  if let some ys := isSelfTailCall ctx.self b then
    let ps := ctx.selfParams
    let pairs := (ps.zip ys).filter fun (p, _) => !p.ty.isVoid
    assignAll (pairs.map (varName ·.1.x)) (pairs.map (argStr ·.2))
    emitLn "__blk = 0"
    emitLn "continue"
    return
  match b with
  | .vdecl x ty e k => emitVDecl x ty e; emitBody k
  | .jdecl _ _ _ k => emitBody k
  | .set x i y k => emitLn s!"{varName x}.objs[{i}] = {argStr y}"; emitBody k
  | .uset x i y k => emitLn s!"{varName x}.sc[{scalarKey i 0}] = {varName y}"; emitBody k
  | .sset x n off y _ k => emitLn s!"{varName x}.sc[{scalarKey n off}] = {varName y}"; emitBody k
  | .setTag x cidx k => emitLn s!"{varName x}.tag = {cidx}"; emitBody k
  | .inc x n _ p k =>
    unless p do
      if n == 1 then emitLn s!"lean_inc({varName x})" else emitLn s!"lean_inc_n({varName x}, {n})"
    emitBody k
  | .dec x _ _ p k =>
    unless p do emitLn s!"lean_dec({varName x})"
    emitBody k
  | .del _ k => emitBody k
  | .case _ x xType alts =>
    let xt ← varType x
    let scrut := if isObjType xType && isObjType xt then s!"lean_obj_tag({varName x})" else varName x
    let alts := alts.toList
    match alts with
    | [.default body] => emitBody body
    | _ =>
      emitLn s!"__t = {scrut}"
      let mut first := true
      let mut hasDefault := false
      for alt in alts do
        match alt with
        | .ctor info body =>
          emitLn s!"{if first then "if" else "elif"} __t == {info.cidx}:"
          indented (emitBody body)
        | .default body =>
          hasDefault := true
          emitLn (if first then "if True:" else "else:")
          indented (emitBody body)
        first := false
      unless hasDefault do
        emitLn "else:"
        indented (emitLn "lean_internal_panic_unreachable()")
  | .ret y => emitLn s!"return {argStr y}"
  | .jmp j ys =>
    match ctx.inlineJps[j.idx]? with
    | some (xs, v) =>
      assignAll (xs.map (varName ·.x)) (ys.map argStr)
      emitBody v
    | none =>
      let some (st, xs) := ctx.stateOf[j.idx]? | throw s!"unknown join point {j.idx}"
      assignAll (xs.map (varName ·.x)) (ys.map argStr)
      emitLn s!"__blk = {st}"
      emitLn "continue"
  | .unreachable => emitLn "lean_internal_panic_unreachable()"

/-! ## Declarations -/

def paramList (ps : Array Param) : String :=
  joinArgs (ps.filter (!·.ty.isVoid) |>.map (fun p => varName p.x))

partial def bodySelfTail (f : Name) (b : FnBody) : Bool :=
  match b with
  | .vdecl x _ (.fap c _) (.ret (.var r)) => (c == f && r == x)
  | .jdecl _ _ v k => bodySelfTail f v || bodySelfTail f k
  | .case _ _ _ alts => alts.any fun a => bodySelfTail f a.body
  | .ret _ | .jmp .. | .unreachable => false
  | b => bodySelfTail f b.body

def runEmit (ctx : Ctx) (indent : Nat) (k : EmitM Unit) : Except String String := do
  let ((), s) ← (k.run ctx).run { indent }
  return s.out

def emitDecl (env : Environment) (decls : Std.HashMap Name Decl) (exports : Std.HashMap String Name) (d : Decl) : Except String String := do
  match d with
  | .extern f ps _ _ =>
    let some sym := externSymbol env f | return ""
    unless isPyExtern sym do return ""
    let parts := ((sym.drop 3).toString).splitOn "."
    let attr := parts.getLast!
    let mod := ".".intercalate parts.dropLast
    let n := (ps.filter fun p => !(p.ty.isErased || p.ty.isVoid)).size
    let args := joinArgs ((Array.range n).map (s!"a{·}"))
    return s!"def {pyExternName f}({args}):\n    return lean_py_extern({quoteString mod}, {quoteString attr})({args})\n"
  | .fdecl f ps _ body _ =>
  let jps := joinPoints body {}
  let mut inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}
  let mut stateOf : Std.HashMap Nat (Nat × Array Param) := {}
  let mut states : Array (Nat × FnBody) := #[]
  for (i, (xs, v, n)) in jps.toList.mergeSort (fun a b => a.1 ≤ b.1) do
    if n == 1 then inlineJps := inlineJps.insert i (xs, v)
    else
      let st := states.size + 1
      stateOf := stateOf.insert i (st, xs)
      states := states.push (st, v)
  let selfTail := bodySelfTail f body
  let machine := !states.isEmpty || selfTail
  let vars := bodyVars body {}
  let varTypes := ps.foldl (fun m p => m.insert p.x.idx p.ty) vars
  let ctx : Ctx := { env, decls, exports, self := f, selfParams := ps, inlineJps, stateOf, varTypes }
  let body' : Nat → Except String String := fun ind => do
    if machine then
      let mut out := String.ofList (List.replicate (4 * ind) ' ') ++ "__blk = 0\n"
      out := out ++ String.ofList (List.replicate (4 * ind) ' ') ++ "while True:\n"
      let pad := String.ofList (List.replicate (4 * (ind + 1)) ' ')
      out := out ++ pad ++ "if __blk == 0:\n" ++ (← runEmit ctx (ind + 2) (emitBody body))
      for (st, v) in states do
        out := out ++ pad ++ s!"elif __blk == {st}:\n" ++ (← runEmit ctx (ind + 2) (emitBody v))
      out := out ++ pad ++ "else:\n" ++ pad ++ "    lean_internal_panic_unreachable()\n"
      return out
    else runEmit ctx ind (emitBody body)
  if ps.isEmpty then
    -- constants: evaluated once on first use and marked persistent
    let mut out := s!"def {fnName f}__init():\n" ++ (← body' 1)
    out := out ++ s!"{fnName f}__cell = []\n"
    out := out ++ s!"def {fnName f}():\n    c = {fnName f}__cell\n    if not c:\n        c.append(lean_mark_persistent({fnName f}__init()))\n    return c[0]\n"
    return out
  return s!"def {fnName f}({paramList ps}):\n" ++ (← body' 1)

/-! ## Collection -/

partial def bodyCallees (b : FnBody) (acc : Array Name) : Array Name :=
  match b with
  | .vdecl _ _ e k =>
    let acc := match e with
      | .fap c _ | .pap c _ => acc.push c
      | _ => acc
    bodyCallees k acc
  | .jdecl _ _ v k => bodyCallees k (bodyCallees v acc)
  | .case _ _ _ alts => alts.foldl (fun acc a => bodyCallees a.body acc) acc
  | .ret _ | .jmp .. | .unreachable => acc
  | b => bodyCallees b.body acc

def collect (env : Environment) (exports : Std.HashMap String Name) (roots : Array Name) : Except String (Array Decl) := do
  let mut seen : Std.HashSet Name := {}
  let mut out : Array Decl := #[]
  let mut stack := roots.reverse
  while !stack.isEmpty do
    let n := stack.back!
    stack := stack.pop
    if seen.contains n then continue
    seen := seen.insert n
    let some d := findEnvDecl env n | throw s!"no IR for {n} (is it noncomputable?)"
    out := out.push d
    if let .extern f .. := d then
      if let some t := (externSymbol env f).bind (exports[·]?) then
        unless seen.contains t do stack := stack.push t
    if let .fdecl _ _ _ b _ := d then
      for c in (bodyCallees b #[]).reverse do
        unless seen.contains c do stack := stack.push c
  return out

/-- The function compiled code runs for `name`: the target of a `@[csimp]`
    lemma `@name = @target` in an imported module (the module of `name` first), or `name`
    itself. -/
def csimpTarget (env : Environment) (name : Name) : Name := Id.run do
  let own := (env.getModuleIdxFor? name).map (·.toNat)
  let idxs := own.toList ++ ((List.range env.header.moduleNames.size).filter (some · != own))
  for idx in idxs do
    for e in Compiler.CSimp.ext.ext.getModuleEntries env idx do
      match e with
      | .global e | .scoped _ e => if e.fromDeclName == name then return e.toDeclName
  return name

/-- C names of the externs the collected functions call. -/
def externsOf (env : Environment) (exports : Std.HashMap String Name) (decls : Array Decl) : Except String (Array String) := do
  let mut out : Array String := #[]
  for d in decls do
    if let .extern f .. := d then
      match externSymbol env f with
      | some s => unless out.contains s || exports.contains s || isPyExtern s do out := out.push s
      | none => throw s!"extern without a C symbol: {f}"
  return out

structure Output where
  /-- The emitted definitions (a Python module body without the runtime import). -/
  items : String
  externs : Array String
  decls : Array Decl

def generateInternal (env : Environment) (roots : Array Name) : Except String Output := do
  let targets := roots.map (csimpTarget env)
  let exports := exportedFns env
  let decls ← collect env exports (roots ++ targets)
  let declMap := decls.foldl (fun m d => m.insert d.name d) ({} : Std.HashMap Name Decl)
  let externs ← externsOf env exports decls
  let mut items := ""
  for d in decls do
    let s ← emitDecl env declMap exports d
    unless s.isEmpty do items := items ++ s ++ "\n"
  return { items, externs, decls }

/-- The module header: the runtime names the definitions use. -/
def moduleHeader (externs : Array String) : String :=
  let core := #["Ctor", "Closure", "lean_reset", "lean_reuse", "lean_apply", "lean_inc", "lean_inc_n",
    "lean_inc_ret", "lean_dec", "lean_obj_tag", "lean_is_shared", "lean_mark_persistent",
    "lean_internal_panic_unreachable", "lean_py_extern"]
  let names := core ++ (externs.filter (!core.contains ·)).qsort (· < ·)
  "from lean_python.runtime import (  # noqa: F401\n" ++ String.join (names.toList.map (s!"    {·},\n")) ++ ")\n"

end LeanPython
