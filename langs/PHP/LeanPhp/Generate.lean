import LeanPhp.Marshal

open Lean Meta

namespace LeanPhp

inductive FacadeKind where
  | cls | trait
  deriving BEq

def FacadeKind.parse (value : String) : Except String FacadeKind :=
  match value with
  | "class" => .ok .cls
  | "trait" => .ok .trait
  | _ => .error s!"facade kind must be class or trait: {value}"

def FacadeKind.declaration : FacadeKind → String
  | .cls => "final class"
  | .trait => "trait"

structure Skipped where
  name : Name
  reason : String

structure PublicFn where
  lean : Name
  target : IR.Decl
  method : String
  sig : PublicSig

structure Collected where
  state : MarshalState
  functions : Array PublicFn
  skipped : Array Skipped

def collectPublic (types roots : Array Name) (facade : String) : MarshalM Collected := do
  let env ← getEnv
  let cfg ← read
  discard <| freshIdent facade
  let mut skipped := #[]
  let mut functions := #[]
  let mut methods : NameClaims := {}
  let mut seen : Std.HashSet Name := {}
  for ty in types do
    let saved ← get
    let savedEnv ← getEnv
    try
      if isPrivateName ty then throwError "private type `{ty}`"
      let e ← mkConstWithLevelParams ty
      discard <| descOf e
    catch e =>
      setEnv savedEnv
      set saved
      skipped := skipped.push { name := ty, reason := ← e.toMessageData.toString }
  for r in roots do
    if seen.contains r then continue
    seen := seen.insert r
    let saved ← get
    let savedEnv ← getEnv
    try
      if isPrivateName r then throwError "private definition `{r}`"
      let some target := IR.findEnvDecl env (csimpTarget env r) | throwError "no IR"
      let sig ← publicSig r target.params
      let (method, claims) ← ofExcept (methods.claim (publicMethod cfg.strip r))
      methods := claims
      functions := functions.push { lean := r, target, method, sig }
    catch e =>
      setEnv savedEnv
      set saved
      skipped := skipped.push { name := r, reason := ← e.toMessageData.toString }
  return { state := ← get, functions, skipped }

