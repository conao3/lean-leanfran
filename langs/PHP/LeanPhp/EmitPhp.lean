import Lean
import LeanPhp.RuntimeExterns

open Lean Lean.IR

namespace LeanPhp

def hex2 (n : Nat) (width : Nat) : String :=
  let s := String.ofList (Nat.toDigits 16 n)
  String.ofList (List.replicate (width - s.length) '0') ++ s

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

def liveParam (p : Param) : Bool := !(p.ty.isErased || p.ty.isVoid)

def varName (x : VarId) : String := s!"$x_{x.idx}"

def joinArgs (xs : Array String) : String := ", ".intercalate xs.toList

def asciiUpper (c : Char) : Bool := 'A' ≤ c && c ≤ 'Z'

def caseSuffix (s : String) : String :=
  "__c" ++ hex2 (s.toList.foldl (fun n c => 2 * n + if asciiUpper c then 1 else 0) 0) 1

def methodNames (decls : Array Decl) : Except String (Std.HashMap Name String) := do
  let mut counts : Std.HashMap String Nat := {}
  for d in decls do
    let key := (d.name.mangle "l_").toLower
    counts := counts.insert key (counts.getD key 0 + 1)
  let mut used : Std.HashSet String := {}
  let mut methods : Std.HashMap Name String := {}
  for d in decls do
    let base := d.name.mangle "l_"
    let name := if counts.getD base.toLower 0 > 1 then base ++ caseSuffix base else base
    if used.contains name.toLower then throw s!"PHP method name collision: {name}"
    used := used.insert name.toLower
    methods := methods.insert d.name name
  return methods

def quoteBytes (s : String) : String := Id.run do
  let mut acc := "\""
  for b in s.toUTF8 do
    let n := b.toNat
    acc := acc ++
      if n == 34 then "\\\""
      else if n == 36 then "\\$"
      else if n == 92 then "\\\\"
      else if n == 10 then "\\n"
      else if n < 32 || n ≥ 127 then "\\x" ++ hex2 n 2
      else (Char.ofNat n).toString
  return acc ++ "\""

def phpType : IRType → String
  | .uint8 | .uint16 | .uint32 | .uint64 | .usize => "int"
  | .float | .float32 => "float"
  | _ => "mixed"

def scalarSuffix : IRType → Except String String
  | .uint8 => .ok "uint8"
  | .uint16 => .ok "uint16"
  | .uint32 => .ok "uint32"
  | .uint64 => .ok "uint64"
  | .float => .ok "float"
  | .float32 => .ok "float32"
  | t => .error s!"unsupported scalar field type: {repr t}"

def litStr (ty : IRType) : LitVal → String
  | .str s => s!"L\\lean_mk_string({quoteBytes s})"
  | .num n =>
    match ty with
    | .uint64 | .usize =>
      let v := n % (2 ^ 64)
      if v == 2 ^ 63 then "\\PHP_INT_MIN"
      else if v > 2 ^ 63 then s!"-{2 ^ 64 - v}"
      else toString v
    | .float | .float32 => s!"{n}.0"
    | _ => if n < 2 ^ 63 then toString n else s!"\\gmp_init(\"{n}\", 10)"

structure Ctx where
  decls : Std.HashMap Name Decl
  methods : Std.HashMap Name String
  directExterns : Std.HashMap Name String
  tailTargets : Std.HashSet Name
  cores : Std.HashSet Name
  self : Name
  selfParams : Array Param
  inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}
  labelParams : Std.HashMap Nat (Array Param) := {}
  varTypes : Std.HashMap Nat IRType := {}
  constBody : Bool := false

structure St where
  out : String := ""
  indent : Nat := 2

abbrev EmitM := ReaderT Ctx (StateT St (Except String))

def emitLn (s : String) : EmitM Unit :=
  modify fun st => { st with out := st.out ++ String.ofList (List.replicate (4 * st.indent) ' ') ++ s ++ "\n" }

def indented (k : EmitM Unit) : EmitM Unit := do
  modify fun st => { st with indent := st.indent + 1 }
  k
  modify fun st => { st with indent := st.indent - 1 }

def liftExcept (e : Except String α) : EmitM α :=
  match e with
  | .ok a => pure a
  | .error msg => throw msg

