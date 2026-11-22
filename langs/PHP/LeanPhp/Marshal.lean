import LeanPhp.EmitPhp

open Lean Meta Lean.IR

namespace LeanPhp

def sanitize (s : String) : String :=
  s.foldl (fun acc c => acc ++ match c with
    | '?' => "_q"
    | '!' => "_bang"
    | '\'' => "_prime"
    | c => if (c.isAlphanum && c.toNat < 128) || c == '_' then c.toString else "_") ""

def camelParts (s : String) : List String :=
  ((sanitize s).splitOn "_").filter (!·.isEmpty)

def camelJoin (s : String) : String :=
  match camelParts s with
    | [] => ""
    | p :: ps => p.decapitalize ++ String.join (ps.map String.capitalize)

def componentString : Name → String
  | .str _ s => s
  | .num _ n => toString n
  | .anonymous => ""

def stripName (strip n : Name) : Name :=
  if strip != .anonymous && strip.isPrefixOf n && strip != n then n.replacePrefix strip .anonymous else n

def phpIdentifier (s : String) : Bool :=
  let start := fun (c : Char) => c.isAlpha || c == '_' || c.toNat >= 128
  match s.toList with
  | [] => false
  | c :: cs => start c && cs.all (fun c => start c || c.isDigit)

def reservedClasses : List String :=
  ("__class__ __dir__ __file__ __function__ __halt_compiler __line__ __method__ __namespace__ " ++
    "__property__ __trait__ abstract and array as bool break callable case catch class clone const continue declare " ++
    "default die do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile eval exit " ++
    "extends false final finally float fn for foreach function global goto if implements include include_once " ++
    "instanceof insteadof int interface isset list match mixed namespace never new null object or parent print " ++
    "private protected public readonly require require_once return self static string switch throw " ++
    "trait true try unset use var void while xor yield iterable").splitOn " "

def publicReserved : List String :=
  reservedClasses ++ ("enum this __construct __destruct __call __callstatic __clone __get __set " ++
    "__isset __unset __invoke __tostring __debuginfo __serialize __unserialize __set_state").splitOn " "

def phpIdent (s : String) : String :=
  let s := if s.isEmpty || s.front.isDigit then "_" ++ s else s
  if publicReserved.contains s.toLower then s ++ "_" else s

def publicMethod (strip n : Name) : String :=
  phpIdent ("_".intercalate ((stripName strip n).components.map (camelJoin ∘ componentString)))

def collisionLabel : String := "PHP name collision: "

structure NameClaims where
  counts : Std.HashMap String Nat := {}
  used : Std.HashSet String := {}

def NameClaims.claim (claims : NameClaims) (base : String) : Except String (String × NameClaims) := do
  let key := base.toLower
  let count := claims.counts.getD key 0 + 1
  let name := if count == 1 then base else s!"{base}_{count}"
  if claims.used.contains name.toLower then throw (collisionLabel ++ name)
  return (name, { counts := claims.counts.insert key count, used := claims.used.insert name.toLower })

inductive Desc where
  | nat | int | bool | char | string | float | float32 | unit
  | uint (bits : Nat)
  | sint (bits : Nat)
  | usize | isize
  | list (d : Desc)
  | array (d : Desc)
  | option (d : Desc)
  | prod (a b : Desc)
  | except (e a : Desc)
  | fin (n : Nat)
  | named (ident : String)
  | foreign (ns ident : String)
  deriving Inhabited, BEq

structure FieldInfo where
  key : String
  property : String
  slot : String
  pos : Nat
  desc : Desc
  omitNone : Bool := false
  flat : Bool := false
  bounds : Array (String × Int) := #[]
  deriving Inhabited

structure InvInfo where
  field : String
  prop : String
  decider : Name
  args : Array Nat
  deriving Inhabited

structure VariantInfo where
  name : String
  ident : String
  cidx : Nat
  size : Nat
  usize : Nat
  ssize : Nat
  positional : Bool
  fields : Array FieldInfo
  invariants : Array InvInfo
  deriving Inhabited

inductive TypeKind where
  | struct (v : VariantInfo) (trivial : Option Nat)
  | enum (ctors : Array String)
  | sum (vs : Array VariantInfo) (trivial : Option Nat)
  | subtype (base : Desc) (inv : InvInfo) (bounds : Array (String × Int))
  deriving Inhabited

