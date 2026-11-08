import Lean
import LeanRust.EmitRs

/-! # Public functions

The marshalling descriptor (`Desc`) of a Lean type is built from its declaration in the
environment. Constructor layouts come from `Compiler.LCNF.getCtorLayout`, structures with one
relevant field are represented by that field (`Compiler.LCNF.hasTrivialStructure?`), and
inductive types are registered once as generated Rust structs and enums. The public functions
are safe Rust functions that convert their arguments with `ToLean`, call the internal function
and convert the result with `FromLean`. -/

open Lean Lean.IR Meta

namespace LeanRust

/-! ## Rust names -/

def rustKeywords : List String :=
  ["as", "async", "await", "break", "const", "continue", "dyn", "else", "enum", "extern", "false",
   "fn", "for", "gen", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
   "ref", "return", "static", "struct", "trait", "true", "try", "type", "unsafe", "use", "where",
   "while", "abstract", "become", "box", "do", "final", "macro", "override", "priv", "typeof",
   "unsized", "virtual", "yield"]

/-- A Rust identifier for `s`: keywords get `r#`, names that cannot be raw get `_`. -/
def rustIdent (s : String) : String :=
  if ["self", "Self", "super", "crate", "_", ""].contains s then s ++ "_"
  else if rustKeywords.contains s then "r#" ++ s
  else if s.front.isDigit then "_" ++ s
  else s

/-- `?` → `_q`, `!` → `_bang`, `'` → `_prime`, other characters that Rust does not accept → `_`. -/
def sanitize (s : String) : String :=
  s.foldl (fun acc c => acc ++ match c with
    | '?' => "_q"
    | '!' => "_bang"
    | '\'' => "_prime"
    | c => if c.isAlphanum || c == '_' then c.toString else "_") ""

def snakeCase (s : String) : String := Id.run do
  let cs := s.toList.toArray
  let mut acc := ""
  for h : i in [0:cs.size] do
    let c := cs[i]
    if c.isUpper then
      let prev := if i > 0 then cs[i - 1]! else ' '
      let next := cs[i + 1]?.getD ' '
      if i > 0 && (prev.isLower || prev.isDigit || (prev.isUpper && next.isLower)) then acc := acc.push '_'
      acc := acc.push c.toLower
    else acc := acc.push c
  return acc

def componentString : Name → String
  | .str _ s => s
  | .num _ n => toString n
  | .anonymous => ""

def camelCase (s : String) : String :=
  String.join ((sanitize s).splitOn "_" |>.map String.capitalize)

/-- `n` relative to the namespace `strip` (unchanged when `strip` is not a prefix). -/
def stripName (strip n : Name) : Name :=
  if strip != .anonymous && strip.isPrefixOf n && strip != n then n.replacePrefix strip .anonymous else n

def rustFnName (strip n : Name) : String :=
  rustIdent ("_".intercalate ((stripName strip n).components.map fun c => sanitize (snakeCase (componentString c))))

def rustTypeName (strip n : Name) : String :=
  rustIdent (String.join ((stripName strip n).components.map fun c => camelCase (componentString c)))

def rustFieldName (s : String) : String := rustIdent (sanitize (snakeCase s))

/-! ## Descriptors -/

/-- How a value crosses between Rust and Lean. -/
inductive Desc where
  /-- A type converted by the runtime's `ToLean`/`FromLean` (`bool`, `u8`, …, `rt::Nat`). -/
  | prim (rust : String)
  | list (d : Desc)
  | array (d : Desc)
  | option (d : Desc)
  | except (e a : Desc)
  | prod (a b : Desc)
  /-- `Fin n`: a `usize` checked against `n` on the way to Lean. -/
  | fin (n : Nat)
  /-- A generated struct or enum. -/
  | named (rust : String)
  /-- `Box<T>`, for recursive fields. -/
  | boxed (d : Desc)
  /-- A type of Aeneas's model of Rust converted by the runtime's `Model` (`Std.U32` as `u32`,
      `Str` as `String`, the structs and enums of the crate). -/
  | model (rust : String)
  /-- Aeneas's `Slice α` and `alloc.vec.Vec α`: `Vec<T>`. -/
  | slice (d : Desc)
  /-- Aeneas's `Result α`: the value, a Rust panic when the result is not `ok`. -/
  | result (d : Desc)
  deriving Inhabited, BEq

/-- Where a constructor field lives in the object. -/
inductive FieldLoc where
  | obj (i : Nat)
  | usize (i : Nat)
  | scalar (off : Nat) (ty : IRType)
  deriving Inhabited

structure Field where
  /-- Rust field name, or empty for a tuple field. -/
  name : String
  loc : FieldLoc
  desc : Desc
  deriving Inhabited

structure Variant where
  name : String
  info : CtorInfo
  fields : Array Field
  deriving Inhabited

inductive TypeKind where
  /-- A structure with one constructor (fields in the object). -/
  | struct (v : Variant)
  /-- A structure represented by its one relevant field. -/
  | newtype (field : String) (d : Desc)
  /-- Nullary constructors only: a scalar tag. -/
  | enum (ctors : Array String)
  | sum (variants : Array Variant)
  deriving Inhabited

structure TypeDef where
  rust : String
  lean : String
  module : String
  kind : TypeKind
  eqHash : Bool
  /-- Some constructor has a proof field: the Rust value cannot carry the invariant. -/
  hasProof : Bool
  /-- Defined by another generated module (a type path), not emitted here. -/
  external : Bool := false
  deriving Inhabited

partial def Desc.rustType : Desc → String
  | .prim r | .named r => r
  | .list d | .array d => s!"Vec<{d.rustType}>"
  | .option d => s!"Option<{d.rustType}>"
  | .except e a => s!"Result<{a.rustType}, {e.rustType}>"
  | .prod a b => s!"({a.rustType}, {b.rustType})"
  | .fin _ => "usize"
  | .boxed d => s!"Box<{d.rustType}>"
  | .model r => r
  | .slice d => s!"Vec<{d.rustType}>"
  | .result d => d.rustType

partial def Desc.named? : Desc → Array String
  | .named r => #[r]
  | .list d | .array d | .option d | .boxed d | .slice d | .result d => d.named?
  | .except a b | .prod a b => a.named? ++ b.named?
  | _ => #[]

