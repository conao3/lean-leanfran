import Lean
import LeanGo.RuntimeExterns

open Lean Lean.IR

namespace LeanGo

def exportedFns (env : Environment) : Std.HashMap String Name := Id.run do
  let mut m : Std.HashMap String Name := {}
  for idx in [0:env.header.moduleNames.size] do
    for (n, sym) in exportAttr.ext.getModuleEntries env idx do
      m := m.insert sym.toString n
  return m

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

partial def bodyVars (b : FnBody) (acc : Std.HashMap Nat IRType) : Std.HashMap Nat IRType :=
  match b with
  | .vdecl x t _ k => bodyVars k (acc.insert x.idx t)
  | .jdecl _ xs v k =>
    let acc := xs.foldl (fun a p => a.insert p.x.idx p.ty) acc
    bodyVars k (bodyVars v acc)
  | .case _ _ _ alts => alts.foldl (fun a alt => bodyVars alt.body a) acc
  | .ret _ | .jmp .. | .unreachable => acc
  | b => bodyVars b.body acc

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

def externSymbol (env : Environment) (c : Name) : Option String :=
  getExternNameFor env `c c

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

def csimpTarget (env : Environment) (name : Name) : Name := Id.run do
  let own := (env.getModuleIdxFor? name).map (·.toNat)
  let idxs := own.toList ++ ((List.range env.header.moduleNames.size).filter (some · != own))
  for idx in idxs do
    for e in Compiler.CSimp.ext.ext.getModuleEntries env idx do
      match e with
      | .global e | .scoped _ e => if e.fromDeclName == name then return e.toDeclName
  return name

def liveParam (p : Param) : Bool := !(p.ty.isErased || p.ty.isVoid)

def goName (n : Name) : String := n.mangle "L_"

def methodName (internalOnly : Bool) (n : Name) : String :=
  if internalOnly then goName n else n.mangle "l_"

def varName (x : VarId) : String := s!"x_{x.idx}"

def joinArgs (xs : Array String) : String := ", ".intercalate xs.toList

def quoteGo (s : String) : String := Id.run do
  let mut out := "\""
  for b in s.toUTF8 do
    let n := b.toNat
    out := out ++
      if n == 34 then "\\\""
      else if n == 92 then "\\\\"
      else if n == 10 then "\\n"
      else if n == 13 then "\\r"
      else if n == 9 then "\\t"
      else if n < 32 || n ≥ 127 then
        let hex := String.ofList (Nat.toDigits 16 n)
        "\\x" ++ (if hex.length == 1 then "0" else "") ++ hex
      else (Char.ofNat n).toString
  return out ++ "\""

def goType : IRType → String
  | .uint8 => "uint8"
  | .uint16 => "uint16"
  | .uint32 => "uint32"
  | .uint64 | .usize => "uint64"
  | .float => "float64"
  | .float32 => "float32"
  | _ => "rt.V"

def scalarSuffix : IRType → Except String String
  | .uint8 => .ok "uint8"
  | .uint16 => .ok "uint16"
  | .uint32 => .ok "uint32"
  | .uint64 => .ok "uint64"
  | .float => .ok "float"
  | .float32 => .ok "float32"
  | t => .error s!"unsupported scalar field type: {repr t}"

def supportedType : IRType → Bool
  | .struct .. | .union .. => false
  | _ => true

def box (ty : IRType) (s : String) : String :=
  match ty with
  | .float => s!"rt.Lean_box_float({s})"
  | .float32 => s!"rt.Lean_box_float32({s})"
  | .uint64 | .usize => s!"rt.Lean_box({s})"
  | .uint8 | .uint16 | .uint32 => s!"rt.Lean_box(uint64({s}))"
  | _ => s

def unbox (ty : IRType) (s : String) : String :=
  match ty with
  | .float => s!"rt.Lean_unbox_float({s})"
  | .float32 => s!"rt.Lean_unbox_float32({s})"
  | .uint64 | .usize => s!"rt.Lean_unbox({s})"
  | .uint8 | .uint16 | .uint32 => s!"{goType ty}(rt.Lean_unbox({s}))"
  | _ => s

def upperFirst (s : String) : String :=
  match s.toList with
  | [] => s
  | c :: rest => String.ofList (c.toUpper :: rest)

def runtimeName (s : String) : String := "rt." ++ upperFirst s

def zero (t : IRType) : String := if t.isScalar then "0" else "rt.V{}"

def litGo (ty : IRType) : LitVal → String
  | .str s => s!"rt.Lean_mk_string({quoteGo s})"
  | .num n =>
    if ty.isScalar then
      let width := match ty with
        | .uint8 => 8
        | .uint16 => 16
        | .uint32 => 32
        | .uint64 | .usize => 64
        | _ => 0
      toString (if width > 0 then n % (2 ^ width) else n)
    else if n < 2 ^ 63 then
      s!"rt.NatFromUint64({n})"
    else
      s!"rt.Lean_cstr_to_nat(\"{n}\")"

def tailName (n : Name) : String := "tail_" ++ goName n
def adapterName (n : Name) : String := "apply_" ++ goName n
def coreName (n : Name) : String := "core_" ++ goName n
def globalName (n : Name) : String := "value_" ++ goName n
def computeName (n : Name) : String := "compute_" ++ goName n

structure Ctx where
  decls : Std.HashMap Name Decl
  tailTargets : Std.HashSet Name
  self : Name
  selfParams : Array Param
  resultType : IRType
  hasFrame : Bool
  canTail : Bool
  internalOnly : Bool
  inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}
  labelParams : Std.HashMap Nat (Array Param) := {}
  varTypes : Std.HashMap Nat IRType := {}

structure St where
  out : String := ""
  indent : Nat := 1
  usesStart : Bool := false

abbrev EmitM := ReaderT Ctx (StateT St (Except String))

def emitLn (s : String) : EmitM Unit :=
  modify fun st => { st with out := st.out ++ String.ofList (List.replicate st.indent '\t') ++ s ++ "\n" }

def emitLabel (s : String) : EmitM Unit :=
  modify fun st => { st with out := st.out ++ s ++ ":\n" }

def indented (k : EmitM Unit) : EmitM Unit := do
  modify fun st => { st with indent := st.indent + 1 }
  k
  modify fun st => { st with indent := st.indent - 1 }

def liftExcept (e : Except String α) : EmitM α :=
  match e with
  | .ok a => pure a
  | .error msg => throw msg

def argStr (y : Arg) (expected : IRType) : EmitM String := do
  match y with
  | .erased => return zero expected
  | .var x =>
    let actual := (← read).varTypes.getD x.idx .object
    if actual.isErased || actual.isVoid then return zero expected
    return varName x

def bindArgs (ps : Array Param) (ys : Array Arg) : EmitM Unit := do
  let pairs := (ps.zip ys).filter fun (p, y) => liveParam p && y != .var p.x
  unless pairs.isEmpty do
    let args ← pairs.mapM fun (p, y) => argStr y p.ty
    emitLn s!"{joinArgs (pairs.map (varName ·.1.x))} = {joinArgs args}"

def callArgs (d : Decl) (ys : Array Arg) : EmitM (Array String) :=
  ((d.params.zip ys).filter (liveParam ·.1)).mapM fun (p, y) => argStr y p.ty

def slice (args : Array String) : String :=
  if args.isEmpty then "nil" else "[]rt.V{" ++ joinArgs args ++ "}"

def valueArgs (ys : Array Arg) : EmitM String := do
  return slice (← ys.mapM (argStr · .object))

def targetDecl (c : Name) : EmitM Decl := do
  let some d := (← read).decls[c]? | throw s!"function was not collected: {c}"
  return d

def emitVDecl (x : VarId) (ty : IRType) (e : IR.Expr) : EmitM Unit := do
  let xs := varName x
  let rhs ← match e with
    | .ctor info _ =>
      if ty.isScalar then pure (toString info.cidx)
      else if info.isScalar then pure s!"rt.Lean_box({info.cidx})"
      else pure s!"rt.Lean_alloc_ctor({info.cidx}, {info.size}, {8 * info.usize + info.ssize})"
    | .reset n y => pure s!"rt.Reset({varName y}, {n})"
    | .reuse y info update _ =>
      pure s!"rt.Reuse({varName y}, {info.cidx}, {info.size}, {8 * info.usize + info.ssize}, {update})"
    | .proj i y => pure s!"rt.Lean_ctor_get({varName y}, {i})"
    | .uproj i y => pure s!"rt.Lean_ctor_get_usize({varName y}, {i})"
    | .sproj n offset y =>
      let suffix ← liftExcept (scalarSuffix ty)
      pure s!"rt.Lean_ctor_get_{suffix}({varName y}, {8 * n + offset})"
    | .fap c ys =>
      let d ← targetDecl c
      pure s!"{methodName (← read).internalOnly c}({joinArgs (← callArgs d ys)})"
    | .pap c ys =>
      let d ← targetDecl c
      pure s!"rt.Closure({adapterName c}, {d.params.size}, {← valueArgs ys})"
    | .ap f ys => pure s!"rt.Lean_apply({varName f}, {← valueArgs ys})"
    | .box t y => pure (box t (varName y))
    | .unbox y => pure (unbox ty (varName y))
    | .lit v => pure (litGo ty v)
    | .isShared y => pure s!"rt.Bool(!rt.Lean_is_exclusive({varName y}))"
  if ty.isVoid then
    if let .fap .. := e then emitLn rhs
    else if let .ap .. := e then emitLn rhs
  else if ty.isErased then
    if let .fap .. := e then emitLn rhs
    else if let .ap .. := e then emitLn rhs
  else
    emitLn s!"{xs} = {rhs}"
  match e with
  | .ctor _ ys | .reuse _ _ _ ys =>
    for (y, i) in ys.zipIdx do
      emitLn s!"rt.Lean_ctor_set({xs}, {i}, {← argStr y .object})"
  | _ => pure ()

partial def tailReturns (x : VarId) : FnBody → Bool
  | .ret (.var r) => x == r
  | .del _ k => tailReturns x k
  | _ => false

partial def jmpRefs (b : FnBody) (acc : Std.HashSet Nat) : Std.HashSet Nat :=
  match b with
  | .jdecl _ _ _ k => jmpRefs k acc
  | .case _ _ _ alts => alts.foldl (fun a alt => jmpRefs alt.body a) acc
  | .jmp j _ => acc.insert j.idx
  | .ret _ | .unreachable => acc
  | b => jmpRefs b.body acc

partial def reachableJps (body : FnBody)
    (jps : Std.HashMap Nat (Array Param × FnBody × Nat)) : Std.HashSet Nat := Id.run do
  let mut next := jmpRefs body {}
  let mut done : Std.HashSet Nat := {}
  while !next.isEmpty do
    let prev := next
    next := {}
    for j in prev do
      unless done.contains j do
        done := done.insert j
        if let some (_, b, _) := jps[j]? then
          next := jmpRefs b next
  return done

def emitUnreachable : EmitM Unit := do
  emitLn "rt.Lean_internal_panic_unreachable()"
  let ty := (← read).resultType
  emitLn (if ty.isVoid then "return" else s!"return {zero ty}")

partial def emitBody (b : FnBody) : EmitM Unit := do
  let ctx ← read
  match b with
  | .vdecl x ty e k =>
    if ctx.canTail && !ty.isVoid && tailReturns x k then
      match e with
      | .fap c ys =>
        if c == ctx.self then
          bindArgs ctx.selfParams ys
          modify fun st => { st with usesStart := true }
          emitLn "goto _start"
          return
        if ctx.hasFrame && ctx.tailTargets.contains c then
          let d ← targetDecl c
          let args ← (d.params.zip ys |>.filter (liveParam ·.1)).mapM fun (p, y) => do
            return box p.ty (← argStr y p.ty)
          emitLn s!"rt.TailCall(frame, {tailName c}, {slice args})"
          emitLn s!"return {zero ctx.resultType}"
          return
      | .ap f ys =>
        if ctx.hasFrame then
          let call := s!"rt.TailApply(frame, {varName f}, {← valueArgs ys})"
          emitLn s!"return {unbox ctx.resultType call}"
          return
      | _ => pure ()
    emitVDecl x ty e
    emitBody k
  | .jdecl _ _ _ k => emitBody k
  | .set x i y k =>
    emitLn s!"rt.Lean_ctor_set({varName x}, {i}, {← argStr y .object})"
    emitBody k
  | .uset x i y k =>
    emitLn s!"rt.Lean_ctor_set_usize({varName x}, {i}, {varName y})"
    emitBody k
  | .sset x n off y ty k =>
    let suffix ← liftExcept (scalarSuffix ty)
    emitLn s!"rt.Lean_ctor_set_{suffix}({varName x}, {8 * n + off}, {varName y})"
    emitBody k
  | .setTag x tag k =>
    emitLn s!"rt.Lean_ctor_set_tag({varName x}, {tag})"
    emitBody k
  | .inc x n _ p k =>
    unless p do
      if n == 1 then emitLn s!"rt.Lean_inc({varName x})"
      else emitLn s!"rt.Lean_inc_n({varName x}, {n})"
    emitBody k
  | .dec x n _ p k =>
    unless p do
      if n == 1 then emitLn s!"rt.Lean_dec({varName x})"
      else
        emitLn s!"for range {n} \{"
        indented (emitLn s!"rt.Lean_dec({varName x})")
        emitLn "}"
    emitBody k
  | .del _ k => emitBody k
  | .case _ x t alts =>
    let arg ← argStr (.var x) t
    let actual := ctx.varTypes.getD x.idx t
    let scrut := if actual.isScalar then arg else s!"rt.Lean_obj_tag({arg})"
    emitLn s!"switch {scrut} \{"
    let mut hasDefault := false
    for alt in alts do
      match alt with
      | .ctor info body =>
        emitLn s!"case {info.cidx}:"
        indented (emitBody body)
      | .default body =>
        hasDefault := true
        emitLn "default:"
        indented (emitBody body)
    unless hasDefault do
      emitLn "default:"
      indented emitUnreachable
    emitLn "}"
  | .ret y =>
    if ctx.resultType.isVoid then emitLn "return"
    else emitLn s!"return {← argStr y ctx.resultType}"
  | .jmp j ys =>
    if let some (xs, body) := ctx.inlineJps[j.idx]? then
      bindArgs xs ys
      emitBody body
    else
      let some xs := ctx.labelParams[j.idx]? | throw s!"unknown join point {j.idx}"
      bindArgs xs ys
      emitLn s!"goto _jp_{j.idx}"
  | .unreachable => emitUnreachable

structure TailEdges where
  direct : Std.HashSet Name := {}
  apply : Bool := false

partial def tailEdges (b : FnBody) (edges : TailEdges) : TailEdges :=
  match b with
  | .vdecl x ty e k =>
    let edges := if !ty.isVoid && tailReturns x k then
      match e with
      | .fap c _ => { edges with direct := edges.direct.insert c }
      | .ap .. => { edges with apply := true }
      | _ => edges
      else edges
    tailEdges k edges
  | .jdecl _ _ v k => tailEdges k (tailEdges v edges)
  | .case _ _ _ alts => alts.foldl (fun a alt => tailEdges alt.body a) edges
  | .ret _ | .jmp .. | .unreachable => edges
  | b => tailEdges b.body edges

partial def closures (b : FnBody) (acc : Std.HashSet Name) : Std.HashSet Name :=
  match b with
  | .vdecl _ _ (.pap c _) k => closures k (acc.insert c)
  | .jdecl _ _ v k => closures k (closures v acc)
  | .case _ _ _ alts => alts.foldl (fun a alt => closures alt.body a) acc
  | .ret _ | .jmp .. | .unreachable => acc
  | b => closures b.body acc

def functionHeader (name : String) (params : Array String) (ty : IRType) : String :=
  let result := if ty.isVoid then "" else " " ++ goType ty
  s!"func {name}({joinArgs params}){result} \{\n"

def parameters (ps : Array Param) : Array String :=
  (ps.filter liveParam).map fun p => s!"{varName p.x} {goType p.ty}"

def callResult (call : String) (ty : IRType) : String :=
  if ty.isVoid then call else "return " ++ call

def emitAdapter (d : Decl) (name callee : String) (passesFrame releases dropsErased : Bool) :
    String := Id.run do
  let params := if dropsErased then (d.params.filter liveParam) else d.params
  let mut args := if passesFrame then #["frame"] else #[]
  let mut body := ""
  for (p, i) in params.zipIdx do
    if liveParam p then
      let a := s!"args[{i}]"
      args := args.push (unbox p.ty a)
      if releases && p.borrow && p.ty.isPossibleRef then
        body := body ++ s!"\tdefer rt.Lean_dec({a})\n"
  let frame := if passesFrame then "frame" else "_"
  let argsParam := if args.size > (if passesFrame then 1 else 0) then "args" else "_"
  let header := functionHeader name #[s!"{frame} *rt.Tail", s!"{argsParam} []rt.V"] .object
  let call := s!"{callee}({joinArgs args})"
  if d.resultType.isVoid then
    return header ++ body ++ s!"\t{call}\n\treturn rt.V\{}\n}\n"
  return header ++ body ++ s!"\treturn {box d.resultType call}\n}\n"

def emitExtern (env : Environment) (decls : Std.HashMap Name Decl)
    (exports : Std.HashMap String Name) (internalOnly : Bool) (d : Decl) : Except String String := do
  let some sym := externSymbol env d.name | throw s!"extern without a C symbol: {d.name}"
  let live := d.params.filter liveParam
  let mut callee := runtimeName sym
  let args := live.map (varName ·.x)
  let mut ownership := ""
  if let some target := exports[sym]? then
    let t := decls[target]!
    let ts := t.params.filter liveParam
    if ts.size != live.size then throw s!"incompatible IR arity for exported extern {sym}"
    callee := methodName internalOnly target
    for (p, tp) in live.zip ts do
      if p.ty.isPossibleRef && p.borrow != tp.borrow then
        let x := varName p.x
        let code := if p.borrow then s!"rt.Lean_inc({x})" else s!"defer rt.Lean_dec({x})"
        ownership := ownership ++ s!"\t{code}\n"
  let call := s!"{callee}({joinArgs args})"
  let header := functionHeader (methodName internalOnly d.name) (parameters d.params) d.resultType
  return header ++ ownership ++ s!"\t{callResult call d.resultType}\n}\n"

def storeValue (ty : IRType) (value : String) : String :=
  if ty.isScalar then value else s!"rt.Lean_mark_persistent({value})"

def emitDecl (env : Environment) (decls : Std.HashMap Name Decl)
    (exports : Std.HashMap String Name)
    (tailTargets cores papTargets initGlobals : Std.HashSet Name) (internalOnly : Bool)
    (d : Decl) : Except String String := do
  let n := d.name
  let ps := d.params
  let ty := d.resultType
  unless supportedType ty && ps.all (fun p => supportedType p.ty) do
    throw s!"unsupported aggregate IR type in {n}"
  let name := methodName internalOnly n
  let header := functionHeader name (parameters ps) ty
  let core := cores.contains n
  let stored := ps.isEmpty && (match d with | .fdecl .. => true | _ => false)
  if stored && ty.isVoid then throw s!"unsupported void global in {n}"
  let mut pieces := #[]
  match d with
  | .extern .. =>
    pieces := pieces.push (← emitExtern env decls exports internalOnly d)
  | .fdecl _ _ _ body _ =>
    if stored then
      pieces := pieces.push s!"var {globalName n} {goType ty}\n"
      pieces := pieces.push (header ++ s!"\treturn {globalName n}\n}\n")
    unless initGlobals.contains n do
      let jps := joinPoints body {}
      let reachable := reachableJps body jps
      let mut inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}
      let mut labelParams : Std.HashMap Nat (Array Param) := {}
      let mut blocks := #[]
      for (i, (xs, v, count)) in jps.toList.mergeSort (fun a b => a.1 ≤ b.1) do
        if reachable.contains i then
          if count == 1 && !(joinPoints v {}).contains i then
            inlineJps := inlineJps.insert i (xs, v)
          else
            labelParams := labelParams.insert i xs
            blocks := blocks.push (i, v)
      let locals := bodyVars body {}
      let varTypes := ps.foldl (fun m p => m.insert p.x.idx p.ty) locals
      unless locals.toList.all (supportedType ∘ Prod.snd) do
        throw s!"unsupported aggregate IR type in {n}"
      let ctx : Ctx := {
        decls, tailTargets, self := n, selfParams := ps, resultType := ty, hasFrame := core,
        canTail := !stored, inlineJps, labelParams, varTypes, internalOnly
      }
      let emit : EmitM Unit := do
        emitBody body
        for (i, v) in blocks do
          emitLabel s!"_jp_{i}"
          emitBody v
      let ((), st) ← (emit.run ctx).run {}
      let mut variables := ""
      for (i, t) in locals.toList.mergeSort (fun a b => a.1 ≤ b.1) do
        unless t.isErased || t.isVoid do
          variables := variables ++ s!"\tvar x_{i} {goType t}\n\t_ = x_{i}\n"
      let start := if st.usesStart then "_start:\n" else ""
      let implementationHeader :=
        if core then functionHeader (coreName n) (#["frame *rt.Tail"] ++ parameters ps) ty
        else if stored then functionHeader (computeName n) #[] ty
        else header
      if core then
        let boxed := (ps.filter liveParam).map fun p => box p.ty (varName p.x)
        let call := s!"rt.Run({tailName n}, {slice boxed})"
        pieces := pieces.push (header ++ s!"\treturn {unbox ty call}\n}\n")
        pieces := pieces.push (emitAdapter d (tailName n) (coreName n) true false true)
      pieces := pieces.push (implementationHeader ++ variables ++ start ++ st.out ++ "}\n")
  if papTargets.contains n then
    let borrowed := ps.any fun p => liveParam p && p.borrow && p.ty.isPossibleRef
    let useCore := core && !borrowed
    let callee := if useCore then coreName n else name
    pieces := pieces.push (emitAdapter d (adapterName n) callee useCore true false)
  return "\n".intercalate pieces.toList

structure Initializers where
  roots : Array Name := #[]
  globals : Std.HashSet Name := {}
  entries : Array (Name × Name) := #[]

partial def importedModules (env : Environment) (mod : Name) (seen : Std.HashSet Nat) :
    Std.HashSet Nat := Id.run do
  let some idx := env.getModuleIdx? mod | return seen
  if seen.contains idx.toNat then return seen
  let mut seen := seen.insert idx.toNat
  for imp in env.header.moduleData[idx.toNat]!.imports do
    unless imp.isMeta do
      seen := importedModules env imp.module seen
  return seen

def initializers (env : Environment) (mod : Name) (reached : Std.HashSet Name) : Initializers := Id.run do
  let modules := importedModules env mod {}
  let mut result : Initializers := {}
  for i in [0:env.header.moduleNames.size] do
    unless modules.contains i do continue
    let entries := regularInitAttr.ext.getModuleEntries env i
    let entries := entries ++ (regularInitAttr.ext.getModuleIREntries env i).filter (!entries.contains ·)
    let stdlib := (`Init).isPrefixOf env.header.moduleNames[i]!
    for (n, init) in entries do
      if isIOUnitBuiltinInitFn env n || isMarkedMeta env n || (stdlib && !reached.contains n) then continue
      result := { result with roots := result.roots.push n, entries := result.entries.push (n, init) }
      unless init.isAnonymous do
        result := { result with roots := result.roots.push init, globals := result.globals.insert n }
  return result