def inspectPublic (env : Environment) (cfg : MarshalCfg) (types roots : Array Name) (facade : String) :
    IO (Collected × Environment) := do
  let ctx : Core.Context := { fileName := "<leanfran --lang php>", fileMap := default, maxHeartbeats := 0 }
  let state : MarshalState := { foreignTypes := (cfg.shared.getD {}).defs }
  let ((r, _), st) ← ((((collectPublic types roots facade).run state).run cfg).run').toIO ctx { env }
  return (r, st.env)

private def qualifyDesc (ns : String) : Desc → Desc
  | .named ident => .foreign ns ident
  | .list d => .list (qualifyDesc ns d)
  | .array d => .array (qualifyDesc ns d)
  | .option d => .option (qualifyDesc ns d)
  | .prod a b => .prod (qualifyDesc ns a) (qualifyDesc ns b)
  | .except e a => .except (qualifyDesc ns e) (qualifyDesc ns a)
  | d => d

def shareTypes (ns : String) (state : MarshalState) (shared : SharedTypes) : SharedTypes := Id.run do
  let defs := state.types.foldl (fun defs t =>
    let kind := match t.kind with
      | .struct v trivial =>
        .struct { v with fields := v.fields.map fun f => { f with desc := qualifyDesc ns f.desc } } trivial
      | .subtype base inv bounds => .subtype (qualifyDesc ns base) inv bounds
      | kind => kind
    defs.insert (ns, t.ident) { t with kind }) state.foreignTypes
  let mut names := shared.names
  for (ty, desc) in state.byType.toArray do
    if let .named ident := desc then
      if let some t := defs[(ns, ident)]? then
        if !t.anonymous && t.model.isNone then
          names := names.insert ty (ns, ident)
  return { names, defs }

def runtime (name : String) : String := "\\Conao3\\Leanfran\\" ++ name
def descClass : String := runtime "Schema\\Desc"
def marshalClass : String := runtime "Marshal"

structure RenderCfg where
  ns : String
  internal : String
  state : MarshalState
  methods : Std.HashMap Name String
  env : Environment

def RenderCfg.qualified (c : RenderCfg) (name : String) : String := s!"\\{c.ns}\\{name}"

def RenderCfg.target (c : RenderCfg) (name : Name) : String :=
  c.internal ++ "::" ++ c.methods[name]!

def descNew (kind : String) (args : Array String := #[]) : String :=
  s!"new {descClass}({joinArgs (#[quoteBytes kind] ++ args)})"

def descMethod (ident : String) : String := s!"desc_{ident}"

def refDesc (expr : String) : String :=
  descNew "ref" #[s!"get: static fn (): {descClass} => {expr}"]

partial def Desc.code (c : RenderCfg) (modelField := false) : Desc → String
  | .nat => descNew "nat" (if modelField then #["phpInt: true"] else #[])
  | .int => descNew "int" (if modelField then #["phpInt: true"] else #[])
  | .bool => descNew "bool"
  | .char => descNew "char"
  | .string => descNew "string"
  | .float => descNew "float"
  | .float32 => descNew "float32"
  | .unit => descNew "unit"
  | .uint bits => descNew "uint" #[s!"bits: {bits}"]
  | .sint bits => descNew "sint" #[s!"bits: {bits}"]
  | .usize => descNew "usize" #["bits: 64"]
  | .isize => descNew "isize" #["bits: 64"]
  | .fin n => descNew "fin" #[s!"bound: {quoteBytes (toString n)}"]
  | .list d => descNew "list" #[s!"a: {d.code c modelField}"]
  | .array d => descNew "array" #[s!"a: {d.code c modelField}"]
  | .option d => descNew "option" #[s!"a: {d.code c modelField}"]
  | .prod a b => descNew "prod" #[s!"a: {a.code c modelField}", s!"b: {b.code c modelField}"]
  | .except a b => descNew "except" #[s!"a: {a.code c modelField}", s!"b: {b.code c modelField}"]
  | .named ident => refDesc s!"{c.internal}::{descMethod ident}()"
  | .foreign ns ident => refDesc s!"(\\{ns}\\{ident}::DESC)()"

def TypeDef.base? (t : TypeDef) : Option Desc :=
  match t.kind with
  | .subtype base .. => if t.anonymous then some base else none
  | _ => none

def RenderCfg.findType (c : RenderCfg) (ident : String) : TypeDef :=
  (c.state.types.find? (·.ident == ident)).get!

partial def Desc.phpType (c : RenderCfg) (ctor : Bool := false) : Desc → String
  | .nat | .int | .uint 64 | .usize => if ctor then "int|\\GMP|string" else "int|\\GMP"
  | .uint _ | .sint _ | .isize => "int"
  | .fin n => if n ≤ 2 ^ 63 then "int" else "int|\\GMP"
  | .bool => "bool"
  | .char | .string => "string"
  | .float | .float32 => "float"
  | .unit => "null"
  | .array _ | .list _ | .prod .. => "array"
  | .except .. => runtime "Except"
  | .option d => d.phpType c ctor ++ "|null"
  | .named ident =>
    let t := c.findType ident
    match t.model, t.base? with
    | some cls, _ => "\\" ++ cls
    | none, some d => d.phpType c ctor
    | none, none => c.qualified ident
  | .foreign ns ident =>
    match c.state.foreignTypes[(ns, ident)]? with
    | some { anonymous := true, kind := .subtype base .., .. } => base.phpType c ctor
    | some { model := some cls, .. } => "\\" ++ cls
    | _ => s!"\\{ns}\\{ident}"

def boundValue (bounds : Array (String × Int)) (keys : List (String × Int)) (combine : Int → Int → Int)
    (base : Option Int) : Option Int := Id.run do
  let mut res := base
  for (k, x) in bounds do
    if let some (_, offset) := keys.find? (·.1 == k) then
      res := some (res.map (combine (x + offset)) |>.getD (x + offset))
  return res

def intDoc (bounds : Array (String × Int)) (lo hi : Option Int) : String :=
  let lo := boundValue bounds [("minimum", 0), ("exclusiveMinimum", 1)] max lo
  let hi := boundValue bounds [("maximum", 0), ("exclusiveMaximum", -1)] min hi
  let lo := lo.map (max (-(2 ^ 63)))
  let hi := hi.map (min (2 ^ 63 - 1))
  if lo.isNone && hi.isNone then "int"
  else if lo.any (fun n => n > 2 ^ 63 - 1) || hi.any (fun n => n < -(2 ^ 63)) then "never"
  else s!"int<{(lo.map toString).getD "min"}, {(hi.map toString).getD "max"}>"

def wideDoc (bounds : Array (String × Int)) (lo hi : Option Int) (ctor : Bool) : String :=
  let doc := intDoc bounds lo hi
  (if doc == "never" then "\\GMP" else doc ++ "|\\GMP") ++ (if ctor then "|string" else "")

partial def Desc.phpDoc (c : RenderCfg) (ctor : Bool := false) (bs : Array (String × Int) := #[]) : Desc → String
  | .nat => wideDoc bs (some 0) none ctor
  | .int => wideDoc bs none none ctor
  | .uint 64 | .usize => wideDoc bs (some 0) none ctor
  | .uint b => intDoc bs (some 0) (some (2 ^ b - 1))
  | .sint b => intDoc bs (some (-(2 ^ (b - 1)))) (some (2 ^ (b - 1) - 1))
  | .isize => intDoc bs (some (-(2 ^ 63))) (some (2 ^ 63 - 1))
  | .fin n =>
    if n ≤ 2 ^ 63 then intDoc bs (some 0) (some (max 0 (Int.ofNat n - 1)))
    else wideDoc bs (some 0) (some (Int.ofNat n - 1)) false
  | .string =>
    if (boundValue bs [("minLength", 0)] max none).any (· ≥ 1) then "non-empty-string" else "string"
  | .array d | .list d =>
    let base := if (boundValue bs [("minItems", 0)] max none).any (· ≥ 1) then "non-empty-list" else "list"
    s!"{base}<{d.phpDoc c ctor}>"
  | .option d => d.phpDoc c ctor bs ++ "|null"
  | .prod a b => s!"array\{0: {a.phpDoc c ctor}, 1: {b.phpDoc c ctor}}"
  | .except e a => s!"{runtime "Except"}<{e.phpDoc c ctor}, {a.phpDoc c ctor}>"
  | .named ident =>
    match c.findType ident with
    | { anonymous := true, kind := .subtype base _ bounds, .. } => base.phpDoc c ctor (bs ++ bounds)
    | _ => (Desc.named ident).phpType c ctor
  | .foreign ns ident =>
    match c.state.foreignTypes[(ns, ident)]? with
    | some { anonymous := true, kind := .subtype base _ bounds, .. } => base.phpDoc c ctor (bs ++ bounds)
    | _ => (Desc.foreign ns ident).phpType c ctor
  | d => d.phpType c ctor

def docLines (lines : Array String) : String :=
  if lines.isEmpty then ""
  else if lines.size == 1 then s!"    /** {lines[0]!} */\n"
  else "    /**\n" ++ String.join (lines.toList.map (s!"     * {·}\n")) ++ "     */\n"

def docText (s : String) : String :=
  s.replace "*/" "* /" |>.replace "\r" " " |>.replace "\n" " " |>.replace "?>" "? >"

def phpArray (items : Array String) : String := s!"[{joinArgs items}]"

def assoc (fields : Array (String × String)) : String :=
  phpArray (fields.map fun (key, v) => s!"{quoteBytes key} => {v}")

def boundsCode (bs : Array (String × Int)) : String :=
  let bounds := bs.foldl (fun (out : Array (String × Int)) (k, v) =>
    match out.findIdx? (·.1 == k) with
    | some i => out.modify i fun (_, old) => (k, if k.toLower.endsWith "maximum" || k.startsWith "max" then min old v else max old v)
    | none => out.push (k, v)) #[]
  assoc (bounds.map fun (k, v) => (k, quoteBytes (toString v)))

def fieldCode (c : RenderCfg) (modelField : Bool) (f : FieldInfo) : String :=
  assoc #[("key", quoteBytes f.key), ("prop", quoteBytes f.property), ("desc", f.desc.code c modelField),
    ("slot", quoteBytes f.slot), ("at", toString f.pos), ("omitNone", toString f.omitNone),
    ("flat", toString f.flat), ("bounds", boundsCode f.bounds)]

def asScalar (ty : IR.IRType) (expr : String) : String :=
  match phpType ty with
  | "int" => s!"{runtime "Runtime\\requireRuntimeInt"}({expr})"
  | "float" => s!"{runtime "Runtime\\requireRuntimeFloat"}({expr})"
  | _ => expr

def invariantCode (c : RenderCfg) (inv : InvInfo) : String := Id.run do
  let decl := (IR.findEnvDecl c.env inv.decider).get!
  let args := decl.params.mapIdx (fun i p => (i, p)) |>.filter (liveParam ∘ Prod.snd)
  let args := args.map fun (i, p) =>
    let v := s!"$args[{i}]"
    if !p.borrow && p.ty.isPossibleRef then s!"{runtime "Runtime\\lean_inc_ret"}({v})" else asScalar p.ty v
  let dec := s!"static fn (mixed ...$args): bool => {c.target inv.decider}({joinArgs args}) !== 0"
  return assoc #[("field", quoteBytes inv.field), ("prop", quoteBytes inv.prop),
    ("args", phpArray (inv.args.map toString)), ("decide", dec)]

def variantCode (c : RenderCfg) (v : VariantInfo) (cls : String) (model : Bool := false) : String :=
  assoc #[("name", quoteBytes v.name), ("cls", cls), ("tag", toString v.cidx),
    ("size", toString v.size), ("usize", toString v.usize), ("ssize", toString v.ssize),
    ("positional", toString v.positional), ("fields", phpArray (v.fields.map (fieldCode c model))),
    ("invariants", phpArray (v.invariants.map (invariantCode c)))]

def subtypeVariant (base : Desc) (inv : InvInfo) (bounds : Array (String × Int)) : VariantInfo :=
  { name := "mk", ident := "", cidx := 0, size := 0, usize := 0, ssize := 0, positional := false,
    fields := #[{ key := "val", property := "val", slot := "none", pos := 0, desc := base, bounds }],
    invariants := #[inv] }

def descriptorCode (c : RenderCfg) (t : TypeDef) : String :=
  let cls := (t.model.map ("\\" ++ ·) |>.getD (c.qualified t.ident)) ++ "::class"
  let name := if t.anonymous then "Subtype" else t.model.getD t.ident
  let args := #[s!"name: {quoteBytes name}"]
  match t.kind with
  | .enum tags =>
    let args := args ++ #[s!"cls: {cls}", s!"cases: {phpArray (tags.map quoteBytes)}"]
    descNew "enum" (if t.model.isSome then args.push "enumByName: true" else args)
  | .struct v trivial =>
    descNew (if t.model.isSome then "model" else "struct")
      (args ++ #[s!"cls: {cls}", s!"variants: [{variantCode c v cls t.model.isSome}]",
      s!"trivial: {(trivial.map toString).getD "null"}"])
  | .sum vs trivial =>
    let variants := vs.map fun v => variantCode c v (c.qualified v.ident ++ "::class")
    descNew "inductive" (args ++ #[s!"cls: {cls}", s!"variants: {phpArray variants}",
      s!"trivial: {(trivial.map toString).getD "null"}"])
  | .subtype base inv bounds =>
    let v := variantCode c (subtypeVariant base inv bounds) (if t.anonymous then "null" else cls)
    descNew "subtype" (args ++ #[s!"cls: {if t.anonymous then "null" else cls}", s!"a: {base.code c}",
      s!"variants: [{v}]", "trivial: 0", s!"bounds: {boundsCode bounds}"])

