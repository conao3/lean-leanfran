import Lean
import LeanRust.RuntimeExterns

/-! # lean-rs: a Lean IR -> Rust backend

IR `Decl`s are read from the environment with `Lean.IR.findEnvDecl`, collected
transitively from a set of root functions, and emitted as Rust functions that
call into the hand-written runtime `lean-rust-runtime`. The emitted code follows
the C backend (`Lean.Compiler.LCNF.EmitC`): reference counting, `reset`/`reuse`
and `isShared` run as in C, so the in-place updates of the C backend happen in
the same places. `goto` is replaced by a state machine over the join points. -/

open Lean Lean.IR

namespace LeanRust

/-! ## Names -/

/-- Rust identifier of a collected Lean function (the C backend's mangling). -/
def fnName (n : Name) : String := n.mangle "l_"

def varName (x : VarId) : String := s!"x_{x.idx}"

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
        if c.toNat < 32 || c.toNat == 127 then
          let h := String.ofList (Nat.toDigits 16 c.toNat)
          "\\u{" ++ h ++ "}"
        else c.toString
  return acc ++ "\""

/-! ## Types -/

def rsType : IRType → String
  | .float => "f64"
  | .float32 => "f32"
  | .uint8 => "u8"
  | .uint16 => "u16"
  | .uint32 => "u32"
  | .uint64 => "u64"
  | .usize => "usize"
  | _ => "Obj"

def defaultValue : IRType → String
  | .float => "0.0f64"
  | .float32 => "0.0f32"
  | .uint8 | .uint16 | .uint32 | .uint64 | .usize => "0"
  | _ => "rt::lean_box(0)"

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
  /-- Join points emitted as states of the state machine, by index. -/
  stateOf : Std.HashMap Nat Nat := {}
  /-- Types of the local variables. -/
  varTypes : Std.HashMap Nat IRType := {}
  /-- Path of the runtime module. -/
  rt : String := "rt"

abbrev EmitM := ReaderT Ctx (StateT String (Except String))

def emit (s : String) : EmitM Unit := modify (· ++ s)

def emitLn (s : String) : EmitM Unit := emit (s ++ "\n")

def argStr : Arg → String
  | .var x => varName x
  | .erased => "rt::lean_box(0)"

def externSymbol (env : Environment) (c : Name) : Option String :=
  getExternNameFor env `c c

/-- An extern implemented by a Rust function of the crate (`@[extern "rs:crate::f(_)"]`). -/
def isRustExtern (sym : String) : Bool := sym.startsWith "rs:"

def isConst (d : Decl) : Bool :=
  match d with
  | .fdecl _ xs .. => xs.isEmpty
  | _ => false

/-- Largest number of parameters a closure function takes separately (`closureMaxArgs`). -/
def closureMaxArgs : Nat := 16

/-- A boxed function with more than `closureMaxArgs` parameters takes them as an array
    `*mut Obj`, as in the C backend (`lean_apply_m` calls it that way). -/
def takesArgArray (d : Decl) : Bool :=
  (d.params.filter (!·.ty.isVoid)).size > closureMaxArgs && Lean.Compiler.LCNF.isBoxedName d.name

def varType (x : VarId) : EmitM IRType := do
  return (← read).varTypes.getD x.idx .object

/-- Call of a collected function or an extern. Erased and void parameters are
    dropped for externs, as in the C backend. -/
def callStr (c : Name) (ys : Array Arg) : EmitM String := do
  let ctx ← read
  match ctx.decls[c]? with
  | some d@(.extern _ ps _ _) =>
    let some sym := externSymbol ctx.env c | throw s!"extern without a C symbol: {d.name}"
    if isRustExtern sym then
      let args := (ps.zip ys).filter (fun (p, _) => !p.ty.isVoid) |>.map (argStr ·.2)
      return s!"{fnName c}({", ".intercalate args.toList})"
    if let some t := ctx.exports[sym]? then
      if let some td := ctx.decls[t]? then
        if td.params.size == ps.size then
          -- an owned parameter of the Lean implementation receives a borrowed argument
          let args := (td.params.zip (ps.zip ys)).filter (fun (tp, _) => !tp.ty.isVoid) |>.map fun (tp, p, y) =>
            if p.borrow && !tp.borrow && isObjType tp.ty then
              match y with
              | .var x => s!"\{ rt::lean_inc({varName x}); {varName x} }"
              | .erased => argStr y
            else argStr y
          if isConst td then return s!"{fnName t}()"
          return s!"{fnName t}({", ".intercalate args.toList})"
    let args := (ps.zip ys).filter (fun (p, _) => !(p.ty.isErased || p.ty.isVoid)) |>.map (argStr ·.2)
    return s!"rt::{sym}({", ".intercalate args.toList})"
  | some d =>
    if isConst d then return s!"{fnName c}()"
    let args := (d.params.zip ys).filter (fun (p, _) => !p.ty.isVoid) |>.map (argStr ·.2)
    if takesArgArray d then
      return s!"\{ let mut __aargs: [Obj; {args.size}] = [{", ".intercalate args.toList}]; {fnName c}(__aargs.as_mut_ptr()) }"
    return s!"{fnName c}({", ".intercalate args.toList})"
  | none => throw s!"function was not collected: {c}"

def ctorAlloc (i : CtorInfo) : String :=
  s!"rt::lean_alloc_ctor({i.cidx}, {i.size}, {i.usize} * core::mem::size_of::<usize>() as u32 + {i.ssize})"

def ctorSets (x : String) (ys : Array Arg) : String := Id.run do
  let mut acc := ""
  for h : i in [0:ys.size] do
    acc := acc ++ s!" rt::lean_ctor_set({x}, {i}, {argStr ys[i]});"
  return acc

def litStr (ty : IRType) : LitVal → String
  | .str s => s!"rt::lean_mk_string_unchecked({quoteString s}, {s.utf8ByteSize}, {s.length})"
  | .num v =>
    match ty with
    | .uint8 => s!"{v}u8"
    | .uint16 => s!"{v}u16"
    | .uint32 => s!"{v}u32"
    | .uint64 => s!"{v}u64"
    | .usize => s!"{v}usize"
    | .float => s!"{v}.0f64"
    | .float32 => s!"{v}.0f32"
    | _ => if v < 2 ^ 32 then s!"rt::lean_unsigned_to_nat({v}u32)" else s!"rt::lean_cstr_to_nat({quoteString (toString v)})"

def boxFn : IRType → String
  | .usize => "lean_box_usize"
  | .uint32 => "lean_box_uint32"
  | .uint64 => "lean_box_uint64"
  | .float => "lean_box_float"
  | .float32 => "lean_box_float32"
  | _ => "lean_box"

def sprojFn : IRType → Except String String
  | .float => .ok "lean_ctor_get_float"
  | .float32 => .ok "lean_ctor_get_float32"
  | .uint8 => .ok "lean_ctor_get_uint8"
  | .uint16 => .ok "lean_ctor_get_uint16"
  | .uint32 => .ok "lean_ctor_get_uint32"
  | .uint64 => .ok "lean_ctor_get_uint64"
  | t => .error s!"sproj of type {repr t}"

def ssetFn : IRType → Except String String
  | .float => .ok "lean_ctor_set_float"
  | .float32 => .ok "lean_ctor_set_float32"
  | .uint8 => .ok "lean_ctor_set_uint8"
  | .uint16 => .ok "lean_ctor_set_uint16"
  | .uint32 => .ok "lean_ctor_set_uint32"
  | .uint64 => .ok "lean_ctor_set_uint64"
  | t => .error s!"sset of type {repr t}"

def offsetStr (n offset : Nat) : String :=
  s!"{n} * core::mem::size_of::<usize>() as u32 + {offset}"

def liftExcept (e : Except String α) : EmitM α :=
  match e with
  | .ok a => pure a
  | .error m => throw m

/-- One `let` binding: statements assigning `x`. -/
def emitVDecl (x : VarId) (ty : IRType) (e : IR.Expr) : EmitM Unit := do
  let xs := varName x
  match e with
  | .ctor i ys =>
    if i.size == 0 && i.usize == 0 && i.ssize == 0 then emitLn s!"{xs} = rt::lean_box({i.cidx});"
    else emitLn s!"{xs} = {ctorAlloc i};{ctorSets xs ys}"
  | .reset n y =>
    let ys := varName y
    let mut rel := ""
    for i in [0:n] do rel := rel ++ s!" rt::lean_ctor_release({ys}, {i});"
    emitLn s!"if rt::lean_is_exclusive({ys}) \{{rel} {xs} = {ys}; } else \{ rt::lean_dec_ref({ys}); {xs} = rt::lean_box(0); }"
  | .reuse y i upd ys =>
    let yv := varName y
    let tag := if upd then s!" rt::lean_ctor_set_tag({xs}, {i.cidx});" else ""
    emitLn s!"if rt::lean_is_scalar({yv}) \{ {xs} = {ctorAlloc i}; } else \{ {xs} = {yv};{tag} }{ctorSets xs ys}"
  | .proj i y => emitLn s!"{xs} = rt::lean_ctor_get({varName y}, {i});"
  | .uproj i y => emitLn s!"{xs} = rt::lean_ctor_get_usize({varName y}, {i});"
  | .sproj n off y => emitLn s!"{xs} = rt::{← liftExcept (sprojFn ty)}({varName y}, {offsetStr n off});"
  | .fap c ys => emitLn s!"{xs} = {← callStr c ys};"
  | .pap c ys =>
    let ctx ← read
    let some d := ctx.decls[c]? | throw s!"function was not collected: {c}"
    emit s!"{xs} = rt::lean_alloc_closure({fnName c} as *const (), {d.params.size}, {ys.size});"
    for h : i in [0:ys.size] do emit s!" rt::lean_closure_set({xs}, {i}, {argStr ys[i]});"
    emitLn ""
  | .ap f ys =>
    if ys.size > 16 then
      emitLn s!"\{ let mut aargs: [Obj; {ys.size}] = [{", ".intercalate (ys.toList.map argStr)}]; {xs} = rt::lean_apply_m({varName f}, {ys.size}, aargs.as_mut_ptr()); }"
    else
      emitLn s!"{xs} = rt::lean_apply_{ys.size}({varName f}, {", ".intercalate (ys.toList.map argStr)});"
  | .box t y =>
    let fn := boxFn t
    let arg := if fn == "lean_box" then s!"{varName y} as usize" else varName y
    emitLn s!"{xs} = rt::{fn}({arg});"
  | .unbox y =>
    match ty with
    | .usize => emitLn s!"{xs} = rt::lean_unbox_usize({varName y});"
    | .uint32 => emitLn s!"{xs} = rt::lean_unbox_uint32({varName y});"
    | .uint64 => emitLn s!"{xs} = rt::lean_unbox_uint64({varName y});"
    | .float => emitLn s!"{xs} = rt::lean_unbox_float({varName y});"
    | .float32 => emitLn s!"{xs} = rt::lean_unbox_float32({varName y});"
    | t => emitLn s!"{xs} = rt::lean_unbox({varName y}) as {rsType t};"
  | .lit v => emitLn s!"{xs} = {litStr ty v};"
  | .isShared y => emitLn s!"{xs} = (!rt::lean_is_exclusive({varName y})) as u8;"

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

/-- Parallel assignment through temporaries. -/
def assignAll (targets : Array String) (vals : Array String) : String := Id.run do
  let mut a := ""
  let mut b := ""
  for h : i in [0:targets.size] do
    a := a ++ s!"let t_{i} = {vals[i]!}; "
    b := b ++ s!"{targets[i]} = t_{i}; "
  return "{ " ++ a ++ b ++ "}"

mutual

partial def emitBody (b : FnBody) : EmitM Unit := do
  let ctx ← read
  if let some ys := isSelfTailCall ctx.self b then
    let ps := ctx.selfParams
    let pairs := (ps.zip ys).filter fun (p, _) => !p.ty.isVoid
    emitLn (assignAll (pairs.map (varName ·.1.x)) (pairs.map (argStr ·.2)))
    emitLn "__blk = 0; continue 'body;"
    return
  match b with
  | .vdecl x ty e k => emitVDecl x ty e; emitBody k
  | .jdecl _ _ _ k => emitBody k
  | .set x i y k => emitLn s!"rt::lean_ctor_set({varName x}, {i}, {argStr y});"; emitBody k
  | .uset x i y k => emitLn s!"rt::lean_ctor_set_usize({varName x}, {i}, {varName y});"; emitBody k
  | .sset x n off y ty k =>
    emitLn s!"rt::{← liftExcept (ssetFn ty)}({varName x}, {offsetStr n off}, {varName y});"; emitBody k
  | .setTag x cidx k => emitLn s!"rt::lean_ctor_set_tag({varName x}, {cidx});"; emitBody k
  | .inc x n c p k =>
    unless p do
      let f := if c then "lean_inc" else "lean_inc_ref"
      if n == 1 then emitLn s!"rt::{f}({varName x});" else emitLn s!"rt::{f}_n({varName x}, {n});"
    emitBody k
  | .dec x _ c p k =>
    unless p do
      let f := if c then "lean_dec" else "lean_dec_ref"
      emitLn s!"rt::{f}({varName x});"
    emitBody k
  | .del x k => emitLn s!"rt::lean_del_object({varName x});"; emitBody k
  | .case _ x xType alts =>
    let xt ← varType x
    let scrut := if isObjType xType && isObjType xt then s!"rt::lean_obj_tag({varName x})"
      else s!"{varName x} as u32"
    emitLn s!"match {scrut} \{"
    let mut hasDefault := false
    for alt in alts do
      match alt with
      | .ctor info body =>
        emitLn s!"{info.cidx} => \{"
        emitBody body
        emitLn "}"
      | .default body =>
        hasDefault := true
        emitLn "_ => {"
        emitBody body
        emitLn "}"
    unless hasDefault do emitLn "_ => rt::lean_internal_panic_unreachable(),"
    emitLn "}"
  | .ret y => emitLn s!"return {argStr y};"
  | .jmp j ys =>
    match ctx.inlineJps[j.idx]? with
    | some (xs, v) =>
      emitLn (assignAll (xs.map (varName ·.x)) (ys.map argStr))
      emitBody v
    | none =>
      let some st := ctx.stateOf[j.idx]? | throw s!"unknown join point {j.idx}"
      let some (xs, _) := (joinPoints (← currentBody) {})[j.idx]?.map (fun (a, b, _) => (a, b))
        | throw s!"unknown join point {j.idx}"
      emitLn (assignAll (xs.map (varName ·.x)) (ys.map argStr))
      emitLn s!"__blk = {st}; continue 'body;"
  | .unreachable => emitLn "rt::lean_internal_panic_unreachable();"

partial def currentBody : EmitM FnBody := do
  let ctx ← read
  match ctx.decls[ctx.self]? with
  | some (.fdecl _ _ _ b _) => return b
  | _ => throw s!"no body for {ctx.self}"

end

/-! ## Declarations -/

def paramList (ps : Array Param) : String :=
  ", ".intercalate (ps.filter (!·.ty.isVoid) |>.map (fun p => s!"mut {varName p.x}: {rsType p.ty}")).toList

def fnHeader (d : Decl) (f : Name) (ps : Array Param) (ty : IRType) : String :=
  if takesArgArray d then
    let unpack := (ps.filter (!·.ty.isVoid)).mapIdx fun i p => s!"let mut {varName p.x}: {rsType p.ty} = *__args.add({i});\n"
    s!"#[allow(dead_code, non_snake_case, unused_mut, unused_assignments, unused_variables, unreachable_code, unused_unsafe, clippy::all)]\npub(crate) unsafe fn {fnName f}(__args: *mut Obj) -> {rsType ty} \{\n" ++ String.join unpack.toList
  else
    s!"#[allow(dead_code, non_snake_case, unused_mut, unused_assignments, unused_variables, unreachable_code, unused_unsafe, clippy::all)]\npub(crate) unsafe fn {fnName f}({paramList ps}) -> {rsType ty} \{\n"

partial def bodySelfTail (f : Name) (b : FnBody) : Bool :=
  match b with
  | .vdecl x _ (.fap c _) (.ret (.var r)) => (c == f && r == x)
  | .jdecl _ _ v k => bodySelfTail f v || bodySelfTail f k
  | .case _ _ _ alts => alts.any fun a => bodySelfTail f a.body
  | .ret _ | .jmp .. | .unreachable => false
  | b => bodySelfTail f b.body

def emitDecl (env : Environment) (decls : Std.HashMap Name Decl) (exports : Std.HashMap String Name) (d : Decl) : Except String String := do
  let .fdecl f ps ty body _ := d | return ""
  let jps := joinPoints body {}
  let mut inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}
  let mut stateOf : Std.HashMap Nat Nat := {}
  let mut states : Array (Nat × FnBody) := #[]
  for (i, (xs, v, n)) in jps.toList.mergeSort (fun a b => a.1 ≤ b.1) do
    if n == 1 then inlineJps := inlineJps.insert i (xs, v)
    else
      let st := states.size + 1
      stateOf := stateOf.insert i st
      states := states.push (st, v)
  let selfTail := (bodySelfTail f body)
  let machine := !states.isEmpty || selfTail
  let vars := bodyVars body {}
  let varTypes := ps.foldl (fun m p => m.insert p.x.idx p.ty) vars
  let ctx : Ctx := { env, decls, exports, self := f, selfParams := ps, inlineJps, stateOf, varTypes }
  let run (b : FnBody) : Except String String := do
    let ((), s) ← ((emitBody b).run ctx).run ""
    return s
  let mut out := ""
  if ps.isEmpty then
    -- constants: evaluated once on first use and marked persistent
    let inner ← run body
    let cell := if isObjType ty then "Obj" else rsType ty
    out := out ++ s!"#[allow(dead_code, non_snake_case, unused_mut, unused_assignments, unused_variables, unreachable_code, clippy::all)]\nunsafe fn {fnName f}_init() -> {rsType ty} \{\n"
    for (i, t) in vars.toList.mergeSort (fun a b => a.1 ≤ b.1) do
      out := out ++ s!"let mut x_{i}: {rsType t} = {defaultValue t};\n"
    if machine then
      out := out ++ "let mut __blk: u32 = 0;\n'body: loop { match __blk {\n0 => {\n" ++ inner ++ "}\n"
      for (st, v) in states do out := out ++ s!"{st} => \{\n" ++ (← run v) ++ "}\n"
      out := out ++ "_ => rt::lean_internal_panic_unreachable(),\n} }\n"
    else out := out ++ inner
    out := out ++ "}\n"
    let mark := if isObjType ty then "rt::lean_mark_persistent(v); " else ""
    out := out ++ s!"#[allow(dead_code, non_snake_case, clippy::all)]\npub(crate) unsafe fn {fnName f}() -> {rsType ty} \{\n  thread_local! \{ static CELL: core::cell::OnceCell<{cell}> = const \{ core::cell::OnceCell::new() }; }\n  if let Some(v) = CELL.with(|c| c.get().copied()) \{ return v; }\n  let v = {fnName f}_init();\n  {mark}CELL.with(|c| *c.get_or_init(|| v))\n}\n"
    return out
  out := out ++ fnHeader d f ps ty
  for (i, t) in vars.toList.mergeSort (fun a b => a.1 ≤ b.1) do
    out := out ++ s!"let mut x_{i}: {rsType t} = {defaultValue t};\n"
  let inner ← run body
  if machine then
    out := out ++ "let mut __blk: u32 = 0;\n'body: loop { match __blk {\n0 => {\n" ++ inner ++ "}\n"
    for (st, v) in states do out := out ++ s!"{st} => \{\n" ++ (← run v) ++ "}\n"
    out := out ++ "_ => rt::lean_internal_panic_unreachable(),\n} }\n"
  else out := out ++ inner
  out := out ++ "}\n"
  return out

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
      | some s => unless out.contains s || exports.contains s || isRustExtern s do out := out.push s
      | none => throw s!"extern without a C symbol: {f}"
  return out

structure Output where
  /-- The emitted items (a Rust module body without `use` of the runtime). -/
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
    items := items ++ (← emitDecl env declMap exports d) ++ "\n"
  return { items, externs, decls }

end LeanRust