structure MarshalState where
  types : Array TypeDef := #[]
  index : Std.HashMap String Nat := {}
  inProgress : Std.HashSet String := {}
  /-- Lean type of each registered Rust type name, to detect collisions. -/
  leanOf : Std.HashMap String String := {}

structure MarshalConfig where
  /-- Namespace removed from the Rust names. -/
  strip : Name
  /-- Types of these namespaces are defined by other generated modules at these Rust paths. -/
  typePaths : Array (Name × String) := #[]
  /-- The namespace of the crate's Aeneas model: its types are the crate's Rust types. -/
  modelNs : Option Name := none

abbrev MarshalM := ReaderT MarshalConfig (StateRefT MarshalState MetaM)

def moduleOf (env : Environment) (c : Name) : String :=
  match env.getModuleIdxFor? c with
  | some idx => toString env.header.moduleNames[idx.toNat]!
  | none => toString env.header.mainModule

def toIRCtorInfo (i : Compiler.LCNF.CtorInfo) : CtorInfo :=
  { name := i.name, cidx := i.cidx, size := i.size, usize := i.usize, ssize := i.ssize }

def scalarIRType (sz : Nat) (ty : Lean.Expr) : IRType :=
  match ty.constName? with
  | some ``Float => .float
  | some ``Float32 => .float32
  | _ => match sz with
    | 1 => .uint8
    | 2 => .uint16
    | 4 => .uint32
    | _ => .uint64

/-- Inside a type being registered, a direct reference to it (not through `Vec`) is boxed. -/
partial def boxRec (inProgress : Std.HashSet String) : Desc → Desc
  | .named r => if inProgress.contains r then .boxed (.named r) else .named r
  | .option d => .option (boxRec inProgress d)
  | .except e a => .except (boxRec inProgress e) (boxRec inProgress a)
  | .prod a b => .prod (boxRec inProgress a) (boxRec inProgress b)
  | d => d

def unsupportedTypes : List Name := [``ByteArray, ``FloatArray, ``Thunk, ``Task, ``Subtype]

/-- The Rust types of Aeneas's integer types, by the constructor of `UScalarTy` or `IScalarTy`. -/
def aeneasScalars : List (Name × String) :=
  [(`Aeneas.Std.UScalarTy.U8, "u8"), (`Aeneas.Std.UScalarTy.U16, "u16"), (`Aeneas.Std.UScalarTy.U32, "u32"),
   (`Aeneas.Std.UScalarTy.U64, "u64"), (`Aeneas.Std.UScalarTy.U128, "u128"), (`Aeneas.Std.UScalarTy.Usize, "usize"),
   (`Aeneas.Std.IScalarTy.I8, "i8"), (`Aeneas.Std.IScalarTy.I16, "i16"), (`Aeneas.Std.IScalarTy.I32, "i32"),
   (`Aeneas.Std.IScalarTy.I64, "i64"), (`Aeneas.Std.IScalarTy.I128, "i128"), (`Aeneas.Std.IScalarTy.Isize, "isize")]

/-- The Rust path of a type of the crate's model: `my_crate.inv.Item` → `crate::inv::Item`. -/
def modelRustPath (ns c : Name) : String :=
  "::".intercalate ("crate" :: (c.replacePrefix ns .anonymous).components.map componentString)

mutual