def argStr : Arg → EmitM String
  | .erased => pure "0"
  | .var x => do
    let t := (← read).varTypes.getD x.idx .object
    return if t.isErased || t.isVoid then "0" else varName x

def bindArgs (ps : Array Param) (ys : Array Arg) : EmitM Unit := do
  let pairs := (ps.zip ys).filter (liveParam ·.1)
  for ((_, arg), i) in pairs.zipIdx do
    emitLn s!"$_tmp_{i} = {← argStr arg};"
  for ((p, _), i) in pairs.zipIdx do
    emitLn s!"{varName p.x} = $_tmp_{i};"

def methodRef (methods : Std.HashMap Name String) (n : Name) : String :=
  "self::" ++ methods[n]!

def coreName (method : String) : String := "tc_" ++ method

def coreRef (methods : Std.HashMap Name String) (n : Name) : String :=
  "self::" ++ coreName methods[n]!

def callArgs (d : Decl) (ys : Array Arg) : EmitM String := do
  return joinArgs (← ((d.params.zip ys).filter (liveParam ·.1)).mapM (argStr ·.2))

def emitVDecl (x : VarId) (ty : IRType) (e : IR.Expr) : EmitM Unit := do
  let ctx ← read
  let xs := varName x
  let rhs ← match e with
    | .ctor info ys =>
      let aggregate := match ty with
        | .struct .. | .union .. => true
        | _ => false
      if info.isScalar && !aggregate then pure (toString info.cidx)
      else pure s!"new L\\Ctor({info.cidx}, [{joinArgs (← ys.mapM argStr)}])"
    | .reset n y => pure s!"L\\lean_reset({varName y}, {n})"
    | .reuse y info update ys =>
      pure s!"L\\lean_reuse({varName y}, {info.cidx}, {update}, [{joinArgs (← ys.mapM argStr)}])"
    | .proj i y => pure s!"L\\lean_ctor_get({varName y}, {i})"
    | .uproj i y => pure s!"L\\lean_ctor_get_usize({varName y}, {i})"
    | .sproj n offset y =>
      let suffix ← liftExcept (scalarSuffix ty)
      pure s!"L\\lean_ctor_get_{suffix}({varName y}, {8 * n + offset})"
    | .fap c ys =>
      let some d := ctx.decls[c]? | throw s!"function was not collected: {c}"
      let fn := match ctx.directExterns[c]? with
        | some sym => "L\\" ++ sym
        | none => methodRef ctx.methods c
      pure s!"{fn}({← callArgs d ys})"
    | .pap c ys =>
      let some d := ctx.decls[c]? | throw s!"function was not collected: {c}"
      let params := d.params
      let borrowed := params.filter fun p => liveParam p && p.borrow && p.ty.isPossibleRef
      let fn := if ctx.cores.contains c && borrowed.isEmpty then coreRef ctx.methods c else methodRef ctx.methods c
      let callable :=
        if borrowed.isEmpty && params.all liveParam then fn ++ "(...)"
        else
          let args := joinArgs (params.map fun p => varName p.x)
          let liveArgs := joinArgs (params.filter liveParam |>.map fun p => varName p.x)
          let releases := String.join (borrowed.toList.map fun p => s!" L\\lean_dec({varName p.x});")
          s!"static function ({args}) \{ $result = {fn}({liveArgs});{releases} return $result; }"
      pure s!"new L\\LClosure({callable}, {params.size}, [{joinArgs (← ys.mapM argStr)}])"
    | .ap f ys => pure s!"L\\lean_apply({varName f}, [{joinArgs (← ys.mapM argStr)}])"
    | .box _ y | .unbox y => argStr (.var y)
    | .lit v => pure (litStr ty v)
    | .isShared y => pure s!"L\\lean_is_shared({varName y})"
  if ty.isErased || ty.isVoid then
    emitLn (rhs ++ ";")
  else
    emitLn s!"{xs} = {rhs};"

partial def tailReturns (x : VarId) : FnBody → Bool
  | .ret (.var r) => x == r
  | .inc y _ _ _ k => x != y && tailReturns x k
  | .dec y _ _ _ k => x != y && tailReturns x k
  | .del _ k => tailReturns x k
  | _ => false