def emitDescriptor (c : RenderCfg) (t : TypeDef) : String :=
  s!"\n    public static function {descMethod t.ident}(): {descClass}\n    \{\n        static $desc;\n        return $desc ??= {descriptorCode c t};\n    }\n"

partial def flattenFields (c : RenderCfg) (fields : Array FieldInfo) : Except String (Array FieldInfo) :=
  fields.flatMapM fun f => do
    if !f.flat then return #[f]
    let parent ← match f.desc with
      | .named n => pure (c.findType n)
      | .foreign ns n => do
        let some t := c.state.foreignTypes[(ns, n)]? | throw "Missing foreign parent layout."
        pure t
      | _ => throw "Missing structure parent layout."
    let .struct v _ := parent.kind | throw "Expected a structure parent."
    flattenFields c v.fields

def valueMethods (c : RenderCfg) (ident : String) : String :=
  s!"    public static function desc(): {descClass}\n    \{\n        return {c.internal}::{descMethod ident}();\n    }\n\n" ++
  s!"    public static function fromArray(mixed $data): static\n    \{\n        return {marshalClass}::fromData(self::desc(), self::class, $data);\n    }\n\n" ++
  s!"    public static function fromJson(string $json): static\n    \{\n        return {marshalClass}::fromData(self::desc(), self::class, $json, true);\n    }\n\n" ++
  s!"    /** @return array<mixed> */\n    public function toArray(): array\n    \{\n        return {marshalClass}::toArray(self::desc(), $this);\n    }\n\n" ++
  s!"    public function toJson(): string\n    \{\n        return {runtime "Json"}::encode({marshalClass}::jsonValue(self::desc(), $this));\n    }\n\n" ++
  s!"    /** @return array<string, mixed> */\n    public static function jsonSchema(string $target = 'draft-2020-12'): array\n    \{\n        return {runtime "Schema\\JsonSchema"}::of(self::desc(), $target);\n    }\n\n" ++
  s!"    public function jsonSerialize(): mixed\n    \{\n        return {runtime "Json"}::native({marshalClass}::jsonValue(self::desc(), $this));\n    }\n"