structure TypeDef where
  ident : String
  pretty : String
  kind : TypeKind
  anonymous : Bool := false
  model : Option String := none
  deriving Inhabited

structure MarshalCfg where
  strip : Name
  typeModules : Array (Name × String) := #[]
  models : Std.HashMap Name String := {}

structure MarshalState where
  types : Array TypeDef := #[]
  byType : Std.HashMap Lean.Expr Desc := {}
  idents : NameClaims := {}
  foreignTypes : Std.HashMap (String × String) TypeDef := {}
  deciders : Array Name := #[]
  subtypes : Nat := 0

abbrev MarshalM := StateRefT MarshalState (ReaderT MarshalCfg MetaM)

def capitalizeIdent (s : String) : String :=
  let parts := camelParts s
  String.join (parts.map String.capitalize)

def typeIdentOf (strip c : Name) (args : Array String) : String :=
  let comps := (stripName strip c).components.map fun n => (sanitize (componentString n)).capitalize
  let base := "_".intercalate (comps.filter (!·.isEmpty))
  let base := base ++ String.join (args.toList.map capitalizeIdent)
  phpIdent base.capitalize

def freshIdent (base : String) : MarshalM String := do
  let st ← get
  let (nm, claims) ← ofExcept (st.idents.claim base)
  modify fun s => { s with idents := claims }
  return nm

def deciderName (ident ctor field : String) : MetaM Name := do
  let n := Name.str (.str (.str (.str .anonymous "LeanPhpGen") ident) ctor) (field ++ "_decide")
  let env ← getEnv
  if !env.contains n then return n
  let mut i := 2
  while env.contains (.num n i) do i := i + 1
  return .num n i

def compileDecider (name : Name) (args : Array Lean.Expr) (prop : Lean.Expr) : MetaM Unit := do
  let dec ← try mkDecide prop
    catch _ => throwError "no `Decidable` instance for the proposition `{prop}`"
  let value ← instantiateMVars (← mkLambdaFVars args dec)
  if value.hasFVar || value.hasMVar then throwError "the proposition `{prop}` depends on a proof field"
  let type ← inferType value
  addAndCompile (.defnDecl { name, levelParams := [], type, value, hints := .opaque, safety := .safe })

def literalInt? (e : Lean.Expr) : MetaM (Option Int) := do
  let e ← instantiateMVars e
  if let some i := e.int? then return some i
  if let some n ← (evalNat e).run then return some (Int.ofNat n)
  return none