partial def descOf (t : Lean.Expr) : MarshalM Desc := do
  let t ← whnfR (← instantiateMVars t)
  let t := t.consumeMData
  if t.isForall then throwError "function type `{t}`"
  if t.isSort then throwError "type argument `{t}`"
  let args := t.getAppArgs
  let .const c _ := t.getAppFn | throwError "type variable `{t}`"
  match c, args with
  | ``Nat, #[] => return .prim "rt::Nat"
  | ``Int, #[] => return .prim "rt::Int"
  | ``Bool, #[] => return .prim "bool"
  | ``Decidable, #[_] => return .prim "bool"
  | ``String, #[] => return .prim "String"
  | ``Char, #[] => return .prim "char"
  | ``UInt8, #[] => return .prim "u8"
  | ``UInt16, #[] => return .prim "u16"
  | ``UInt32, #[] => return .prim "u32"
  | ``UInt64, #[] => return .prim "u64"
  | ``USize, #[] => return .prim "usize"
  | ``Int8, #[] => return .prim "i8"
  | ``Int16, #[] => return .prim "i16"
  | ``Int32, #[] => return .prim "i32"
  | ``Int64, #[] => return .prim "i64"
  | ``ISize, #[] => return .prim "isize"
  | ``Float, #[] => return .prim "f64"
  | ``Float32, #[] => return .prim "f32"
  | ``Unit, #[] | ``PUnit, #[] => return .prim "()"
  | ``List, #[a] => return .list (← descOf a)
  | ``Array, #[a] => return .array (← descOf a)
  | ``Option, #[a] => return .option (← descOf a)
  | ``Except, #[e, a] => return .except (← descOf e) (← descOf a)
  | ``Prod, #[a, b] => return .prod (← descOf a) (← descOf b)
  | ``Fin, #[n] =>
    let some v ← (evalNat (← instantiateMVars n)).run | throwError "`Fin` with a bound that is not a literal: `{n}`"
    if v ≥ 2 ^ 64 then throwError "`Fin {v}` does not fit in usize"
    return .fin v
  | `Aeneas.Std.UScalar, #[ty] | `Aeneas.Std.IScalar, #[ty] =>
    let some k := ty.constName? | throwError "scalar type `{t}`"
    match aeneasScalars.lookup k with
    | some r => return .model r
    | none => throwError "scalar type `{t}`"
  | `Aeneas.Std.Slice, #[a] | `Aeneas.Std.alloc.vec.Vec, #[a] => return .slice (← descOf a)
  | `Aeneas.Std.Str, #[] => return .model "String"
  | `Aeneas.Std.Result, #[a] => return .result (← descOf a)
  | _, _ =>
    if unsupportedTypes.contains c then throwError "unsupported type `{c}`"
    if c.getRoot == `Aeneas then throwError "unsupported type of Aeneas's model `{t}`"
    if let some ns := (← read).modelNs then
      if ns.isPrefixOf c && (moduleOf (← getEnv) c).startsWith s!"LeanRustGen.Model.{ns}." then
        unless args.isEmpty do throwError "generic type of the model `{t}`"
        return .model (modelRustPath ns c)
    namedDesc c t args

partial def namedDesc (c : Name) (t : Lean.Expr) (args : Array Lean.Expr) : MarshalM Desc := do
  let env ← getEnv
  let some (.inductInfo ind) := env.find? c | throwError "unsupported type `{t}`"
  if ind.numIndices != 0 then throwError "type family `{t}`"
  let cfg ← read
  let ext := cfg.typePaths.find? fun (ns, _) => ns.isPrefixOf c
  let mut rust := match ext with
    | some (ns, path) => path ++ "::" ++ rustTypeName ns c
    | none => rustTypeName cfg.strip c
  for a in args[:ind.numParams] do
    unless ← isProof a do
      rust := rust ++ camelCase (toString (← ppExpr a))
  let leanStr := toString (← ppExpr t)
  match (← get).leanOf[rust]? with
  | some l => if l != leanStr then throwError "Rust type name `{rust}` is used by `{l}` and `{leanStr}`"
  | none => pure ()
  if (← get).index.contains rust || (← get).inProgress.contains rust then return .named rust
  modify fun s => { s with inProgress := s.inProgress.insert rust, leanOf := s.leanOf.insert rust leanStr }
  let mut variants : Array Variant := #[]
  let mut hasProof := false
  for ctor in ind.ctors do
    let some (.ctorInfo ci) := env.find? ctor | throwError "unknown constructor {ctor}"
    let layout ← Compiler.LCNF.getCtorLayout ctor
    let ctorTy ← instantiateForall ci.type args[:ci.numParams]
    let fieldsOf ← forallTelescopeReducing ctorTy fun fs _ => do
      let mut out : Array (Name × Option Lean.Expr × Bool) := #[]
      for f in fs do
        let ty ← f.fvarId!.getType
        out := out.push (← f.fvarId!.getUserName, some ty, ← isProp ty)
      return out
    let named := fieldsOf.all fun (n, _) => !n.hasMacroScopes
    let mut fields : Array Field := #[]
    for h : i in [0:layout.fieldInfo.size] do
      let (n, ty?, proof) := fieldsOf[i]!
      if proof then hasProof := true
      let loc ← match layout.fieldInfo[i] with
        | .object j _ => pure (some (FieldLoc.obj j))
        | .usize j => pure (some (FieldLoc.usize j))
        | .scalar sz off ty => pure (some (FieldLoc.scalar off (scalarIRType sz ty)))
        | .erased | .void => pure none
      let some loc := loc | continue
      let some fty := ty? | continue
      let d ← descOf fty
      let name := if named then rustFieldName (componentString n.eraseMacroScopes) else ""
      fields := fields.push { name, loc, desc := boxRec (← get).inProgress d }
    variants := variants.push { name := rustTypeName .anonymous (Name.mkSimple (componentString ctor)), info := toIRCtorInfo layout.ctorInfo, fields }
  let kind ← do
    if variants.size == 1 then
      if let some _ ← Compiler.LCNF.hasTrivialStructure? c then
        let v := variants[0]!
        let some f := v.fields[0]? | throwError "trivial structure without a field: {c}"
        pure (TypeKind.newtype f.name f.desc)
      else pure (TypeKind.struct variants[0]!)
    else if variants.all (·.fields.isEmpty) then pure (TypeKind.enum (variants.map (·.name)))
    else pure (TypeKind.sum variants)
  let eqHash ← try
      let inst ← mkAppM ``DecidableEq #[t]
      pure (← synthInstance? inst).isSome
    catch _ => pure false
  let floats := variants.any fun v => v.fields.any fun f => f.desc == .prim "f64" || f.desc == .prim "f32"
  let td : TypeDef := { rust, lean := leanStr, module := moduleOf env c, kind, eqHash := eqHash && !floats, hasProof, external := ext.isSome }
  modify fun s => { s with
    types := s.types.push td
    index := s.index.insert rust s.types.size
    inProgress := s.inProgress.erase rust }
  return .named rust

end

/-! ## Conversions -/

/-- Rust expression turning the Rust value `x` into an owned boxed `Obj`. -/
partial def toObj (d : Desc) (x : String) (k : Nat := 0) : String :=
  let v := s!"v{k}"
  match d with
  | .prim _ | .named _ => s!"rt::ToLean::to_lean({x})"
  | .list d => s!"rt::list_to_lean({x}, |{v}| {toObj d v (k + 1)})"
  | .array d => s!"rt::array_to_lean({x}, |{v}| {toObj d v (k + 1)})"
  | .option d => s!"rt::option_to_lean({x}, |{v}| {toObj d v (k + 1)})"
  | .except e a => s!"rt::except_to_lean({x}, |{v}| {toObj e v (k + 1)}, |{v}| {toObj a v (k + 1)})"
  | .prod a b => s!"rt::prod_to_lean({x}, |{v}| {toObj a v (k + 1)}, |{v}| {toObj b v (k + 1)})"
  | .fin n => s!"rt::fin_to_lean({x}, {n})"
  | .boxed d => toObj d s!"(*{x})" k
  | .model _ => s!"rt::Model::to_model({x})"
  | .slice d => s!"rt::slice_to_model({x}, |{v}| {toObj d v (k + 1)})"
  | .result d => s!"__lr_result_ok({toObj d x k})"

/-- Rust expression reading a Rust value from the borrowed boxed `Obj` `x`. -/
partial def fromObj (d : Desc) (x : String) (k : Nat := 0) : String :=
  let v := s!"v{k}"
  match d with
  | .prim r | .named r => s!"<{r} as rt::FromLean>::from_lean({x})"
  | .list d => s!"rt::list_from_lean({x}, |{v}| {fromObj d v (k + 1)})"
  | .array d => s!"rt::array_from_lean({x}, |{v}| {fromObj d v (k + 1)})"
  | .option d => s!"rt::option_from_lean({x}, |{v}| {fromObj d v (k + 1)})"
  | .except e a => s!"rt::except_from_lean({x}, |{v}| {fromObj e v (k + 1)}, |{v}| {fromObj a v (k + 1)})"
  | .prod a b => s!"rt::prod_from_lean({x}, |{v}| {fromObj a v (k + 1)}, |{v}| {fromObj b v (k + 1)})"
  | .fin _ => s!"rt::fin_from_lean({x})"
  | .boxed d => s!"Box::new({fromObj d x k})"
  | .model r => s!"<{r} as rt::Model>::from_model({x})"
  | .slice d => s!"rt::slice_from_model({x}, |{v}| {fromObj d v (k + 1)})"
  | .result d => s!"rt::result_value(__lr_result_match({x}), |{v}| {fromObj d v (k + 1)})"

def signedOf : String → Option String
  | "i8" => some "u8"
  | "i16" => some "u16"
  | "i32" => some "u32"
  | "i64" => some "u64"
  | "isize" => some "usize"
  | _ => none

/-- Rust expression of IR type `ty` for the Rust value `x` (an owned `Obj` for object types). -/
partial def toIR (types : Std.HashMap String TypeDef) (d : Desc) (ty : IRType) (x : String) : String :=
  if !ty.isScalar then toObj d x else
  match d with
  | .prim "bool" => s!"({x}) as u8"
  | .prim "char" => s!"({x}) as u32"
  | .prim r => match signedOf r with
    | some u => s!"({x}) as {u}"
    | none => x
  | .model _ => s!"rt::lean_unbox(rt::Model::to_model({x})) as {rsType ty}"
  | .named r => match (types[r]?.map (·.kind) : Option TypeKind) with
    | some (.newtype f inner) => toIR types inner ty s!"({x}).{if f.isEmpty then "0" else f}"
    | _ => s!"({x}) as {rsType ty}"
  | _ => x

/-- Rust expression reading a Rust value from `x` of IR type `ty` (borrowed for objects). -/
partial def fromIR (types : Std.HashMap String TypeDef) (d : Desc) (ty : IRType) (x : String) : String :=
  if !ty.isScalar then fromObj d x else
  match d with
  | .prim "bool" => s!"({x}) != 0"
  | .prim "char" => s!"rt::char_of_u32({x})"
  | .prim r => match signedOf r with
    | some _ => s!"({x}) as {r}"
    | none => x
  | .model r => s!"<{r} as rt::Model>::from_model(rt::lean_box(({x}) as usize))"
  | .named r => match (types[r]?.map (·.kind) : Option TypeKind) with
    | some (.newtype f inner) =>
      if f.isEmpty then s!"{r}({fromIR types inner ty x})" else s!"{r} \{ {f}: {fromIR types inner ty x} }"
    | _ => s!"{r}::from_lean_tag(({x}) as u32)"
  | _ => x

/-! ## Generated types -/

def fieldBinder (i : Nat) : String := s!"f{i}"

def fieldSet (types : Std.HashMap String TypeDef) (v : Variant) (f : Field) (x : String) : String :=
  let n := v.info.size + v.info.usize
  match f.loc with
  | .obj i => s!"rt::lean_ctor_set(o, {i}, {toObj f.desc x});"
  | .usize i => s!"rt::lean_ctor_set_usize(o, {i}, {toIR types f.desc .usize x});"
  | .scalar off ty =>
    match ssetFn ty with
    | .ok fn => s!"rt::{fn}(o, {offsetStr n off}, {toIR types f.desc ty x});"
    | .error _ => "rt::lean_internal_panic_unreachable();"

def fieldGet (types : Std.HashMap String TypeDef) (v : Variant) (f : Field) : String :=
  let n := v.info.size + v.info.usize
  match f.loc with
  | .obj i => fromObj f.desc s!"rt::lean_ctor_get(o, {i})"
  | .usize i => fromIR types f.desc .usize s!"rt::lean_ctor_get_usize(o, {i})"
  | .scalar off ty =>
    match sprojFn ty with
    | .ok fn => fromIR types f.desc ty s!"rt::{fn}(o, {offsetStr n off})"
    | .error _ => "rt::lean_internal_panic_unreachable()"

def isUnitCtor (v : Variant) : Bool := v.info.size == 0 && v.info.usize == 0 && v.info.ssize == 0

/-- Statements building the object of `v` from the bindings `f0`, `f1`, … into `o`. -/
def buildCtor (types : Std.HashMap String TypeDef) (v : Variant) : String := Id.run do
  if isUnitCtor v then return s!"rt::lean_box({v.info.cidx})"
  let mut s := s!"let o = {ctorAlloc v.info}; "
  for h : i in [0:v.fields.size] do
    s := s ++ fieldSet types v v.fields[i] (fieldBinder i) ++ " "
  return "{ " ++ s ++ "o }"

def readCtor (types : Std.HashMap String TypeDef) (path : String) (v : Variant) : String :=
  if v.fields.isEmpty then path
  else if v.fields.all (!·.name.isEmpty) then
    path ++ " { " ++ ", ".intercalate (v.fields.toList.map fun f => s!"{f.name}: {fieldGet types v f}") ++ " }"
  else path ++ "(" ++ ", ".intercalate (v.fields.toList.map (fieldGet types v)) ++ ")"

def fieldPattern (path : String) (v : Variant) : String :=
  if v.fields.isEmpty then path
  else if v.fields.all (!·.name.isEmpty) then
    path ++ " { " ++ ", ".intercalate ((v.fields.toList.zipIdx).map fun (f, i) => s!"{f.name}: {fieldBinder i}") ++ " }"
  else path ++ "(" ++ ", ".intercalate ((List.range v.fields.size).map fieldBinder) ++ ")"

def fieldDecls (v : Variant) (pub : Bool) : String :=
  let p := if pub then "pub " else ""
  if v.fields.all (!·.name.isEmpty) then
    "{ " ++ ", ".intercalate (v.fields.toList.map fun f => s!"{p}{f.name}: {f.desc.rustType}") ++ " }"
  else "(" ++ ", ".intercalate (v.fields.toList.map fun f => s!"{p}{f.desc.rustType}") ++ ")"

def derives (td : TypeDef) (copy : Bool) : String :=
  let base := if copy then ["Debug", "Clone", "Copy", "PartialEq"] else ["Debug", "Clone", "PartialEq"]
  let all := if td.eqHash then base ++ ["Eq", "Hash"] else base
  s!"#[derive({", ".intercalate all})]"

def emitTypeDef (types : Std.HashMap String TypeDef) (td : TypeDef) : String :=
  let doc := s!"#[doc = {quoteString s!"Lean type `{td.lean}` (module `{td.module}`)."}]\n"
  let r := td.rust
  let impls (toBody fromBody : String) :=
    s!"impl rt::ToLean for {r} \{\n    unsafe fn to_lean(self) -> Obj \{\n        {toBody}\n    }\n}\n" ++
    s!"impl rt::FromLean for {r} \{\n    unsafe fn from_lean(o: Obj) -> Self \{\n        {fromBody}\n    }\n}\n"
  match td.kind with
  | .struct v =>
    let decl := if v.fields.isEmpty then s!"pub struct {r} \{}\n"
      else if v.fields.all (!·.name.isEmpty) then s!"pub struct {r} {fieldDecls v true}\n"
      else s!"pub struct {r}{fieldDecls v true};\n"
    let bind := if v.fields.isEmpty then s!"let _ = self;" else s!"let {fieldPattern r v} = self;"
    let fromBody := if v.fields.isEmpty then s!"let _ = o; {r} \{}" else readCtor types r v
    doc ++ derives td false ++ "\n" ++ decl ++
      impls s!"{bind} {buildCtor types v}" fromBody
  | .newtype f inner =>
    let decl := if f.isEmpty then s!"pub struct {r}(pub {inner.rustType});\n"
      else s!"pub struct {r} \{ pub {f}: {inner.rustType} }\n"
    let acc := if f.isEmpty then "0" else f
    let mk := if f.isEmpty then s!"{r}({fromObj inner "o"})" else s!"{r} \{ {f}: {fromObj inner "o"} }"
    doc ++ derives td false ++ "\n" ++ decl ++ impls (toObj inner s!"self.{acc}") mk
  | .enum ctors =>
    let variants := ctors.toList.zipIdx.map fun (c, i) => s!"    {c} = {i},\n"
    let arms := ctors.toList.zipIdx.map fun (c, i) => s!"            {i} => {r}::{c},\n"
    doc ++ derives td true ++ "\n" ++ s!"pub enum {r} \{\n" ++ String.join variants ++ "}\n" ++
      s!"impl {r} \{\n    #[doc(hidden)]\n    pub fn from_lean_tag(tag: u32) -> Self \{\n        match tag \{\n" ++ String.join arms ++
      "            _ => unreachable!(),\n        }\n    }\n}\n" ++
      impls "rt::lean_box(self as usize)" s!"{r}::from_lean_tag(rt::lean_unbox(o) as u32)"
  | .sum vs =>
    let variants := vs.toList.map fun v =>
      if v.fields.isEmpty then s!"    {v.name},\n" else s!"    {v.name}{fieldDecls v false},\n"
    let toArms := vs.toList.map fun v => s!"            {fieldPattern s!"{r}::{v.name}" v} => {buildCtor types v},\n"
    let fromArms := vs.toList.map fun v => s!"            {v.info.cidx} => {readCtor types s!"{r}::{v.name}" v},\n"
    doc ++ derives td false ++ "\n" ++ s!"pub enum {r} \{\n" ++ String.join variants ++ "}\n" ++
      impls ("match self {\n" ++ String.join toArms ++ "        }")
        ("match rt::lean_obj_tag(o) {\n" ++ String.join fromArms ++ "            _ => unreachable!(),\n        }")

/-! ## Signatures -/

/-- Code of an instance argument: a call of compiled functions on erased arguments. -/
inductive InstCode where
  | call (fn : Name) (args : Array (Option InstCode))

inductive ParamKind where
  /-- An irrelevant parameter: `lean_box(0)`. -/
  | erased
  /-- The `IO` world: not passed. -/
  | world
  | value (rust : String) (d : Desc)
  | inst (code : InstCode)

structure PublicSig where
  /-- Per IR parameter. -/
  params : Array ParamKind
  result : Desc
  /-- `IO`: `EST.Out IO.Error`; `BaseIO`: `EST.Out Empty` with `io = false`. -/
  est : Bool
  io : Bool
  /-- Functions instance arguments call. -/
  instFns : Array Name
  deriving Inhabited

partial def instCode (e : Lean.Expr) : MarshalM (InstCode × Array Name) := do
  let e ← instantiateMVars e
  let .const c _ := e.getAppFn | throwError "instance `{e}` is not a constant application"
  let some d := findEnvDecl (← getEnv) c | throwError "instance `{c}` has no IR"
  let args := e.getAppArgs
  if d.params.size != args.size then throwError "instance `{c}` is partially applied"
  let mut out : Array (Option InstCode) := #[]
  let mut fns := #[c]
  for h : i in [0:args.size] do
    let p := d.params[i]!
    if p.ty.isErased then out := out.push none
    else if p.ty.isScalar then throwError "instance `{c}` takes a scalar argument"
    else
      let (code, fs) ← instCode args[i]
      out := out.push (some code)
      fns := fns ++ fs
  return (.call c out, fns)

def publicSig (name : Name) (ps : Array Param) : MarshalM PublicSig := do
  let some ci := (← getEnv).find? name | throwError "unknown constant {name}"
  forallBoundedTelescope ci.type ps.size fun xs body => do
    if xs.size != ps.size then
      throwError "the IR has {ps.size} parameters but the type has {xs.size} binders"
    let body ← whnfR body
    let est := body.getAppFn.constName? == some `EST.Out
    let errTy := if est then body.getAppArgs[0]!.constName? else none
    if est && errTy != some ``IO.Error && errTy != some ``Empty then
      throwError "`EIO` with an error type other than `IO.Error`"
    let mut params := #[]
    let mut instFns := #[]
    let mut used : Std.HashSet String := {}
    for h : i in [0:xs.size] do
      let x := xs[i]
      let p := ps[i]!
      let ldecl ← x.fvarId!.getDecl
      if est && i + 1 == xs.size then params := params.push .world; continue
      if ← isProp ldecl.type then throwError "takes a proof argument `{ldecl.userName}`"
      if p.ty.isErased then params := params.push .erased; continue
      if ldecl.binderInfo.isInstImplicit then
        if ldecl.type.hasFVar then throwError "instance argument over a type variable"
        let some inst ← withLCtx {} #[] (synthInstance? ldecl.type) | throwError "cannot synthesize the instance `{ldecl.type}`"
        let (code, fs) ← instCode inst
        params := params.push (.inst code)
        instFns := instFns ++ fs
        continue
      let d ← descOf ldecl.type
      let base := if ldecl.userName.hasMacroScopes then s!"arg{i}" else rustFieldName (componentString ldecl.userName.eraseMacroScopes)
      let base := if base == "_" || base == "_" ++ "_" then s!"arg{i}" else base
      let mut nm := base
      let mut k := 1
      while used.contains nm do
        nm := s!"{base}_{k}"; k := k + 1
      used := used.insert nm
      params := params.push (.value nm d)
    let result ← if est then descOf body.getAppArgs[2]! else descOf body
    return { params, result, est, io := errTy == some ``IO.Error, instFns }