def emitInc (x : VarId) (n : Nat) (persistent : Bool) : EmitM Unit := do
  unless persistent do
    if n == 1 then emitLn s!"L\\lean_inc({varName x});"
    else emitLn s!"L\\lean_inc_n({varName x}, {n});"

partial def emitTrailingIncs : FnBody → EmitM Unit
  | .inc x n _ p k => do
    emitInc x n p
    emitTrailingIncs k
  | .dec _ _ _ _ k | .del _ k => emitTrailingIncs k
  | _ => pure ()

partial def emitBody (b : FnBody) : EmitM Unit := do
  let ctx ← read
  match b with
  | .vdecl x ty e k =>
    if !ctx.constBody && tailReturns x k then
      match e with
      | .fap c ys =>
        if c == ctx.self then
          emitTrailingIncs k
          bindArgs ctx.selfParams ys
          emitLn "goto _start;"
          return
        if ctx.tailTargets.contains c then
          emitTrailingIncs k
          emitLn s!"return new L\\TailCall({coreRef ctx.methods c}(...), [{← callArgs ctx.decls[c]! ys}]);"
          return
      | .ap f ys =>
        emitTrailingIncs k
        emitLn s!"return new L\\TailApply({varName f}, [{joinArgs (← ys.mapM argStr)}]);"
        return
      | _ => pure ()
    emitVDecl x ty e
    emitBody k
  | .jdecl _ _ _ k => emitBody k
  | .set x i y k =>
    emitLn s!"L\\lean_ctor_set({varName x}, {i}, {← argStr y});"
    emitBody k
  | .uset x i y k =>
    emitLn s!"L\\lean_ctor_set_usize({varName x}, {i}, {varName y});"
    emitBody k
  | .sset x n off y ty k =>
    let suffix ← liftExcept (scalarSuffix ty)
    emitLn s!"L\\lean_ctor_set_{suffix}({varName x}, {8 * n + off}, {varName y});"
    emitBody k
  | .setTag x tag k =>
    emitLn s!"L\\lean_ctor_set_tag({varName x}, {tag});"
    emitBody k
  | .inc x n _ p k =>
    emitInc x n p
    emitBody k
  | .dec x _ _ p k =>
    unless p do emitLn s!"L\\lean_dec({varName x});"
    emitBody k
  | .del _ k => emitBody k
  | .case _ x t alts =>
    let arg ← argStr (.var x)
    let ty := ctx.varTypes.getD x.idx t
    let scrut := if t.isScalar || ty.isScalar then arg else s!"L\\lean_obj_tag({arg})"
    emitLn s!"switch ({scrut}) \{"
    indented do
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
        indented (emitLn "L\\lean_internal_panic_unreachable();")
    emitLn "}"
  | .ret y =>
    let result ← argStr y
    if ctx.constBody then
      emitLn s!"return $_value = L\\lean_mark_persistent({result});"
    else emitLn s!"return {result};"
  | .jmp j ys =>
    if let some (xs, body) := ctx.inlineJps[j.idx]? then
      bindArgs xs ys
      emitBody body
    else
      let some xs := ctx.labelParams[j.idx]? | throw s!"unknown join point {j.idx}"
      bindArgs xs ys
      emitLn s!"goto _jp_{j.idx};"
  | .unreachable => emitLn "L\\lean_internal_panic_unreachable();"

structure TailEdges where
  direct : Std.HashSet Name := {}
  apply : Bool := false

partial def tailEdges (b : FnBody) (edges : TailEdges) : TailEdges :=
  match b with
  | .vdecl x _ e k =>
    let edges := if tailReturns x k then
      match e with
      | .fap c _ => { edges with direct := edges.direct.insert c }
      | .ap .. => { edges with apply := true }
      | _ => edges
      else edges
    tailEdges k edges
  | .jdecl _ _ v k => tailEdges k (tailEdges v edges)
  | .case _ _ _ alts => alts.foldl (fun acc a => tailEdges a.body acc) edges
  | .ret _ | .jmp .. | .unreachable => edges
  | b => tailEdges b.body edges

