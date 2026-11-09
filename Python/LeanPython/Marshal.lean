import Lean
import LeanPython.EmitPy

/-! # Public Python types and functions

The Lean types of the public functions are mapped to Python types: scalars to `int`, `bool`,
`str`, `float`; `List`/`Array` to `list`, `Option` to `T | None`, `Prod` to `tuple`; structures
to pydantic models; inductive types to a `StrEnum` (nullary constructors only) or to a pydantic
model per constructor under a common base class. Constructor layouts come from
`Compiler.LCNF.getCtorLayout`. Proof fields become validators that run a decision procedure
compiled from the proposition (`decide`). -/

open Lean Meta Lean.IR

namespace LeanPython

def pythonKeywords : List String :=
  ["False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue",
   "def", "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in",
   "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield",
   "match", "case", "type"]

def sanitize (s : String) : String := Id.run do
  let mut out := ""
  for c in s.toList do
    out := out ++ match c with
      | '?' => "_q"
      | '!' => "_bang"
      | '\'' => "_prime"
      | c => if c.isAlphanum || c == '_' then c.toString else "_"
  if out.isEmpty then return "_"
  if out.front.isDigit then out := "_" ++ out
  if pythonKeywords.contains out then out := out ++ "_"
  return out

def componentString : Name → String
  | .str _ s => s
  | .num _ n => toString n
  | .anonymous => ""

def stripName (strip n : Name) : Name := n.replacePrefix strip .anonymous

/-- Python path (dotted) of a Lean name under the stripped namespace. -/
def pyPath (strip n : Name) : Array String :=
  ((stripName strip n).components.map (sanitize ∘ componentString)).toArray

/-- How a value crosses between Python and Lean. -/
inductive Desc where
  | nat | int | bool | char | string | float | float32 | unit
  | uint (bits : Nat)
  | sint (bits : Nat)
  | list (d : Desc)
  | array (d : Desc)
  | option (d : Desc)
  | prod (a b : Desc)
  | fin (n : Nat)
  /-- A generated type (by its Python name). -/
  | named (py : String)
  deriving Inhabited, BEq

partial def Desc.pyType : Desc → String
  | .nat => "Nat"
  | .int => "int"
  | .bool => "bool"
  | .char => "Char"
  | .string => "str"
  | .float | .float32 => "float"
  | .unit => "None"
  | .uint b => s!"UInt{b}"
  | .sint b => s!"Int{b}"
  | .list d | .array d => s!"list[{d.pyType}]"
  | .option d => s!"{d.pyType} | None"
  | .prod a b => s!"tuple[{a.pyType}, {b.pyType}]"
  | .fin n => s!"Annotated[int, Ge(0), Lt({n})]"
  | .named py => py

partial def Desc.pyDesc : Desc → String
  | .nat => "_m.NAT"
  | .int => "_m.INT"
  | .bool => "_m.BOOL"
  | .char => "_m.CHAR"
  | .string => "_m.STRING"
  | .float => "_m.FLOAT"
  | .float32 => "_m.FLOAT32"
  | .unit => "_m.UNIT"
  | .uint b => s!"_m.UIntD({b})"
  | .sint b => s!"_m.SIntD({b})"
  | .list d => s!"_m.ListD({d.pyDesc})"
  | .array d => s!"_m.ArrayD({d.pyDesc})"
  | .option d => s!"_m.OptionD({d.pyDesc})"
  | .prod a b => s!"_m.ProdD({a.pyDesc}, {b.pyDesc})"
  | .fin n => s!"_m.FinD({n})"
  | .named py => s!"_m.NamedD(globals(), {quoteString py})"

/-- Where a constructor field lives in the object. -/
inductive FieldLoc where
  | obj (i : Nat)
  | scalar (key : Nat)
  | erased
  deriving Inhabited