/-! ## Public functions -/

structure PublicFn where
  lean : Name
  rust : String
  target : Name
  sig : PublicSig
  doc : String

partial def instExpr (decls : Std.HashMap Name Decl) : InstCode → String
  | .call c args =>
    match decls[c]? with
    | none => "rt::lean_internal_panic_unreachable()"
    | some d =>
    if isConst d then s!"\{ let i = {fnName c}(); rt::lean_inc(i); i }"
    else
      let vals := args.map fun a => match a with
        | none => "rt::lean_box(0)"
        | some code => instExpr decls code
      let binds := String.join (vals.toList.zipIdx.map fun (v, i) => s!"let i{i} = {v}; ")
      let call := s!"{fnName c}({", ".intercalate ((List.range vals.size).map (s!"i{·}")) })"
      let decs := String.join ((d.params.toList.zipIdx).filterMap fun (p, i) =>
        if p.borrow && !p.ty.isScalar then some s!" rt::lean_dec(i{i});" else none)
      "{ " ++ binds ++ s!"let r = {call};" ++ decs ++ " r }"

def emitPublic (types : Std.HashMap String TypeDef) (decls : Std.HashMap Name Decl) (facade : String)
    (f : PublicFn) : Except String String := do
  let some d := decls[f.target]? | throw s!"function was not collected: {f.target}"
  let ps := d.params
  let mut sigParams := #[]
  let mut stmts := #[]
  let mut args := #[]
  let mut decs := #[]
  for h : i in [0:f.sig.params.size] do
    let p := ps[i]!
    match f.sig.params[i] with
    | .world => pure ()
    | .erased => args := args.push "rt::lean_box(0)"
    | .inst code =>
      stmts := stmts.push s!"let __a{i}: Obj = {instExpr decls code};"
      args := args.push s!"__a{i}"
      if p.borrow then decs := decs.push s!"rt::lean_dec(__a{i});"
    | .value nm desc =>
      if desc == .prim "String" then
        sigParams := sigParams.push s!"{nm}: impl AsRef<str>"
        stmts := stmts.push s!"let __a{i}: Obj = rt::ToLean::to_lean({nm}.as_ref());"
      else
        sigParams := sigParams.push s!"{nm}: {desc.rustType}"
        stmts := stmts.push s!"let __a{i}: {rsType p.ty} = {toIR types desc p.ty nm};"
      args := args.push s!"__a{i}"
      if p.borrow && !p.ty.isScalar then decs := decs.push s!"rt::lean_dec(__a{i});"
  let resTy := f.sig.result.rustType
  let retTy := if f.sig.io then s!"std::io::Result<{resTy}>" else resTy
  let call := if isConst d then s!"{fnName f.target}()" else s!"{fnName f.target}({", ".intercalate args.toList})"
  let errorFn := fnName ``IO.Error.toString
  let errorCall := match decls[``IO.Error.toString]? with
    | some ed => if ed.params[0]!.borrow then s!"{errorFn}(__e)" else s!"\{ rt::lean_inc(__e); {errorFn}(__e) }"
    | none => "rt::lean_internal_panic_unreachable()"
  let body :=
    if f.sig.est then
      let value := fromObj f.sig.result "rt::lean_io_result_get_value(__r)"
      let res := if f.sig.io then
          s!"if rt::lean_io_result_is_ok(__r) \{ Ok({value}) } else \{ let __e = rt::lean_io_result_get_error(__r); Err(rt::io_error_to_std(__e, {errorCall})) }"
        else value
      s!"let __r: Obj = {call};\n        {String.join (decs.toList.map (· ++ " "))}let __v = {res};\n        rt::lean_dec(__r);\n        __v"
    else if d.resultType.isScalar then
      s!"let __r: {rsType d.resultType} = {call};\n        {String.join (decs.toList.map (· ++ " "))}{fromIR types f.sig.result d.resultType "__r"}"
    else if isConst d then
      s!"let __r: Obj = {call};\n        {fromObj f.sig.result "__r"}"
    else
      s!"let __r: Obj = {call};\n        {String.join (decs.toList.map (· ++ " "))}let __v = {fromObj f.sig.result "__r"};\n        rt::lean_dec(__r);\n        __v"
  let stmtStr := String.join (stmts.toList.map (s!"        " ++ · ++ "\n"))
  return s!"#[doc = {quoteString f.doc}]\n#[{facade}::exported({quoteString (toString f.lean)})]\npub fn {f.rust}({", ".intercalate sigParams.toList}) -> {retTy} \{\n    unsafe \{\n{stmtStr}        {body}\n    }\n}\n"