def boundOf (v : Lean.Expr) (p : Lean.Expr) : MetaM (Option (String × Int)) := do
  let p := p.consumeMData
  let (op, a, b) ← match p.getAppFnArgs with
    | (``LT.lt, #[_, _, a, b]) => pure ("lt", a, b)
    | (``LE.le, #[_, _, a, b]) => pure ("le", a, b)
    | (``GT.gt, #[_, _, a, b]) => pure ("gt", a, b)
    | (``GE.ge, #[_, _, a, b]) => pure ("ge", a, b)
    | _ => return none
  let lenKind (e : Lean.Expr) : Option String := match e.getAppFnArgs with
    | (``String.length, #[x]) => if x == v then some "Length" else none
    | (``List.length, #[_, x]) => if x == v then some "Items" else none
    | (``Array.size, #[_, x]) => if x == v then some "Items" else none
    | _ => none
  let flip : String → String
    | "lt" => "gt" | "le" => "ge" | "gt" => "lt" | _ => "le"
  let (op, target, lit) := if a == v || (lenKind a).isSome then (op, a, b) else (flip op, b, a)
  let some c ← literalInt? lit | return none
  if let some k := lenKind target then
    return some <| match op with
      | "lt" => (s!"max{k}", c - 1)
      | "le" => (s!"max{k}", c)
      | "gt" => (s!"min{k}", c + 1)
      | _ => (s!"min{k}", c)
  unless target == v do return none
  return some <| match op with
    | "lt" => ("exclusiveMaximum", c)
    | "le" => ("maximum", c)
    | "gt" => ("exclusiveMinimum", c)
    | _ => ("minimum", c)

def slotOf : Compiler.LCNF.CtorFieldInfo → String × Nat
  | .object i _ => ("obj", i)
  | .usize i => ("usize", i)
  | .scalar sz off ty =>
    let s := match ty.constName?, sz with
      | some ``Float, _ => "f64"
      | some ``Float32, _ => "f32"
      | _, 1 => "u8"
      | _, 2 => "u16"
      | _, 4 => "u32"
      | _, _ => "u64"
    (s, off)
  | _ => ("none", 0)

def ppProp (strip : Name) (e : Lean.Expr) : MetaM String := do
  let f ← withTheReader Core.Context (fun c => { c with currNamespace := strip, openDecls := [] }) <|
    withOptions (fun o => o.setBool `pp.piBinderTypes false |>.setBool `pp.funBinderTypes false) (ppExpr e)
  return toString f

def ppType (e : Lean.Expr) : MetaM String := do
  return toString (← withOptions (fun o => o.setBool `pp.fullNames true) (ppExpr e))

def unsupportedTypes : List Name :=
  [``ByteArray, ``FloatArray, ``Thunk, ``Task, ``IO.Ref, ``Decidable, ``String.Pos.Raw, ``Substring,
   ``String.Slice]

def unsupportedRoots : List Name := [`Std, `Lean, `IO, `EStateM, `ST, `System]

partial def nullable (st : MarshalState) : Desc → Bool
  | .option _ | .unit => true
  | .named n =>
    match st.types.find? (·.ident == n) with
    | some { anonymous := true, kind := .subtype d .., .. } => nullable st d
    | _ => false
  | _ => false

mutual

partial def descOf (t : Lean.Expr) : MarshalM Desc := do
  let t ← instantiateMVars t
  let orig := t.consumeMData
  let t ← whnfR t
  let t := t.consumeMData
  if t.isForall then throwError "function type `{t}`"
  if t.isSort then throwError "type argument `{t}`"
  let args := t.getAppArgs
  let .const c _ := t.getAppFn | throwError "type variable `{t}`"
  if ← isProp t then throwError "proposition `{t}`"
  if isPrivateName c || (orig.getAppFn.constName?.any isPrivateName) then
    throwError "private type `{orig}`"
  match c, args with
  | ``Nat, #[] => return .nat
  | ``Int, #[] => return .int
  | ``Bool, #[] => return .bool
  | ``String, #[] => return .string
  | ``Char, #[] => return .char
  | ``UInt8, #[] => return .uint 8
  | ``UInt16, #[] => return .uint 16
  | ``UInt32, #[] => return .uint 32
  | ``UInt64, #[] => return .uint 64
  | ``USize, #[] => return .usize
  | ``Int8, #[] => return .sint 8
  | ``Int16, #[] => return .sint 16
  | ``Int32, #[] => return .sint 32
  | ``Int64, #[] => return .sint 64
  | ``ISize, #[] => return .isize
  | ``Float, #[] => return .float
  | ``Float32, #[] => return .float32
  | ``Unit, #[] | ``PUnit, #[] => return .unit
  | ``List, #[a] => return .list (← descOf a)
  | ``Array, #[a] => return .array (← descOf a)
  | ``Option, #[a] =>
    let d ← descOf a
    if nullable (← get) d then
      throwError "ambiguous `Option` `{t}` (`none` and `some` can both be null)"
    return .option d
  | ``Prod, #[a, b] => return .prod (← descOf a) (← descOf b)
  | ``Except, #[e, a] => return .except (← descOf e) (← descOf a)
  | ``Fin, #[n] =>
    let some v ← (evalNat (← instantiateMVars n)).run
      | throwError "`Fin` with a bound that is not a literal: `{n}`"
    return .fin v
  | _, _ =>
    if c == ``Subtype && orig.getAppFn.constName? != some ``Subtype then
      return ← namedDesc c t args orig.getAppFn.constName?
    if t.hasFVar then throwError "type `{t}` of a type parameter"
    if unsupportedTypes.contains c || unsupportedRoots.contains c.getRoot then throwError "unsupported type `{t}`"
    match (← getEnv).find? c with
    | some (.defnInfo _) =>
      let some u ← unfoldDefinition? t | throwError "unsupported type `{t}`"
      let u ← whnfR u
      if u.getAppFn.constName? == some ``Subtype then namedDesc ``Subtype u u.getAppArgs (some c)
      else descOf u
    | some (.inductInfo _) => namedDesc c t args none
    | _ => throwError "unsupported type `{t}`"

partial def namedDesc (c : Name) (t : Lean.Expr) (args : Array Lean.Expr) (alias? : Option Name) :
    MarshalM Desc := do
  let key := alias?.map (fun n => mkApp (mkConst n) t) |>.getD t
  if let some d := (← get).byType[key]? then return d
  let env ← getEnv
  let cfg ← read
  let some (.inductInfo ind) := env.find? c | throwError "unsupported type `{t}`"
  if ind.numIndices != 0 then throwError "indexed type `{t}`"
  if isClass env c then throwError "type class `{t}`"
  let paramArgs ← args[:ind.numParams].toArray.filterM fun a => return !(← isProof a)
  let names ← if c == ``Subtype then pure #[] else paramArgs.mapM fun a => return toString (← ppExpr a)
  if !cfg.models.contains c && (c != ``Subtype || alias?.isSome) then
    let source := alias?.getD c
    if let some (ns, spec) := cfg.typeModules.find? fun (ns, _) => ns.isPrefixOf source && source != ns then
      let ident := typeIdentOf ns source names
      let d := Desc.foreign spec ident
      modify fun s => { s with byType := s.byType.insert key d }
      let td ← typeDef c t args ident alias? true
      modify fun s => { s with foreignTypes := s.foreignTypes.insert (spec, ident) td }
      return d
  let base ← if c == ``Subtype then
      match alias? with
      | some n => pure (typeIdentOf cfg.strip n #[])
      | none =>
        let k := (← get).subtypes
        modify fun s => { s with subtypes := k + 1 }
        pure s!"Subtype{k}"
    else
      pure (typeIdentOf cfg.strip c names)
  let ident ← freshIdent base
  let d := Desc.named ident
  modify fun s => { s with byType := s.byType.insert key d }
  let td ← typeDef c t args ident alias? false
  modify fun s => { s with types := s.types.push td }
  return d

partial def typeDef (c : Name) (t : Lean.Expr) (args : Array Lean.Expr) (ident : String) (alias? : Option Name)
    (external : Bool) : MarshalM TypeDef := do
  let env ← getEnv
  let cfg ← read
  let some (.inductInfo ind) := env.find? c | throwError "unsupported type `{t}`"
  let model := cfg.models[c]?
  let isStruct := isStructure env c
  let mut variants : Array VariantInfo := #[]
  let mut trivial := none
  for ctor in ind.ctors do
    let some (.ctorInfo ci) := env.find? ctor | throwError "unknown constructor {ctor}"
    let layout ← Compiler.LCNF.getCtorLayout ctor
    let levels := t.getAppFn.constLevels!
    let ctorTy ← instantiateForall (ci.type.instantiateLevelParams ci.levelParams levels) args[:ci.numParams]
    let ctorName := componentString ctor
    let v ← forallTelescopeReducing ctorTy fun fs _ => do
      let names ← fs.mapM (·.fvarId!.getUserName)
      let named := names.all (!·.hasMacroScopes)
      let mut fields : Array FieldInfo := #[]
      let mut props : NameClaims := {}
      let mut invs : Array InvInfo := #[]
      let mut valueFvars : Array Lean.Expr := #[]
      let mut origIdx : Array Nat := #[]
      for h : i in [0:fs.size] do
        let f := fs[i]
        let ty ← inferType f
        let raw := componentString names[i]!.eraseMacroScopes
        if ← isProp ty then
          let ty := ty.headBeta
          for h : j in [0:valueFvars.size] do
            if let some b ← boundOf valueFvars[j] ty then
              fields := fields.modify j fun fi => { fi with bounds := fi.bounds.push b }
          let fname := if named then raw else s!"h{i}"
          let dn ← deciderName ident ctorName (sanitize fname)
          unless external do
            compileDecider dn valueFvars ty
            modify fun s => { s with deciders := s.deciders.push dn }
          let prop ← ppProp cfg.strip ty
          invs := invs.push { field := fname, prop, decider := dn, args := (List.range valueFvars.size).toArray }
          continue
        if (← whnf ty).isSort then throwError "the constructor `{ctor}` has a type field `{raw}`"
        let d ← descOf ty
        let optKey := isStruct && raw.endsWith "?" && raw.length > 1 && (match d with | .option _ => true | _ => false)
        let key := if !named then s!"a{fields.size}" else if optKey then (raw.dropEndWhile (· == '?')).copy else raw
        let (property, claims) ← if model.isSome then pure (key, props)
          else ofExcept (props.claim (phpIdent (sanitize key)))
        props := claims
        let flat := isStruct && (isSubobjectField? env c names[i]!).isSome
        let (slot, pos) := slotOf (layout.fieldInfo[i]?.getD .erased)
        fields := fields.push { key, property, slot, pos, desc := d, omitNone := optKey, flat }
        valueFvars := valueFvars.push f
        origIdx := origIdx.push i
      let info := layout.ctorInfo
      return ({ name := ctorName, ident := "", cidx := info.cidx, size := info.size, usize := info.usize, ssize := info.ssize,
                positional := !named, fields, invariants := invs : VariantInfo }, origIdx)
    variants := variants.push v.1
    let info ← Compiler.LCNF.hasTrivialStructure? c
    trivial := info.bind fun ti => v.2.findIdx? (· == ti.fieldIdx)
    if isStruct then
      if c == ``Subtype then
        let some fi := v.1.fields[0]? | throwError "a subtype without a value: `{t}`"
        let some inv := v.1.invariants[0]? | throwError "a subtype without a property: `{t}`"
        return { ident, pretty := ← ppType t,
                 anonymous := alias?.isNone, kind := .subtype fi.desc inv fi.bounds }
      return { ident, pretty := ← ppType t, kind := .struct v.1 trivial, model }
  let kind ← if variants.all (fun v => v.fields.isEmpty && v.invariants.isEmpty) then
      pure (TypeKind.enum (variants.map (·.name)))
    else do
      let vs ← variants.mapM fun v => do
        let base := phpIdent (ident ++ (sanitize v.name).capitalize)
        let ctor ← if external then pure base else freshIdent base
        return { v with ident := ctor }
      pure (.sum vs trivial)
  return { ident, pretty := ← ppType t, kind, model }

end

inductive ParamKind where
  | value (name : String) (d : Desc)
  | world
  deriving Inhabited

structure PublicSig where
  params : Array ParamKind
  result : Desc
  io : Bool
  type : String

def publicSig (name : Name) (ps : Array Param) : MarshalM PublicSig := do
  let some ci := (← getEnv).find? name | throwError "unknown constant {name}"
  let type := toString (← ppExpr ci.type)
  forallBoundedTelescope ci.type ps.size fun xs body => do
    if xs.size != ps.size then
      throwError "the IR has {ps.size} parameters but the type has {xs.size} binders"
    let body ← whnfR body
    let io := body.getAppFn.constName? == some `EST.Out
    if io then
      let errTy := body.getAppArgs[0]!.constName?
      unless errTy == some ``IO.Error do throwError "`EIO` with an error type other than `IO.Error`"
    let mut params := #[]
    let mut used : Std.HashSet String := {}
    for h : i in [0:xs.size] do
      let x := xs[i]
      let ldecl ← x.fvarId!.getDecl
      if io && i + 1 == xs.size then params := params.push .world; continue
      if ← isProp ldecl.type then throwError "takes a proof argument `{ldecl.userName}`"
      if (← whnf ldecl.type).isSort then throwError "polymorphic (takes the type `{ldecl.userName}`)"
      if ldecl.binderInfo.isInstImplicit then throwError "takes an instance argument `{ldecl.type}`"
      let d ← descOf ldecl.type
      let base := if ldecl.userName.hasMacroScopes then s!"arg{i}"
        else phpIdent (camelJoin (componentString ldecl.userName.eraseMacroScopes))
      let base := if base == "_" then s!"arg{i}" else base
      let mut nm := base
      let mut k := 1
      while used.contains nm do
        nm := s!"{base}{k}"; k := k + 1
      used := used.insert nm
      params := params.push (.value nm d)
    let result ← if io then descOf body.getAppArgs[2]! else descOf body
    return { params, result, io, type }

end LeanPhp