structure InitOrder where
  seen : Std.HashSet Name := {}
  lines : String := ""

partial def scheduleValue (env : Environment) (decls : Std.HashMap Name Decl)
    (exports : Std.HashMap String Name) (initializers : Initializers) (name : Name) (st : InitOrder) :
    InitOrder := Id.run do
  if st.seen.contains name then return st
  let mut st := { st with seen := st.seen.insert name }
  if initializers.globals.contains name then return st
  match decls[name]? with
  | some (.fdecl _ ps ty body _) =>
    for c in bodyCallees body #[] do
      st := scheduleValue env decls exports initializers c st
    if ps.isEmpty then
      let call := s!"{computeName name}()"
      st := { st with lines := st.lines ++ s!"\t{globalName name} = {storeValue ty call}\n" }
  | some (.extern ..) =>
    if let some c := (externSymbol env name).bind (exports[·]?) then
      st := scheduleValue env decls exports initializers c st
  | none => pure ()
  return st

def emitInitializers (env : Environment) (decls : Array Decl) (declMap : Std.HashMap Name Decl)
    (exports : Std.HashMap String Name) (inits : Initializers) (internalOnly : Bool) : Except String String := do
  let mut st : InitOrder := {}
  for (n, action) in inits.entries do
    let target := if action.isAnonymous then n else action
    let d := declMap[target]!
    unless (d.params.filter liveParam).isEmpty && !d.resultType.isScalar && !d.resultType.isVoid do
      throw s!"unsupported initializer signature for {target}"
    st := scheduleValue env declMap exports inits target st
    let result := s!"rt.InitResult({methodName internalOnly target}())"
    let line := if action.isAnonymous then result else
      let ty := declMap[n]!.resultType
      s!"{globalName n} = {storeValue ty (unbox ty result)}"
    st := { st with lines := st.lines ++ s!"\t{line}\n" }
  for d in decls do
    st := scheduleValue env declMap exports inits d.name st
  return if st.lines.isEmpty then "" else s!"func init() \{\n\trt.SetInitializing(true)\n\tdefer rt.SetInitializing(false)\n{st.lines}}\n"