def declarationHeader (method : String) (ps : Array Param) (ty : IRType) (isPublic := true) : String :=
  let args := joinArgs ((ps.filter liveParam).map fun p => s!"{phpType p.ty} {varName p.x}")
  let access := if isPublic then "public" else "private"
  s!"    {access} static function {method}({args}): {phpType ty}\n    \{\n"

def emitDecl (env : Environment) (decls : Std.HashMap Name Decl) (methods : Std.HashMap Name String)
    (exports : Std.HashMap String Name) (directExterns : Std.HashMap Name String)
    (edges : Std.HashMap Name TailEdges) (tailTargets cores : Std.HashSet Name)
    (initGlobals : Std.HashSet Name) (d : Decl) : Except String String := do
  let header := declarationHeader methods[d.name]! d.params d.resultType
  match d with
  | .extern f ps ty _ =>
    let some sym := externSymbol env f | throw s!"extern without a C symbol: {f}"
    let live := ps.filter liveParam
    let mut callee := "L\\" ++ sym
    let mut args := live.map (varName ·.x)
    let mut trailing := ""
    if let some target := exports[sym]? then
      let t := decls[target]!
      let ts := t.params.filter liveParam
      if ts.size != live.size then throw s!"incompatible IR arity for exported extern {sym}"
      callee := methodRef methods target
      args := (live.zip ts).map fun (p, tp) =>
        if p.borrow && !tp.borrow && tp.ty.isPossibleRef then s!"L\\lean_inc_ret({varName p.x})"
        else varName p.x
      trailing := String.join ((live.zip ts).toList.filterMap fun (p, tp) =>
        if !p.borrow && tp.borrow && p.ty.isPossibleRef then some s!"        L\\lean_dec({varName p.x});\n"
        else none)
    let call := s!"{callee}({joinArgs args})"
    if ty.isVoid then return header ++ s!"        {call};\n{trailing}        return 0;\n    }\n"
    if trailing.isEmpty then return header ++ s!"        return {call};\n    }\n"
    return header ++ s!"        $result = {call};\n{trailing}        return $result;\n    }\n"
  | .fdecl f ps _ body _ =>
    if initGlobals.contains f then
      return header ++ s!"        return self::$_initValues[{quoteBytes methods[f]!}] ?? throw new \\LogicException('Lean initializer has not run.');\n    }\n"
    let jps := joinPoints body {}
    let mut inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}
    let mut labelParams : Std.HashMap Nat (Array Param) := {}
    let mut blocks := #[]
    for (i, (xs, v, n)) in jps.toList.mergeSort (fun a b => a.1 ≤ b.1) do
      if n == 1 && !(joinPoints v {}).contains i then
        inlineJps := inlineJps.insert i (xs, v)
      else if n > 0 then
        labelParams := labelParams.insert i xs
        blocks := blocks.push (i, v)
    let varTypes := ps.foldl (fun m p => m.insert p.x.idx p.ty) (bodyVars body {})
    let ctx : Ctx := {
      decls, methods, directExterns, tailTargets, cores
      self := f, selfParams := ps, inlineJps, labelParams, varTypes
      constBody := ps.isEmpty
    }
    let emit : EmitM Unit := do
      if ctx.constBody then
        emitLn "static $_value;"
        emitLn "if ($_value !== null) {"
        indented (emitLn "return $_value;")
        emitLn "}"
      if (edges.getD f {}).direct.contains f then emitLn "_start:"
      emitBody body
      for (i, v) in blocks do
        emitLn s!"_jp_{i}:"
        emitBody v
    let ((), st) ← (emit.run ctx).run {}
    if cores.contains f then
      let args := joinArgs ((ps.filter liveParam).map (varName ·.x))
      let wrapper := s!"        return L\\lean_trampoline({coreRef methods f}({args}));\n    }\n\n"
      let core := declarationHeader (coreName methods[f]!) ps .object false
      return header ++ wrapper ++ core ++ st.out ++ "    }\n"
    return header ++ st.out ++ "    }\n"

structure Initializers where
  roots : Array Name := #[]
  globals : Std.HashSet Name := {}
  entries : Array (Name × Name) := #[]