structure Field where
  /-- Python attribute name. -/
  name : String
  loc : FieldLoc
  desc : Desc
  /-- JSON key (Lean's `ToJson`), when it differs from `name`. -/
  alias : Option String := none
  /-- A field named `x?`: the key is omitted when the value is `none`. -/
  omitNone : Bool := false
  /-- annotated-types constraints (`Le(100)`) implied by proof fields comparing the field with a constant. -/
  annotations : Array String := #[]
  deriving Inhabited

/-- A proof field: checked by the compiled decision procedure `decider` applied to the earlier
    fields `args` (by index into the fields). -/
structure Invariant where
  field : String
  prop : String
  decider : Name
  args : Array Nat
  deriving Inhabited

structure Variant where
  /-- Constructor name (last component). -/
  name : String
  /-- Python class name. -/
  py : String
  cidx : Nat
  size : Nat
  unit : Bool
  fields : Array Field
  /-- The constructor's arguments are unnamed (JSON: a value or an array). -/
  positional : Bool
  invariants : Array Invariant
  deriving Inhabited

inductive TypeKind where
  | struct (v : Variant)
  /-- A structure represented by its one relevant field. -/
  | trivial (v : Variant)
  /-- `{x : α // p x}`: the value, checked by the invariant. -/
  | subtype (f : Field) (inv : Invariant)
  | enum (ctors : Array String)
  | sum (variants : Array Variant)
  /-- `LeanPythonUnions.*`: a union of the user's models, by constructor index. -/
  | modelUnion (variants : Array Variant)
  deriving Inhabited

structure TypeDef where
  py : String
  lean : String
  kind : TypeKind
  /-- Defined by another Python module: `some adopt`, where `adopt` attaches the Lean layout to
      that module's class (a user's pydantic model). -/
  external : Option Bool := none
  deriving Inhabited

structure MarshalState where
  types : Array TypeDef := #[]
  index : Std.HashSet String := {}
  inProgress : Std.HashSet String := {}
  deciders : Array Name := #[]
  subtypes : Std.HashMap String String := {}
  /-- `import <module> as <alias>` lines of the external types. -/
  extImports : Array (String × String) := #[]

structure MarshalCfg where
  strip : Name
  /-- Types in namespace `ns` are classes of the Python module `module` (named by their path
      under `ns`); `adopt` marks a module of the user's pydantic models. -/
  typeModules : Array (Name × String × Bool) := #[]

abbrev MarshalM := StateRefT MarshalState (ReaderT MarshalCfg MetaM)

def unsupportedTypes : List Name := [``ByteArray, ``FloatArray, ``Thunk, ``Task, ``Except, ``IO.Ref]

def deciderName (py ctor field : String) : Name :=
  .str (.str (.str (.str .anonymous "LeanPythonGen") py) ctor) (field ++ "_decide")

/-- Compiles `fun args => decide prop` and returns its name. -/
def compileDecider (name : Name) (args : Array Lean.Expr) (prop : Lean.Expr) : MetaM Unit := do
  if (← getEnv).contains name then return
  let dec ← try mkDecide prop
    catch _ => throwError "no `Decidable` instance for the proof field `{prop}`"
  let value ← mkLambdaFVars args dec
  let value ← instantiateMVars value
  if value.hasFVar || value.hasMVar then throwError "the proposition `{prop}` depends on a proof field"
  let type ← inferType value
  addAndCompile (.defnDecl { name, levelParams := [], type, value, hints := .opaque, safety := .safe })

/-- A literal natural number or integer. -/
def literalInt? (e : Lean.Expr) : MetaM (Option Int) := do
  let e ← instantiateMVars e
  if let some i := e.int? then return some i
  if let some n ← (evalNat e).run then return some (Int.ofNat n)
  return none

/-- The annotated-types constraint a proposition `x < c`, `c ≤ x`, `x.length ≤ c`, … puts on the
    field `x` (`v`), as Python source. -/