def emitMain (env : Environment) (d : Decl) (internalOnly : Bool) : Except String String := do
  let n := d.name
  let some info := env.find? n | throw s!"unknown main declaration: {n}"
  let hasArgs := match info.type with | .forallE .. => true | _ => false
  if hasArgs then
    let .forallE _ arg _ _ := info.type | throw s!"missing List String parameter to {n}"
    unless arg.isAppOfArity `List 1 && arg.appArg!.isConstOf `String do
      throw s!"expected {n} to take List String arguments"
  let ty := info.type.getForallBody
  unless ty.isAppOfArity `IO 1 && (d.params.filter liveParam).size == (if hasArgs then 1 else 0) do
    throw s!"expected {n} to have type IO Unit, IO UInt32, or take List String arguments"
  let returnsCode := ty.appArg!.isConstOf `UInt32
  unless returnsCode || ty.appArg!.isConstOf `Unit || ty.appArg!.isAppOf `PUnit do
    throw s!"expected {n} to return IO Unit or IO UInt32"
  let args := if hasArgs then "args" else ""
  let argDecl := if hasArgs then "args" else "_"
  return s!"func main() \{\n\trt.Lean_run_main(func({argDecl} rt.V, _ rt.V) rt.V \{\n\t\treturn {methodName internalOnly n}({args})\n\t}, {hasArgs}, {returnsCode})\n}\n"