def initializers (env : Environment) (mod : Name) : Initializers := Id.run do
  let some idx := env.getModuleIdx? mod | return {}
  let mut result : Initializers := {}
  for (n, init) in regularInitAttr.ext.getModuleEntries env idx do
    if isIOUnitBuiltinInitFn env n then continue
    result := { result with roots := result.roots.push n, entries := result.entries.push (n, init) }
    unless init.isAnonymous do
      result := { result with roots := result.roots.push init, globals := result.globals.insert n }
  return result

def emitMain (env : Environment) (methods : Std.HashMap Name String) (inits : Initializers) (mainDecl : Decl) :
    Except String String := do
  let n := mainDecl.name
  let ps := mainDecl.params
  let hasArgs := ps.size == 2
  let some info := env.find? n | throw s!"unknown main declaration: {n}"
  if hasArgs then
    let .forallE _ arg _ _ := info.type | throw s!"missing List String parameter to {n}"
    unless arg.isAppOfArity (Name.mkSimple "List") 1 && arg.appArg!.isConstOf (Name.mkSimple "String") do
      throw s!"expected {n} to take List String arguments"
  let ty := info.type.getForallBody
  unless (ps.size == 1 || hasArgs) && ty.isAppOfArity (Name.mkSimple "IO") 1 do
    throw s!"expected {n} to have type IO Unit, IO UInt32, or take List String arguments"
  let returnsCode := ty.appArg!.isConstOf (Name.mkSimple "UInt32")
  unless returnsCode || ty.appArg!.isConstOf (Name.mkSimple "Unit") ||
      ty.appArg!.isAppOf (Name.mkSimple "PUnit") do
    throw s!"expected {n} to return IO Unit or IO UInt32"
  let mut out := ""
  if !inits.globals.isEmpty then out := "    private static array $_initValues = [];\n\n"
  out := out ++ "    public static function runMain(array $args): int\n    {\n        return L\\lean_run_main(\n"
  out := out ++ s!"            {methodRef methods n}(...), $args, {hasArgs}, {returnsCode}, [\n"
  for (n, init) in inits.entries do
    if init.isAnonymous then
      out := out ++ s!"                {methodRef methods n}(...),\n"
    else
      out := out ++ s!"                static function (): L\\Ctor \{\n"
      out := out ++ s!"                    $result = {methodRef methods init}();\n"
      out := out ++ "                    if (L\\lean_io_result_is_ok($result)) {\n"
      out := out ++ s!"                        self::$_initValues[{quoteBytes methods[n]!}] = "
        ++ "L\\lean_mark_persistent(L\\lean_io_result_get_value($result));\n"
      out := out ++ "                    }\n                    return $result;\n                },\n"
  return out ++ "            ],\n        );\n    }\n"

structure Output where
  items : String
  functions : Nat
  externs : Nat

def generate (env : Environment) (mod : Name) (roots : Array Name) (main? : Option Name) : Except String Output := do
  let targets := roots.map (csimpTarget env)
  let inits := if main?.isSome then initializers env mod else {}
  let exports := exportedFns env
  let decls ← collect env exports (roots ++ targets ++ main?.toArray ++ inits.roots)
  let mut missing : Array String := #[]
  let mut externs : Std.HashSet String := {}
  let mut directExterns : Std.HashMap Name String := {}
  for d in decls do
    if let .extern f .. := d then
      let some sym := externSymbol env f | throw s!"extern without a C symbol: {f}"
      unless exports.contains sym do
        externs := externs.insert sym
        directExterns := directExterns.insert f sym
        unless runtimeExterns.contains sym || missing.contains sym do missing := missing.push sym
  unless missing.isEmpty do
    throw s!"externs not in the runtime: {joinArgs (missing.qsort (· < ·))}"
  let methods ← methodNames decls
  let declMap := decls.foldl (fun m d => m.insert d.name d) ({} : Std.HashMap Name Decl)
  let mut edges : Std.HashMap Name TailEdges := {}
  for d in decls do
    if let .fdecl f ps _ body _ := d then
      unless ps.isEmpty || inits.globals.contains f do
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
  let mut items ← decls.mapM (emitDecl env declMap methods exports directExterns edges tailTargets cores inits.globals)
  if let some m := main? then
    items := items.push (← emitMain env methods inits declMap[m]!)
  return { items := "\n".intercalate items.toList, functions := decls.size, externs := externs.size }

end LeanPhp