/-! ## Rust functions -/

/-- A Rust function of the crate named by `@[extern "rs:<path>(<modes>)"]`, with `->()` after the
    modes when it returns `()`. A mode is `_` (by value), `&` or `&mut` per argument; the values
    of the `&mut` arguments after the call follow the result, as in Aeneas's model. -/
structure RustCallee where
  path : String
  modes : Array String
  unitRet : Bool
  deriving Inhabited

def parseRustExtern (sym : String) : Except String RustCallee := do
  let cs := sym.toList.drop 3
  let (pathCs, rest) := cs.span (· != '(')
  let some (args, after) := (match rest with
      | '(' :: r => let (a, b) := r.span (· != ')'); some (a, b.drop 1)
      | _ => none) | throw s!"invalid Rust extern `{sym}`: expected `rs:<path>(<modes>)`"
  let modes := ((String.ofList args).splitOn ",").map (fun m => (String.ofList (m.toList.filter (!·.isWhitespace))))
    |>.filter (!·.isEmpty) |>.toArray
  for m in modes do
    unless m == "_" || m == "&" || m == "&mut" do throw s!"invalid mode `{m}` in the Rust extern `{sym}`"
  let after := String.ofList (after.filter (!·.isWhitespace))
  unless after.isEmpty || after == "->()" do throw s!"invalid Rust extern `{sym}`"
  return { path := String.ofList pathCs, modes, unitRet := after == "->()" }