def generate (env : Environment) (mod : Name) (roots : Array Name) (pkg : String)
    (main? : Option Name) (generatorVersion : String) (internalOnly : Bool) : Except String String := do
  let targets := roots.map (csimpTarget env)
  let exports := exportedFns env
  let baseRoots := roots ++ targets ++ main?.toArray
  let mut inits := initializers env mod {}
  let mut decls ← collect env exports (baseRoots ++ inits.roots)
  repeat
    let reached := decls.foldl (fun s d => s.insert d.name) ({} : Std.HashSet Name)
    let next := initializers env mod reached
    if next.entries.size == inits.entries.size then break
    inits := next
    decls ← collect env exports (baseRoots ++ inits.roots)
  let mut missing : Array String := #[]
  for d in decls do
    if let .extern f .. := d then
      let some sym := externSymbol env f | throw s!"extern without a C symbol: {f}"
      unless exports.contains sym || runtimeExterns.contains sym || missing.contains sym do
        missing := missing.push sym
  unless missing.isEmpty do
    throw s!"externs not in the runtime: {joinArgs (missing.qsort (· < ·))}"
  let declMap := decls.foldl (fun m d => m.insert d.name d) ({} : Std.HashMap Name Decl)
  let mut edges : Std.HashMap Name TailEdges := {}
  let mut papTargets : Std.HashSet Name := {}
  for d in decls do
    if let .fdecl f ps ty body _ := d then
      unless inits.globals.contains f do
        papTargets := closures body papTargets
        unless ps.isEmpty || ty.isVoid do
          edges := edges.insert f (tailEdges body {})
  let mut tailTargets : Std.HashSet Name := {}
  for (f, calls) in edges.toList do
    for c in calls.direct do
      if c != f && edges.contains c then
        tailTargets := tailTargets.insert c
  let mut cores := tailTargets
  for (f, calls) in edges.toList do
    if calls.apply || calls.direct.toList.any (fun c => c != f && tailTargets.contains c) then
      cores := cores.insert f
  let mut items ← decls.mapM (emitDecl env declMap exports tailTargets cores papTargets inits.globals internalOnly)
  let init ← emitInitializers env decls declMap exports inits internalOnly
  unless init.isEmpty do items := items.push init
  if let some m := main? then
    items := items.push (← emitMain env declMap[m]! internalOnly)
  let body := "\n".intercalate items.toList
  let imports := if (body.splitOn "rt.").length > 1 then "\nimport \"github.com/conao3/leanfran-go/rt\"\n" else ""
  let moduleLabel := (toString mod).replace "\n" "\\n" |>.replace "\r" "\\r"
  let header := s!"// Code generated by leanfran-go (generator {generatorVersion}) from {moduleLabel}. DO NOT EDIT.\n\npackage {pkg}\n{imports}"
  return if body.isEmpty then header else header ++ "\n" ++ body

end LeanGo
