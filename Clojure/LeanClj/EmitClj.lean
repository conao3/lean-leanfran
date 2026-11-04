import Lean
import LeanClj.Sx

/-! # lean-clj: a Lean IR -> Clojure backend

IR `Decl`s are read from the environment with `Lean.IR.findEnvDecl`, collected
transitively from a set of root functions, and emitted as Clojure forms that
call into the hand-written runtime `lean-clj.runtime`. Reference counting
(`inc`/`dec`/`del`/`reset`/`reuse`) is dropped because the JVM has a tracing GC,
and `isShared` always answers "shared" so that the compiler's in-place update
branches are never taken on values that Clojure code may alias. -/

open Lean Lean.IR

namespace LeanClj

def rtNs : String := "lean-clj.runtime"

def rt (fn : String) : Sx := .atom s!"{rtNs}/{fn}"

def call (fn : Sx) (args : List Sx) : Sx := .list (fn :: args)

def rtCall (fn : String) (args : List Sx) : Sx := call (rt fn) args

/-! ## Names -/

def isPlainChar (c : Char) : Bool :=
  (c.isAlphanum && c.toNat < 128) || c == '_' || c == '?' || c == '!' || c == '\''

/-- Encode a Lean name as a Clojure symbol fragment: `.` separates components
    as `-` (which never occurs in a Lean identifier, so the encoding is
    injective), other non-symbol characters become `_xNN_`. -/
def mangle (n : Name) : String := Id.run do
  let mut acc := ""
  for c in (n.toString (escape := false)).toList do
    if c == '.' then acc := acc.push '-'
    else if isPlainChar c then acc := acc.push c
    else acc := acc ++ s!"_x{c.toNat}_"
  return acc

/-- Internal (private) Clojure name of a collected Lean function. -/
def internalName (n : Name) : String := "lean--" ++ mangle n

def coreName (n : Name) : String := internalName n ++ "-tc"

/-- `isEven?` → `is-even?`, `toJSON` → `to-json`. -/
def kebab (s : String) : String := Id.run do
  let cs := s.toList.toArray
  let mut acc := ""
  for h : i in [0:cs.size] do
    let c := cs[i]
    if c.isUpper then
      let prevLower := i > 0 && (cs[i-1]!.isLower || cs[i-1]!.isDigit)
      let nextLower := i + 1 < cs.size && cs[i+1]!.isLower && i > 0 && cs[i-1]!.isUpper
      if prevLower || nextLower then acc := acc.push '-'
      acc := acc.push c.toLower
    else if isPlainChar c then acc := acc.push c
    else acc := acc ++ s!"_x{c.toNat}_"
  return acc

/-- Public Clojure name of a root function: the components after `strip`,
    kebab-cased and joined by `-` (`Point.add` → `point-add`). -/
def publicName (strip : Name) (n : Name) : String :=
  let rel := if strip.isPrefixOf n && strip != n then n.replacePrefix strip .anonymous else Name.mkSimple n.getString!
  "-".intercalate (rel.componentsRev.reverse.map fun c => kebab (c.toString (escape := false)))

def varName (x : VarId) : String := s!"x_{x.idx}"

def jpName (j : JoinPointId) : String := s!"block_{j.idx}"

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
          "\\u" ++ String.ofList (List.replicate (4 - h.length) '0') ++ h
        else c.toString
  return acc ++ "\""

/-! ## Emission context -/

structure Ctx where
  env : Environment
  /-- Collected declarations by name. -/
  decls : Std.HashMap Name Decl
  /-- Functions on a tail-call cycle of length ≥ 2; they get a `-tc` core that
      returns `TailCall` values and a public wrapper that trampolines. -/
  tcSet : Std.HashSet Name
  self : Name
  selfParams : Array Param
  /-- The body is wrapped in `loop` and self tail calls become `recur`. -/
  loopMode : Bool
  /-- Self tail calls return a `Restart` value that the `loop` around the body
      re-dispatches, because some of them sit inside a `letfn` join point
      where `recur` would target the local function. -/
  restartMode : Bool := false
  /-- Join points with a single `jmp`, expanded at that site. -/
  inlineSet : Std.HashSet Nat := {}
  inlineJps : Std.HashMap Nat (Array Param × FnBody) := {}