/-- A Rust value from the Rust values `xs`: `()`, `x` or nested pairs `(a, (b, c))`. -/
def rustTuple : List String → String
  | [] => "()"
  | [a] => a
  | a :: rest => s!"({a}, {rustTuple rest})"

/-- A block calling the Rust function with the variables `args`, whose value is the result of
    the model (the result, then the `&mut` arguments). -/
def rustCall (c : RustCallee) (args : Array String) : String :=
  let actual := (args.zip c.modes).map fun (a, m) =>
    if m == "&" then s!"&{a}" else if m == "&mut" then s!"&mut {a}" else a
  let call := s!"{c.path}({", ".intercalate actual.toList})"
  let muts := (args.zip c.modes).filterMap fun (a, m) => if m == "&mut" then some a else none
  let value := rustTuple ((if c.unitRet then [] else ["__v"]) ++ muts.toList)
  if c.unitRet then s!"\{ {call}; {value} }" else s!"\{ let __v = {call}; {value} }"

/-- The function of an `rs:` extern: it converts the Lean arguments to Rust values, calls the
    Rust function and converts the result. A `Result` is `ok` of the value, or `fail panic`
    when the Rust function panics. -/
def emitRustExtern (types : Std.HashMap String TypeDef) (name : Name) (ps : Array Param) (ty : IRType)
    (sig : PublicSig) (c : RustCallee) : Except String String := do
  let mut stmts := #[]
  let mut args := #[]
  for h : i in [0:sig.params.size] do
    let p := ps[i]!
    match sig.params[i] with
    | .value nm d =>
      let m := c.modes[args.size]?.getD "_"
      let mutKw := if m == "&mut" then "mut " else ""
      stmts := stmts.push s!"let {mutKw}{nm}: {d.rustType} = {fromIR types d p.ty (varName p.x)};"
      if !p.borrow && !p.ty.isScalar then stmts := stmts.push s!"rt::lean_dec({varName p.x});"
      args := args.push nm
    | .erased => pure ()
    | _ => throw s!"{name}: the Rust extern takes an argument that is not a value"
  if args.size != c.modes.size then
    throw s!"{name}: the Rust function {c.path} takes {c.modes.size} arguments, the Lean function {args.size}"
  let call := rustCall c args
  let body := match sig.result with
    | .result inner =>
      s!"match ::std::panic::catch_unwind(::std::panic::AssertUnwindSafe(move || {call})) \{\n        Ok(__v) => __lr_result_ok({toObj inner "__v"}),\n        Err(_) => __lr_result_fail_panic(),\n    }"
    | d => s!"let __v = {call};\n    {toIR types d ty "__v"}"
  let stmtStr := String.join (stmts.toList.map (s!"    " ++ · ++ "\n"))
  return s!"#[allow(dead_code, non_snake_case, unused_mut, clippy::all)]\npub(crate) unsafe fn {fnName name}({paramList ps}) -> {rsType ty} \{\n{stmtStr}    {body}\n}\n"