def boundOf (v : Lean.Expr) (p : Lean.Expr) : MetaM (Option String) := do
  let p := p.consumeMData
  let (op, a, b) ← match p.getAppFnArgs with
    | (``LT.lt, #[_, _, a, b]) => pure ("lt", a, b)
    | (``LE.le, #[_, _, a, b]) => pure ("le", a, b)
    | (``GT.gt, #[_, _, a, b]) => pure ("gt", a, b)
    | (``GE.ge, #[_, _, a, b]) => pure ("ge", a, b)
    | _ => return none
  let isLen (e : Lean.Expr) : Bool := match e.getAppFnArgs with
    | (``String.length, #[x]) => x == v
    | (``List.length, #[_, x]) => x == v
    | (``Array.size, #[_, x]) => x == v
    | _ => false
  let flip : String → String
    | "lt" => "gt" | "le" => "ge" | "gt" => "lt" | _ => "le"
  let (op, target, lit) :=
    if a == v || isLen a then (op, a, b) else (flip op, b, a)
  unless target == v || isLen target do return none
  let some c ← literalInt? lit | return none
  if isLen target then
    match op with
    | "lt" => return some s!"MaxLen({c - 1})"
    | "le" => return some s!"MaxLen({c})"
    | "gt" => return some s!"MinLen({c + 1})"
    | _ => return some s!"MinLen({c})"
  match op with
  | "lt" => return some s!"Lt({c})"
  | "le" => return some s!"Le({c})"
  | "gt" => return some s!"Gt({c})"
  | _ => return some s!"Ge({c})"

mutual

partial def descOf (t : Lean.Expr) : MarshalM Desc := do
  let t ← whnfR (← instantiateMVars t)
  let t := t.consumeMData
  if t.isForall then throwError "function type `{t}`"
  if t.isSort then throwError "type argument `{t}`"
  let args := t.getAppArgs
  let .const c _ := t.getAppFn | throwError "type variable `{t}`"
  match c, args with
  | ``Nat, #[] => return .nat
  | ``Int, #[] => return .int
  | ``Bool, #[] => return .bool
  | ``Decidable, #[_] => return .bool
  | ``String, #[] => return .string
  | ``Char, #[] => return .char
  | ``UInt8, #[] => return .uint 8
  | ``UInt16, #[] => return .uint 16
  | ``UInt32, #[] => return .uint 32
  | ``UInt64, #[] => return .uint 64
  | ``USize, #[] => return .uint 64
  | ``Int8, #[] => return .sint 8
  | ``Int16, #[] => return .sint 16
  | ``Int32, #[] => return .sint 32
  | ``Int64, #[] => return .sint 64
  | ``ISize, #[] => return .sint 64
  | ``Float, #[] => return .float
  | ``Float32, #[] => return .float32
  | ``Unit, #[] | ``PUnit, #[] => return .unit
  | ``List, #[a] => return .list (← descOf a)
  | ``Array, #[a] => return .array (← descOf a)
  | ``Option, #[a] => return .option (← descOf a)
  | ``Prod, #[a, b] => return .prod (← descOf a) (← descOf b)
  | ``Fin, #[n] =>
    let some v ← (evalNat (← instantiateMVars n)).run | throwError "`Fin` with a bound that is not a literal: `{n}`"
    return .fin v
  | _, _ =>
    if unsupportedTypes.contains c then throwError "unsupported type `{c}`"
    namedDesc c t args

partial def namedDesc (c : Name) (t : Lean.Expr) (args : Array Lean.Expr) : MarshalM Desc := do
  let env ← getEnv
  if t.hasFVar then throwError "type `{t}` of a type parameter"
  let some (.inductInfo ind) := env.find? c | throwError "unsupported type `{t}`"
  if ind.numIndices != 0 then throwError "type family `{t}`"
  if ind.isRec && ind.ctors.length == 1 then throwError "recursive structure `{t}`"
  let cfg ← read
  let strip := cfg.strip
  let mut py := "_".intercalate (pyPath strip c).toList
  let ext := cfg.typeModules.find? fun (ns, _, _) => ns.isPrefixOf c && c != ns
  if let some (ns, pymod, _) := ext then
    let alias ← match (← get).extImports.find? (·.2 == pymod) with
      | some (a, _) => pure a
      | none =>
        let a := s!"_ext{(← get).extImports.size}"
        modify fun s => { s with extImports := s.extImports.push (a, pymod) }
        pure a
    py := alias ++ "." ++ ".".intercalate (pyPath ns c).toList
  if c == ``Subtype then
    let key := toString (← ppExpr t)
    match (← get).subtypes[key]? with
    | some n => return .named n
    | none =>
      py := s!"_Subtype{(← get).subtypes.size}"
      modify fun s => { s with subtypes := s.subtypes.insert key py }
  else
    for a in args[:ind.numParams] do
      unless ← isProof a do
        py := py ++ "_" ++ sanitize (toString (← ppExpr a))
  if (← get).index.contains py || (← get).inProgress.contains py then return .named py
  modify fun s => { s with inProgress := s.inProgress.insert py }
  let leanStr := toString (← ppExpr t)
  let mut variants : Array Variant := #[]
  for ctor in ind.ctors do
    let some (.ctorInfo ci) := env.find? ctor | throwError "unknown constructor {ctor}"
    let layout ← Compiler.LCNF.getCtorLayout ctor
    let ctorTy ← instantiateForall ci.type args[:ci.numParams]
    let v ← forallTelescopeReducing ctorTy fun fs _ => do
      let names ← fs.mapM (·.fvarId!.getUserName)
      let named := names.all (!·.hasMacroScopes)
      let mut fields : Array Field := #[]
      let mut invs : Array Invariant := #[]
      let mut valueFvars : Array Lean.Expr := #[]
      let mut valueIdx : Array Nat := #[]
      for h : i in [0:fs.size] do
        let f := fs[i]
        let ty ← inferType f
        let userName ← f.fvarId!.getUserName
        let raw := componentString userName.eraseMacroScopes
        let optKey := named && raw.endsWith "?" && raw.length > 1
        let key := if optKey then (raw.dropEnd 1).toString else raw
        let fname := if named then sanitize key else s!"a{i}"
        if ← isProp ty then
          let ty := ty.headBeta
          for h : j in [0:valueFvars.size] do
            if let some ann ← boundOf valueFvars[j] ty then
              let k := valueIdx[j]!
              fields := fields.modify k fun f => { f with annotations := f.annotations.push ann }
          let dn := deciderName py (componentString ctor) fname
          compileDecider dn valueFvars ty
          modify fun s => { s with deciders := s.deciders.push dn }
          invs := invs.push { field := fname, prop := toString (← ppExpr ty), decider := dn, args := valueIdx }
          continue
        if (← whnf ty).isSort then throwError "constructor `{ctor}` has a type field"
        let loc := match layout.fieldInfo[i]? with
          | some (.object j _) => FieldLoc.obj j
          | some (.usize j) => FieldLoc.scalar (scalarKey j 0)
          | some (.scalar _ off _) => FieldLoc.scalar (scalarKey (layout.ctorInfo.size + layout.ctorInfo.usize) off)
          | _ => FieldLoc.erased
        let d ← descOf ty
        valueIdx := valueIdx.push fields.size
        valueFvars := valueFvars.push f
        let alias := if named && fname != key then some key else none
        fields := fields.push { name := fname, loc, desc := d, alias, omitNone := optKey }
      let i := layout.ctorInfo
      return { name := componentString ctor, py := py ++ "_" ++ sanitize (componentString ctor), cidx := i.cidx,
               size := i.size, unit := i.size == 0 && i.usize == 0 && i.ssize == 0, fields,
               positional := !named, invariants := invs : Variant }
    variants := variants.push v
  let kind ← do
    if c == ``Subtype then
      let v := variants[0]!
      let some f := v.fields[0]? | throwError "subtype without a value: {t}"
      let some inv := v.invariants[0]? | throwError "subtype without a property: {t}"
      pure (TypeKind.subtype f inv)
    else if variants.size == 1 then
      if (← Compiler.LCNF.hasTrivialStructure? c).isSome then pure (TypeKind.trivial variants[0]!)
      else pure (TypeKind.struct variants[0]!)
    else if c.getRoot == `LeanPythonUnions then pure (TypeKind.modelUnion variants)
    else if variants.all (·.fields.isEmpty) && variants.all (·.invariants.isEmpty) then
      pure (TypeKind.enum (variants.map (·.name)))
    else pure (TypeKind.sum variants)
  modify fun s => { s with
    types := s.types.push { py, lean := leanStr, kind, external := ext.map (·.2.2) }
    index := s.index.insert py
    inProgress := s.inProgress.erase py }
  return .named py

end

/-! ## Signatures -/

inductive ParamKind where
  | value (name : String) (d : Desc)
  | erased
  | world
  deriving Inhabited

structure PublicSig where
  params : Array ParamKind
  result : Desc
  /-- Returns `EST.Out` (an `IO`/`EIO` action). -/
  est : Bool

def publicSig (name : Name) (ps : Array Param) : MarshalM PublicSig := do
  let some ci := (← getEnv).find? name | throwError "unknown constant {name}"
  forallBoundedTelescope ci.type ps.size fun xs body => do
    if xs.size != ps.size then
      throwError "the IR has {ps.size} parameters but the type has {xs.size} binders"
    let body ← whnfR body
    let est := body.getAppFn.constName? == some `EST.Out
    let errTy := if est then body.getAppArgs[0]!.constName? else none
    if est && errTy != some ``IO.Error then throwError "`EIO` with an error type other than `IO.Error`"
    let mut params := #[]
    let mut used : Std.HashSet String := {}
    for h : i in [0:xs.size] do
      let x := xs[i]
      let ldecl ← x.fvarId!.getDecl
      if est && i + 1 == xs.size then params := params.push .world; continue
      if ← isProp ldecl.type then throwError "takes a proof argument `{ldecl.userName}`"
      if (← whnf ldecl.type).isSort then throwError "polymorphic (takes the type `{ldecl.userName}`)"
      if ldecl.binderInfo.isInstImplicit then throwError "takes an instance argument `{ldecl.type}`"
      let d ← descOf ldecl.type
      let base := if ldecl.userName.hasMacroScopes then s!"arg{i}" else sanitize (componentString ldecl.userName.eraseMacroScopes)
      let base := if base == "_" then s!"arg{i}" else base
      let mut nm := base
      let mut k := 1
      while used.contains nm do
        nm := s!"{base}_{k}"; k := k + 1
      used := used.insert nm
      params := params.push (.value nm d)
    let result ← if est then descOf body.getAppArgs[2]! else descOf body
    return { params, result, est }

/-! ## Python code -/

def fieldDescs (fs : Array Field) : String :=
  ", ".intercalate (fs.toList.map fun f =>
    let loc := match f.loc with
      | .obj i => s!"_m.Obj({i})"
      | .scalar k => s!"_m.Scalar({k})"
      | .erased => "_m.ERASED"
    s!"_m.FieldInfo({quoteString f.name}, {loc}, {f.desc.pyDesc})")

def invariantDescs (vs : Array Invariant) : String :=
  ", ".intercalate (vs.toList.map fun inv =>
    s!"_m.Invariant({quoteString inv.field}, {quoteString inv.prop}, {fnName inv.decider}, ({String.join (inv.args.toList.map (s!"{·}, "))}))")

def variantInfo (v : Variant) : String :=
  s!"_m.CtorInfo({quoteString v.name}, {v.cidx}, {v.size}, {if v.unit then "True" else "False"}, [{fieldDescs v.fields}], [{invariantDescs v.invariants}], {if v.positional then "True" else "False"})"

def Field.pyType (f : Field) : String :=
  if f.annotations.isEmpty then f.desc.pyType
  else s!"Annotated[{f.desc.pyType}, {", ".intercalate f.annotations.toList}]"

def fieldLines (v : Variant) : String :=
  String.join (v.fields.toList.map fun f =>
    let isOpt := match f.desc with | .option _ => true | _ => false
    let parts := (if isOpt then #["default=None"] else #[]) ++
      (match f.alias with | some a => #[s!"alias={quoteString a}"] | none => #[]) ++
      (if f.omitNone then #["exclude_if=_m.is_none"] else #[])
    let dflt := if parts.isEmpty then "" else
      if parts == #["default=None"] then " = None" else s!" = _m.Field({", ".intercalate parts.toList})"
    s!"    {f.name}: {quoteString f.pyType}{dflt}\n")

def emitTypeDef (td : TypeDef) : String :=
  match td.external with
  | some true =>
    match td.kind with
    | .struct v => s!"_m.adopt({td.py}, {variantInfo v}, trivial=False)\n"
    | .trivial v => s!"_m.adopt({td.py}, {variantInfo v}, trivial=True)\n"
    | .enum _ => s!"_m.adopt_enum({td.py})\n"
    | _ => ""
  | some false => ""
  | none =>
  match td.kind with
  | .struct v | .trivial v =>
    let trivial := match td.kind with | .trivial _ => "True" | _ => "False"
    let body := fieldLines v
    s!"class {td.py}(_m.LeanModel):\n    {quoteString s!"Lean `{td.lean}`."}\n{body}\n\n{td.py}.__lean__ = _m.StructInfo({td.py}, {variantInfo v}, trivial={trivial})\n"
  | .subtype f inv =>
    s!"{td.py} = _m.subtype({f.desc.pyType}, {f.desc.pyDesc}, {invariantDescs #[inv]}, [{", ".intercalate f.annotations.toList}])\n"
  | .enum ctors =>
    let members := String.join (ctors.toList.map fun c => s!"    {sanitize c} = {quoteString c}\n")
    let plain := if td.py.startsWith "LeanPythonLiterals" then "True" else "False"
    s!"class {td.py}(_m.LeanEnum):\n    {quoteString s!"Lean `{td.lean}`."}\n{members}\n\n{td.py}.__lean__ = _m.EnumInfo({td.py}, plain={plain})\n"
  | .modelUnion vs =>
    let alts := ", ".intercalate (vs.toList.map fun v => s!"({v.cidx}, {(v.fields[0]!).desc.pyDesc})")
    s!"{td.py} = _m.ModelUnion([{alts}])\n"
  | .sum vs =>
    let base := s!"class {td.py}(_m.LeanInductive):\n    {quoteString s!"Lean `{td.lean}`."}\n\n"
    let subs := String.join (vs.toList.map fun v =>
      let body := fieldLines v
      s!"class {v.py}(_m.LeanModel, {td.py}):\n{if body.isEmpty then "    pass\n" else body}\n\n")
    let infos := ", ".intercalate (vs.toList.map fun v => s!"({v.py}, {variantInfo v})")
    base ++ subs ++ s!"_m.register_inductive({td.py}, [{infos}])\n"

def typeNames (td : TypeDef) : Array String :=
  #[td.py]

end LeanPython