def constructMethod (cls : String) : String := "construct_" ++ cls

def emitConstruct (c : RenderCfg) (ident cls : String) (fields : Array FieldInfo) : String :=
  if fields.isEmpty then ""
  else
    let shape := joinArgs (fields.map fun f => s!"{quoteBytes f.property}: {f.desc.phpDoc c false f.bounds}")
    let docs := docLines #["@param array<string, mixed> $values", s!"@return array\{{shape}}"]
    s!"\n{docs}    public static function {constructMethod cls}(array $values): array\n    \{\n" ++
    s!"        return {marshalClass}::construct(self::{descMethod ident}(), {c.qualified cls}::class, $values);\n    }\n"

def classBody (c : RenderCfg) (ident cls : String) (fields : Array FieldInfo) : String := Id.run do
  let properties := fields.map fun f =>
    let type := f.desc.phpType c
    let doc := f.desc.phpDoc c false f.bounds
    (if type == doc then "" else docLines #[s!"@var {doc}"]) ++ s!"    public {type} ${f.property};\n"
  let params := fields.map fun f => s!"{f.desc.phpType c true} ${f.property}"
  let docs := fields.filterMap fun f =>
    let doc := f.desc.phpDoc c true f.bounds
    if doc == f.desc.phpType c true then none else some s!"@param {doc} ${f.property}"
  let args := assoc (fields.map fun f => (f.property, "$" ++ f.property))
  let valueVar := "$__leanFields"
  let body :=
    if fields.isEmpty then s!"        {marshalClass}::construct(self::desc(), self::class, []);\n"
    else s!"        {valueVar} = {c.internal}::{constructMethod cls}({args});\n" ++
      String.join (fields.toList.map fun f => s!"        $this->{f.property} = {valueVar}[{quoteBytes f.property}];\n")
  return String.join properties.toList ++
    (if properties.isEmpty then "" else "\n") ++ docLines docs ++
    s!"    public function __construct({joinArgs params})\n    \{\n{body}    }\n\n" ++
    valueMethods c ident

def descConstant (c : RenderCfg) (ident : String) : String :=
  s!"    public const DESC = [{c.internal}::class, {quoteBytes (descMethod ident)}];\n"

def emitType (c : RenderCfg) (t : TypeDef) : Except String (Array (String × String) × String) := do
  if t.model.isSome then return (#[], "")
  let doc := s!"/** Lean `{docText t.pretty}`. */\n"
  let mkCls (name implement body : String) := (name ++ ".php",
    doc ++ s!"final readonly class {name} implements {implement}\n\{\n{body}}\n")
  match t.kind with
  | .struct v _ =>
    let fields ← flattenFields c v.fields
    let names := fields.map (·.property)
    unless names.toList.Nodup do throw (collisionLabel ++ t.ident)
    let cls := mkCls t.ident "\\JsonSerializable" (descConstant c t.ident ++ "\n" ++ classBody c t.ident t.ident fields)
    return (#[cls], emitConstruct c t.ident t.ident fields)
  | .subtype base inv bounds =>
    if t.anonymous then return (#[], "")
    let fields := (subtypeVariant base inv bounds).fields
    let cls := mkCls t.ident "\\JsonSerializable" (descConstant c t.ident ++ "\n" ++ classBody c t.ident t.ident fields)
    return (#[cls], emitConstruct c t.ident t.ident fields)
  | .enum cases =>
    let (_, seed) ← NameClaims.claim {} "DESC"
    let mut used := seed
    let mut items := ""
    for tag in cases do
      let (name, claims) ← used.claim (phpIdent (sanitize tag).capitalize)
      used := claims
      items := items ++ s!"    case {name} = {quoteBytes tag};\n"
    let body := descConstant c t.ident ++ "\n" ++ items ++ "\n" ++ valueMethods c t.ident
    return (#[(t.ident ++ ".php", doc ++ s!"enum {t.ident}: string implements \\JsonSerializable\n\{\n{body}}\n")], "")
  | .sum vs _ =>
    let base := doc ++ s!"interface {t.ident} extends \\JsonSerializable\n\{\n" ++ descConstant c t.ident ++
      s!"\n    public static function desc(): {descClass};\n\n    public static function fromArray(mixed $data): static;\n\n    public static function fromJson(string $json): static;\n\n    /** @return array<mixed> */\n    public function toArray(): array;\n\n    public function toJson(): string;\n\n    /** @return array<string, mixed> */\n    public static function jsonSchema(string $target = 'draft-2020-12'): array;\n}\n"
    let classes := vs.map (fun v => mkCls v.ident t.ident (classBody c t.ident v.ident v.fields))
    let constructors := String.join (vs.toList.map fun v => emitConstruct c t.ident v.ident v.fields)
    return (#[(t.ident ++ ".php", base)] ++ classes, constructors)

def resultMethod (f : PublicFn) : String := "result_" ++ f.method

def emitResult (c : RenderCfg) (f : PublicFn) : String :=
  let result := f.sig.result.phpType c
  let retDoc := f.sig.result.phpDoc c
  let doc := if retDoc == result then "" else docLines #[s!"@return {retDoc}"]
  let convert := if f.sig.io then "ioResult" else "fromLean"
  s!"\n{doc}    public static function {resultMethod f}(mixed $value): {result}\n    \{\n" ++
  s!"        return {marshalClass}::{convert}({f.sig.result.code c}, $value);\n    }\n"

def emitPublicFn (c : RenderCfg) (f : PublicFn) : String := Id.run do
  let mut docs := #[s!"Lean `{docText f.lean.toString} : {docText f.sig.type}`."]
  let mut params := #[]
  let mut inputs := #[]
  let mut args := #[]
  for h : i in [0:f.sig.params.size] do
    let p := f.target.params[i]!
    match f.sig.params[i] with
    | .world =>
      if liveParam p then args := args.push "0"
    | .value nm d =>
      let type := d.phpType c
      let doc := d.phpDoc c
      if type != doc then docs := docs.push s!"@param {doc} ${nm}"
      params := params.push s!"{type} ${nm}"
      if liveParam p then args := args.push (asScalar p.ty s!"$__leanArgs[{inputs.size}]")
      inputs := inputs.push (phpArray #[d.code c, "$" ++ nm, quoteBytes nm])
  let result := f.sig.result.phpType c
  let retDoc := f.sig.result.phpDoc c
  if retDoc != result then docs := docs.push s!"@return {retDoc}"
  let call := s!"{c.target f.target.name}({joinArgs args})"
  let prologue := if inputs.isEmpty then "" else
    s!"        $__leanArgs = {marshalClass}::arguments({phpArray inputs});\n"
  return docLines docs ++
    s!"    public static function {f.method}({joinArgs params}): {result}\n    \{\n{prologue}        return {c.internal}::{resultMethod f}({call});\n    }\n"

end LeanPhp