/-- A public function whose `@[csimp]` replacement is a Rust function: it calls the Rust
    function with its Rust arguments. -/
def emitPublicRust (facade : String) (f : PublicFn) (c : RustCallee) : Except String String := do
  let vals := f.sig.params.filterMap fun | .value nm d => some (nm, d) | _ => none
  if vals.size != c.modes.size then
    throw s!"{f.lean}: the Rust function {c.path} takes {c.modes.size} arguments, the Lean function {vals.size}"
  let sigParams := vals.map fun (nm, d) => if d == .prim "String" then s!"{nm}: impl AsRef<str>" else s!"{nm}: {d.rustType}"
  let stmts := (vals.zip c.modes).filterMap fun ((nm, d), m) =>
    let mutKw := if m == "&mut" then "mut " else ""
    if d == .prim "String" then some s!"let {mutKw}{nm}: String = {nm}.as_ref().to_string();"
    else if m == "&mut" then some s!"let mut {nm} = {nm};" else none
  let stmtStr := String.join (stmts.toList.map (s!"    " ++ · ++ "\n"))
  return s!"#[doc = {quoteString f.doc}]\n#[{facade}::exported({quoteString (toString f.lean)})]\npub fn {f.rust}({", ".intercalate sigParams.toList}) -> {f.sig.result.rustType} \{\n{stmtStr}    {rustCall c (vals.map (·.1))}\n}\n"

/-- A call of the compiled function `d` with the values `vals` for its relevant parameters, an
    owned result. Owned values passed to a borrowed parameter are released after the call. -/
def helperCall (d : Decl) (vals : List String) : String := Id.run do
  let mut args := #[]
  let mut binds := ""
  let mut decs := ""
  let mut rest := vals
  let mut k := 0
  for p in d.params do
    if p.ty.isVoid then continue
    if p.ty.isErased then args := args.push "rt::lean_box(0)"; continue
    binds := binds ++ s!"let __h{k} = {rest.headD "rt::lean_box(0)"}; "
    rest := rest.tail
    args := args.push s!"__h{k}"
    if p.borrow && !p.ty.isScalar then decs := decs ++ s!" rt::lean_dec(__h{k});"
    k := k + 1
  return "{ " ++ binds ++ s!"let __r = {fnName d.name}({", ".intercalate args.toList});" ++ decs ++ " __r }"