abbrev EmitM := ReaderT Ctx (Except String)

def argSx : Arg → Sx
  | .var x => .atom (varName x)
  | .erased => .atom "nil"

def isRelevant (p : Param) : Bool := !p.ty.isErased && !p.ty.isVoid

def externSymbol (env : Environment) (c : Name) : Option String :=
  getExternNameFor env `c c

def relevantArgs (ps : Array Param) (ys : Array Arg) : List Sx := Id.run do
  let mut acc := #[]
  for h : i in [0:ys.size] do
    if h' : i < ps.size then
      if isRelevant ps[i] then acc := acc.push (argSx ys[i])
    else acc := acc.push (argSx ys[i])
  return acc.toList

def isConst (d : Decl) : Bool :=
  match d with
  | .fdecl _ xs .. => xs.isEmpty
  | _ => false

def emitFap (c : Name) (ys : Array Arg) : EmitM Sx := do
  let ctx ← read
  match ctx.decls[c]? with
  | some d@(.extern _ ps _ _) =>
    match externSymbol ctx.env c with
    | some sym => return rtCall sym (relevantArgs ps ys)
    | none => throw s!"extern without a C symbol: {d.name}"
  | some d =>
    if isConst d then return call (.atom "force") [.atom (internalName c)]
    else return call (.atom (internalName c)) (ys.toList.map argSx)
  | none => throw s!"function was not collected: {c}"

def emitLit (ty : IRType) : LitVal → Sx
  | .str s => .atom (quoteString s)
  | .num v =>
    match ty with
    | .uint64 | .usize =>
      if v ≥ 2 ^ 63 then .atom s!"-{2 ^ 64 - v}" else .atom (toString v)
    | .float | .float32 => .atom s!"{v}.0"
    | _ => if v < 2 ^ 63 then .atom (toString v) else .atom s!"{v}N"

def ctorSx (i : CtorInfo) (ys : Array Arg) : Sx :=
  if i.size == 0 && i.usize == 0 && i.ssize == 0 then .atom (toString i.cidx)
  else rtCall "ctor" ([.atom (toString i.cidx), .atom (toString (i.size + i.usize)), .atom (toString i.ssize)] ++ ys.toList.map argSx)

def emitPap (c : Name) (ys : Array Arg) : EmitM Sx := do
  let ctx ← read
  match ctx.decls[c]? with
  | some (.extern _ ps _ _) =>
    let some sym := externSymbol ctx.env c | throw s!"extern without a C symbol: {c}"
    let xs := (List.range ps.size).map fun i => Sx.atom s!"a_{i}"
    let rel := (xs.zip ps.toList).filterMap fun (x, p) => if isRelevant p then some x else none
    let body := rtCall sym rel
    return rtCall "closure" [call (.atom "fn") [.vec xs, body], .atom (toString ps.size), .vec (ys.toList.map argSx)]
  | some d =>
    let fn := Sx.atom (internalName c)
    return rtCall "closure" [fn, .atom (toString d.params.size), .vec (ys.toList.map argSx)]
  | none => throw s!"function was not collected: {c}"

def emitExpr (ty : IRType) : IR.Expr → EmitM Sx
  | .ctor i ys => return ctorSx i ys
  | .reset _ _ => return .atom "nil"
  | .reuse _ i _ ys => return ctorSx i ys
  | .proj i x => return rtCall "proj" [.atom (varName x), .atom (toString i)]
  | .uproj i x => return rtCall "proj" [.atom (varName x), .atom (toString i)]
  | .sproj _ offset x => return rtCall "sproj" [.atom (varName x), .atom (toString offset)]
  | .fap c ys => emitFap c ys
  | .pap c ys => emitPap c ys
  | .ap x ys => return rtCall "apply" (.atom (varName x) :: ys.toList.map argSx)
  | .box _ x => return .atom (varName x)
  | .unbox x => return .atom (varName x)
  | .lit v => return emitLit ty v
  | .isShared _ => return .atom "1"

/-! ## Tail calls -/

partial def skipRc : FnBody → FnBody
  | .inc _ _ _ _ b | .dec _ _ _ _ b | .del _ b => skipRc b
  | b => b

/-- `let x := c ys; (rc ops)*; ret x` -/
def tailCallOf? : FnBody → Option (Name × Array Arg)
  | .vdecl x _ (.fap c ys) b =>
    match skipRc b with
    | .ret (.var r) => if r == x then some (c, ys) else none
    | _ => none
  | _ => none

partial def tailTargets (b : FnBody) : Array Name :=
  match tailCallOf? b with
  | some (c, _) => #[c]
  | none =>
    match b with
    | .jdecl _ _ v k => tailTargets v ++ tailTargets k
    | .case _ _ _ alts => alts.foldl (fun acc a => acc ++ tailTargets a.body) #[]
    | .ret _ | .jmp .. | .unreachable => #[]
    | b => tailTargets b.body

/-- Does the body contain a self tail call, directly or through a jump to an
    inlined join point? Such code must stay in the `loop` frame. -/
partial def hasRecur (self : Name) (inl : Std.HashMap Nat FnBody) (b : FnBody) : Bool :=
  match tailCallOf? b with
  | some (c, _) => c == self
  | none =>
    match b with
    | .jdecl _ _ v k => hasRecur self inl v || hasRecur self inl k
    | .case _ _ _ alts => alts.any fun a => hasRecur self inl a.body
    | .jmp j _ => match inl[j.idx]? with
      | some v => hasRecur self inl v
      | none => false
    | .ret _ | .unreachable => false
    | b => hasRecur self inl b.body

/-- Join point declarations of a body, with the number of `jmp`s to each. -/
partial def joinPoints (b : FnBody) (acc : Std.HashMap Nat (FnBody × Nat)) :
    Std.HashMap Nat (FnBody × Nat) :=
  match b with
  | .jdecl j _ v k =>
    let acc := acc.alter j.idx fun
      | some (_, n) => some (v, n)
      | none => some (v, 0)
    joinPoints k (joinPoints v acc)
  | .case _ _ _ alts => alts.foldl (fun acc a => joinPoints a.body acc) acc
  | .jmp j _ => acc.alter j.idx fun
    | some (v, n) => some (v, n + 1)
    | none => some (.unreachable, 1)
  | .ret _ | .unreachable => acc
  | b => joinPoints b.body acc

/-- Names on a tail-call cycle of length ≥ 2. -/
def tailCycleMembers (decls : Array Decl) : Std.HashSet Name := Id.run do
  let mut edges : Std.HashMap Name (Array Name) := {}
  for d in decls do
    if let .fdecl f _ _ b _ := d then
      edges := edges.insert f ((tailTargets b).filter (· != f))
  let reach (start : Name) (goal : Name) : Bool := Id.run do
    let mut seen : Std.HashSet Name := {}
    let mut stack := #[start]
    let mut fuel := edges.size * edges.size + 10
    while !stack.isEmpty && fuel > 0 do
      fuel := fuel - 1
      let n := stack.back!
      stack := stack.pop
      if n == goal then return true
      if seen.contains n then continue
      seen := seen.insert n
      for m in edges.getD n #[] do stack := stack.push m
    return false
  let mut out : Std.HashSet Name := {}
  for (f, ts) in edges.toList do
    if ts.any (fun t => reach t f) then out := out.insert f
  return out

/-! ## Function bodies -/

def withBindings (bs : Array (Sx × Sx)) (body : Sx) : Sx :=
  if bs.isEmpty then body
  else .list [.atom "let", .vec (bs.toList.flatMap fun (a, b) => [a, b]), body]

/-- Prepend a statement to a body: `(do stmt body)`, flattening nested `do`. -/
def seqDo (stmt : Sx) (body : Sx) : Sx :=
  match body with
  | .list (.atom "do" :: rest) => .list (.atom "do" :: stmt :: rest)
  | _ => .list [.atom "do", stmt, body]

mutual

partial def emitTailCall (c : Name) (ys : Array Arg) : EmitM Sx := do
  let ctx ← read
  if c == ctx.self && ctx.loopMode then
    if ctx.restartMode then return rtCall "restart" (ys.toList.map argSx)
    return .list (.atom "recur" :: ys.toList.map argSx)
  else if ctx.tcSet.contains ctx.self && ctx.tcSet.contains c then
    return rtCall "tail-call" (.atom (coreName c) :: ys.toList.map argSx)
  else
    emitFap c ys

partial def emitBody (b : FnBody) : EmitM Sx := do
  if let some (c, ys) := tailCallOf? b then
    return (← emitTailCall c ys)
  match b with
  | .vdecl .. =>
    -- gather consecutive bindings into one `let`
    let mut bs : Array (Sx × Sx) := #[]
    let mut cur := b
    repeat
      if (tailCallOf? cur).isSome then break
      match cur with
      | .vdecl x ty e k =>
        bs := bs.push (.atom (varName x), ← emitExpr ty e)
        cur := k
      | .inc _ _ _ _ k | .dec _ _ _ _ k | .del _ k => cur := k
      | _ => break
    return withBindings bs (← emitBody cur)
  | .jdecl j xs v k =>
    let ctx ← read
    if ctx.inlineSet.contains j.idx then
      withReader (fun c => { c with inlineJps := c.inlineJps.insert j.idx (xs, v) }) (emitBody k)
    else
      let vSx ← emitBody v
      let kSx ← emitBody k
      let f := Sx.list [.atom (jpName j), .vec (xs.toList.map fun p => .atom (varName p.x)), vSx]
      return .list [.atom "letfn", .vec [f], kSx]
  | .set x i y k =>
    return seqDo (rtCall "set-obj!" [.atom (varName x), .atom (toString i), argSx y]) (← emitBody k)
  | .uset x i y k =>
    return seqDo (rtCall "set-obj!" [.atom (varName x), .atom (toString i), .atom (varName y)]) (← emitBody k)
  | .sset x _ offset y _ k =>
    return seqDo (rtCall "sset!" [.atom (varName x), .atom (toString offset), .atom (varName y)]) (← emitBody k)
  | .setTag x cidx k =>
    return seqDo (rtCall "set-tag!" [.atom (varName x), .atom (toString cidx)]) (← emitBody k)
  | .inc _ _ _ _ k | .dec _ _ _ _ k | .del _ k => emitBody k
  | .case _ x xType alts =>
    let scrut : Sx := if xType.isScalar then call (.atom "long") [.atom (varName x)] else rtCall "tag" [.atom (varName x)]
    let mut clauses : Array Sx := #[]
    let mut dflt : Option Sx := none
    for alt in alts do
      match alt with
      | .ctor info body =>
        clauses := clauses.push (.atom (toString info.cidx))
        clauses := clauses.push (← emitBody body)
      | .default body => dflt := some (← emitBody body)
    match clauses.toList, dflt with
    | [], some d => return d
    | [_, only], none => return only
    | cs, d =>
      let fallback := d.getD (rtCall "unreachable" [])
      return .list (.atom "case" :: scrut :: cs ++ [fallback])
  | .ret y => return argSx y
  | .jmp j ys =>
    let ctx ← read
    match ctx.inlineJps[j.idx]? with
    | some (xs, v) =>
      let bs := (xs.zip ys).map fun (p, y) => (Sx.atom (varName p.x), argSx y)
      return withBindings bs (← emitBody v)
    | none => return .list (.atom (jpName j) :: ys.toList.map argSx)
  | .unreachable => return rtCall "unreachable" []

end

/-! ## Declarations -/

def paramVec (ps : Array Param) : Sx := .vec (ps.toList.map fun p => .atom (varName p.x))

def emitDecl (env : Environment) (decls : Std.HashMap Name Decl) (tcSet : Std.HashSet Name)
    (d : Decl) : Except String (List Sx) := do
  let .fdecl f ps _ body _ := d | return []
  if ps.size > 20 then throw s!"functions with more than 20 parameters are not supported: {f}"
  let loopMode := (tailTargets body).contains f
  let jps := joinPoints body {}
  let inlineSet := jps.fold (fun s i (_, n) => if n == 1 then s.insert i else s) {}
  let inlBodies := jps.fold (fun m i (v, n) => if n == 1 then m.insert i v else m) {}
  let restartMode := loopMode &&
    jps.toList.any fun (i, (v, _)) => !inlineSet.contains i && hasRecur f inlBodies v
  let ctx : Ctx := { env, decls, tcSet, self := f, selfParams := ps, loopMode, restartMode, inlineSet }
  let b ← (emitBody body).run ctx
  let loopVec := Sx.vec (ps.toList.flatMap fun p => [.atom (varName p.x), .atom (varName p.x)])
  let b := if restartMode then
      let r := Sx.atom "r__"
      let again := Sx.list (.atom "recur" :: (List.range ps.size).map fun i => rtCall "restart-arg" [r, .atom (toString i)])
      .list [.atom "loop", loopVec,
        .list [.atom "let", .vec [r, b], .list [.atom "if", rtCall "restart?" [r], again, r]]]
    else if loopMode then .list [.atom "loop", loopVec, b]
    else b
  if ps.isEmpty then
    return [.list [.atom "def", .atom s!"^:private {internalName f}", .list [.atom "delay", b]]]
  if tcSet.contains f then
    let args := ps.toList.map fun p => Sx.atom (varName p.x)
    return [
      .list [.atom "defn-", .atom (coreName f), paramVec ps, b],
      .list [.atom "defn-", .atom (internalName f), paramVec ps,
        rtCall "trampoline" [.list (.atom (coreName f) :: args)]]]
  return [.list [.atom "defn-", .atom (internalName f), paramVec ps, b]]

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

def collect (env : Environment) (roots : Array Name) : Except String (Array Decl) := do
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
    if let .fdecl _ _ _ b _ := d then
      for c in (bodyCallees b #[]).reverse do
        unless seen.contains c do stack := stack.push c
  return out

/-! ## Marshalling between Clojure values and Lean values -/

/-- A marshalling descriptor, emitted as Clojure data and interpreted by
    `lean-clj.runtime/to-clj` and `from-clj`. -/
inductive Desc where
  | kw (k : String)
  | list (d : Desc)
  | array (d : Desc)
  | option (d : Desc)
  | prod (a b : Desc)
  | ref (key : String)
  deriving Inhabited

partial def Desc.toSx : Desc → Sx
  | .kw k => .atom s!":{k}"
  | .list d => .vec [.atom ":list", d.toSx]
  | .array d => .vec [.atom ":array", d.toSx]
  | .option d => .vec [.atom ":option", d.toSx]
  | .prod a b => .vec [.atom ":prod", a.toSx, b.toSx]
  | .ref k => .vec [.atom ":ref", .atom (quoteString k)]

structure MarshalState where
  /-- Registered named types (structures, enums) in registration order. -/
  types : Array (String × Sx) := #[]
  seen : Std.HashSet String := {}

abbrev MarshalM := StateRefT MarshalState MetaM

open Meta in
partial def descOf (t : Lean.Expr) : MarshalM Desc := do
  let t ← whnfR (← instantiateMVars t)
  let t := t.consumeMData
  let fn := t.getAppFn
  let args := t.getAppArgs
  let .const c _ := fn | return .kw "raw"
  match c, args with
  | ``Nat, #[] => return .kw "nat"
  | ``Int, #[] => return .kw "int"
  | ``Bool, #[] => return .kw "bool"
  | ``String, #[] => return .kw "string"
  | ``Char, #[] => return .kw "char"
  | ``UInt8, #[] | ``UInt16, #[] | ``UInt32, #[] => return .kw "nat"
  | ``UInt64, #[] | ``USize, #[] => return .kw "u64"
  | ``Float, #[] => return .kw "float"
  | ``Float32, #[] => return .kw "float"
  | ``Unit, #[] | ``PUnit, #[_] => return .kw "unit"
  | ``List, #[a] => return .list (← descOf a)
  | ``Array, #[a] => return .array (← descOf a)
  | ``Option, #[a] =>
    let inner ← descOf a
    match inner with
    | .option _ => return .kw "raw"
    | _ => return .option inner
  | ``Prod, #[a, b] => return .prod (← descOf a) (← descOf b)
  | ``Subtype, #[a, _] => descOf a
  | _, _ =>
    let env ← getEnv
    let some (.inductInfo ind) := env.find? c | return .kw "raw"
    if ind.isRec || ind.numIndices != 0 then return .kw "raw"
    let key := toString (← ppExpr t)
    if (← get).seen.contains key then return .ref key
    modify fun s => { s with seen := s.seen.insert key }
    -- enumerations: every constructor is nullary
    let mut allNullary := true
    for ctor in ind.ctors do
      let some (.ctorInfo ci) := env.find? ctor | return .kw "raw"
      if ci.numFields != 0 then allNullary := false
    if allNullary then
      let names := ind.ctors.map fun n => Sx.atom s!":{kebab n.getString!}"
      modify fun s => { s with types := s.types.push (key, .map [.atom ":kind", .atom ":enum", .atom ":ctors", .vec names]) }
      return .ref key
    if !isStructure env c then return .kw "raw"
    let [ctor] := ind.ctors | return .kw "raw"
    let some (.ctorInfo ci) := env.find? ctor | return .kw "raw"
    let layout ← Compiler.LCNF.getCtorLayout ctor
    let fieldNames := getStructureFields env c
    let ctorTy ← instantiateForall ci.type args[:ci.numParams]
    let fieldDescs ← forallTelescopeReducing ctorTy fun fs _ => fs.mapM fun f => do descOf (← f.fvarId!.getType)
    let mut relevant := 0
    let mut fields : Array Sx := #[]
    for h : i in [0:layout.fieldInfo.size] do
      let name := Sx.atom s!":{kebab (fieldNames[i]!.toString (escape := false))}"
      let d := fieldDescs[i]!.toSx
      match layout.fieldInfo[i] with
      | .object j _ => relevant := relevant + 1; fields := fields.push (.vec [name, .vec [.atom ":obj", .atom (toString j)], d])
      | .usize j => relevant := relevant + 1; fields := fields.push (.vec [name, .vec [.atom ":obj", .atom (toString j)], d])
      | .scalar _ off _ => relevant := relevant + 1; fields := fields.push (.vec [name, .vec [.atom ":scalar", .atom (toString off)], d])
      | .erased | .void => pure ()
    if relevant == 1 then
      -- a structure with one relevant field is represented by that field
      for h : i in [0:layout.fieldInfo.size] do
        match layout.fieldInfo[i] with
        | .erased | .void => pure ()
        | _ => return fieldDescs[i]!
    let info := layout.ctorInfo
    let sx := Sx.map [.atom ":kind", .atom ":struct", .atom ":tag", .atom (toString info.cidx),
      .atom ":size", .atom (toString (info.size + info.usize)), .atom ":ssize", .atom (toString info.ssize),
      .atom ":fields", .vec fields.toList]
    modify fun s => { s with types := s.types.push (key, sx) }
    return .ref key

structure PublicSig where
  /-- Per IR parameter: `some desc` for an argument of the public function,
      `none` for an erased one. -/
  params : Array (Option Desc)
  result : Desc

open Meta in
def publicSig (name : Name) (ps : Array Param) : MarshalM PublicSig := do
  let some ci := (← getEnv).find? name | throwError "unknown constant {name}"
  forallBoundedTelescope ci.type ps.size fun xs body => do
    if xs.size != ps.size then
      throwError "{name}: the IR has {ps.size} parameters but the type has {xs.size} binders"
    let mut params := #[]
    for h : i in [0:xs.size] do
      let x := xs[i]
      if !isRelevant ps[i]! then params := params.push none
      else
        let ldecl ← x.fvarId!.getDecl
        if ldecl.binderInfo.isInstImplicit then
          throwError "{name}: instance arguments are not supported in public functions"
        params := params.push (some (← descOf ldecl.type))
    return { params, result := ← descOf body }

def emitPublic (strip : Name) (name : Name) (ps : Array Param) (sig : PublicSig) : Sx :=
  let pub := publicName strip name
  let argNames := (sig.params.toList.zipIdx).filterMap fun (d, i) => d.map fun _ => Sx.atom s!"a{i}"
  let callArgs := (sig.params.toList.zipIdx).map fun (d, i) =>
    match d with
    | some desc => rtCall "from-clj" [desc.toSx, .atom s!"a{i}"]
    | none => .atom "nil"
  let inner := if ps.isEmpty then call (.atom "force") [.atom (internalName name)]
    else .list (.atom (internalName name) :: callArgs)
  .list [.atom "defn", .atom pub, .vec argNames, rtCall "to-clj" [sig.result.toSx, inner]]

/-! ## Rendering -/

structure Output where
  /-- The emitted forms, without an `ns` form. -/
  forms : Array Sx
  /-- Public functions as (Lean name, Clojure name). -/
  publics : Array (Name × String)
  externs : Array String

def generate (roots : Array Name) (strip : Name) : MetaM Output := do
  let env ← getEnv
  let decls ← match collect env roots with
    | .ok ds => pure ds
    | .error e => throwError e
  let declMap := decls.foldl (fun m d => m.insert d.name d) ({} : Std.HashMap Name Decl)
  let tcSet := tailCycleMembers decls
  let mut externs : Array String := #[]
  for d in decls do
    if let .extern f .. := d then
      match externSymbol env f with
      | some s => unless externs.contains s do externs := externs.push s
      | none => throwError "extern without a C symbol: {f}"
  let mut body : Array Sx := #[]
  let mut names : Array Sx := #[]
  for d in decls do
    if let .fdecl f ps .. := d then
      names := names.push (.atom (internalName f))
      if tcSet.contains f && !ps.isEmpty then names := names.push (.atom (coreName f))
  for d in decls.reverse do
    match emitDecl env declMap tcSet d with
    | .ok fs => body := body ++ fs.toArray
    | .error e => throwError e
  let (pubForms, st) ← (do
      let mut acc := #[]
      for r in roots do
        let some d := declMap[r]? | throwError "unknown root {r}"
        let sig ← publicSig r d.params
        acc := acc.push (emitPublic strip r d.params sig)
      return acc : MarshalM (Array Sx)).run {}
  let header : Array Sx := #[
    rtCall "check-symbols!" [.vec (externs.toList.map fun s => .atom (quoteString s))]] ++
    st.types.map (fun (k, sx) => rtCall "register-type!" [.atom (quoteString k), sx]) ++
    (if names.isEmpty then #[] else #[.list (.atom "declare" :: names.toList)])
  return {
    forms := header ++ body ++ pubForms
    publics := roots.map fun r => (r, publicName strip r)
    externs }

def renderForms (forms : Array Sx) : String :=
  "\n\n".intercalate (forms.toList.map (·.render 0)) ++ "\n"

def nsForm (ns : String) (publics : Array String) : Sx :=
  let refer := Sx.list [.atom ":refer-clojure", .atom ":exclude", .vec (publics.toList.map .atom)]
  .list [.atom "ns", .atom ns, refer, .list [.atom ":require", .vec [.atom rtNs]]]

end LeanClj