def resultOk : Name := `Aeneas.Std.Result.ok
def resultMatch : Name := `Aeneas.Std.Result.match
def resultFail : Name := `Aeneas.Std.Result.fail

/-- `__lr_result_ok`, `__lr_result_match` and `__lr_result_fail_panic`: Aeneas's `Result` from
    and to Rust. -/
def emitResultHelpers (decls : Std.HashMap Name Decl) : String := Id.run do
  let (some ok, some mt, some fl) := (decls[resultOk]?, decls[resultMatch]?, decls[resultFail]?) | return ""
  let allow := "#[allow(dead_code, non_snake_case, clippy::all)]\n"
  return allow ++ s!"unsafe fn __lr_result_ok(v: Obj) -> Obj \{\n    {helperCall ok ["v"]}\n}\n" ++
    allow ++ s!"unsafe fn __lr_result_match(r: Obj) -> Obj \{\n    rt::lean_inc(r);\n    {helperCall mt ["r"]}\n}\n" ++
    allow ++ s!"unsafe fn __lr_result_fail_panic() -> Obj \{\n    {helperCall fl ["5u8"]}\n}\n"

/-! ## Generation -/

structure Skipped where
  name : Name
  reason : String

structure GenResult where
  items : String
  externs : Array String
  decls : Array Decl
  publics : Array (Name × String)
  skipped : Array Skipped

def typeUsesProof (types : Std.HashMap String TypeDef) (d : Desc) : Option String := Id.run do
  let mut seen : Std.HashSet String := {}
  let mut stack := d.named?
  while !stack.isEmpty do
    let r := stack.back!
    stack := stack.pop
    if seen.contains r then continue
    seen := seen.insert r
    let some td := types[r]? | continue
    if td.hasProof then return some td.lean
    match td.kind with
    | .struct v => for f in v.fields do stack := stack ++ f.desc.named?
    | .newtype _ inner => stack := stack ++ inner.named?
    | .sum vs => for v in vs do for f in v.fields do stack := stack ++ f.desc.named?
    | .enum _ => pure ()
  return none

/-- Generates the module for `roots`: the internal functions they need, the generated types
    and a public function per root that can be marshalled (the others are `skipped`). A root
    replaced by a `@[csimp]` lemma also has its own definition as a public function of the
    module `__lean_rust_spec`, which re-exports the other public functions. `modelNs` is the
    namespace of the crate's Aeneas model, whose types are the crate's Rust types. -/
def generate (roots : Array Name) (strip : Name) (typePaths : Array (Name × String)) (facade : String) (internalOnly : Bool)
    (modelNs : Option Name := none) :
    MetaM (Except String GenResult) := do
  let env ← getEnv
  if internalOnly then
    return (generateInternal env roots).map fun o =>
      { items := o.items, externs := o.externs, decls := o.decls, publics := #[], skipped := #[] }
  let cfg : MarshalConfig := { strip, typePaths, modelNs }
  let ((fns, copies), st) ← (do
      let mut fns : Array (Except Skipped PublicFn) := #[]
      let mut copies : Array PublicFn := #[]
      for r in roots do
        let t := csimpTarget env r
        let some d := findEnvDecl env t
          | fns := fns.push (.error { name := r, reason := "no IR (is it noncomputable?)" }); continue
        let saved ← get
        try
          let sig ← publicSig r d.params
          let some ci := env.find? r | throwError "unknown constant"
          let doc := s!"Lean: `{r} : {← ppExpr ci.type}` (module `{moduleOf env r}`)."
          let f : PublicFn := { lean := r, rust := rustFnName strip r, target := t, sig, doc }
          fns := fns.push (.ok f)
          if t != r then
            if let some rd := findEnvDecl env r then
              copies := copies.push { f with target := r, sig := ← publicSig r rd.params }
        catch e =>
          set saved
          fns := fns.push (.error { name := r, reason := ← e.toMessageData.toString })
      return (fns, copies) : MarshalM _).run cfg |>.run {}
  let types0 : Std.HashMap String TypeDef := st.types.foldl (fun m td => m.insert td.rust td) {}
  let mut publics : Array PublicFn := #[]
  let mut skipped : Array Skipped := #[]
  for f in fns do
    match f with
    | .error s => skipped := skipped.push s
    | .ok f =>
      let argProof := f.sig.params.findSome? fun
        | .value _ d => typeUsesProof types0 d
        | _ => none
      match argProof with
      | some l => skipped := skipped.push { name := f.lean, reason := s!"argument type `{l}` has proof fields" }
      | none => publics := publics.push f
  let copies := copies.filter fun c => publics.any (·.lean == c.lean)
  let mut names : Std.HashMap String Name := {}
  for f in publics do
    if let some o := names[f.rust]? then
      return .error s!"Rust name `{f.rust}` is used by both {o} and {f.lean}"
    names := names.insert f.rust f.lean
  let aeneas := if env.contains resultOk then #[resultOk, resultMatch, resultFail] else #[]
  let extra := publics.foldl (fun acc f => acc ++ f.sig.instFns) #[] ++
    (if publics.any (·.sig.io) then #[``IO.Error.toString] else #[]) ++ aeneas
  match generateInternal env (publics.map (·.lean) ++ extra) with
  | .error e => return .error e
  | .ok o =>
    let declMap := o.decls.foldl (fun m d => m.insert d.name d) ({} : Std.HashMap Name Decl)
    let mut rustFns : Array (Name × Array Param × IRType × RustCallee) := #[]
    for d in o.decls do
      if let .extern f ps ty _ := d then
        if let some sym := externSymbol env f then
          if isRustExtern sym then
            match parseRustExtern sym with
            | .ok c => rustFns := rustFns.push (f, ps, ty, c)
            | .error e => return .error e
    let (rustSigs, st) ← (do
        let mut out := #[]
        for (f, ps, _, _) in rustFns do
          try out := out.push (← publicSig f ps)
          catch e => throwError "the Rust extern {f}: {e.toMessageData}"
        return out : MarshalM _).run cfg |>.run st
    let types : Std.HashMap String TypeDef := st.types.foldl (fun m td => m.insert td.rust td) {}
    let callees : Std.HashMap Name RustCallee := rustFns.foldl (fun m (f, _, _, c) => m.insert f c) {}
    let mut items := o.items ++ emitResultHelpers declMap ++ "\n"
    for h : i in [0:rustFns.size] do
      let (f, ps, ty, c) := rustFns[i]
      match emitRustExtern types f ps ty rustSigs[i]! c with
      | .ok s => items := items ++ s ++ "\n"
      | .error e => return .error e
    for td in st.types do
      unless td.external do items := items ++ emitTypeDef types td ++ "\n"
    for f in publics do
      let res := match callees[f.target]? with
        | some c => emitPublicRust facade f c
        | none => emitPublic types declMap facade f
      match res with
      | .ok s => items := items ++ s ++ "\n"
      | .error e => return .error e
    let mut specMod := "#[doc(hidden)]\n#[allow(unused_imports)]\npub mod __lean_rust_spec {\n    pub use super::*;\n"
    for f in copies do
      match emitPublic types declMap facade f with
      | .ok s => specMod := specMod ++ s
      | .error e => return .error e
    items := items ++ specMod ++ "}\n"
    return .ok { items, externs := o.externs, decls := o.decls,
                 publics := publics.map fun f => (f.lean, f.rust), skipped }

end LeanRust
