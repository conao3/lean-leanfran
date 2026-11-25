import LeanGo.Marshal

open Lean Meta Lean.IR

namespace LeanGo

structure Skipped where
  name : Name
  reason : String

structure PublicFn where
  source : Name
  target : IR.Decl
  ident : String
  sig : PublicSig

structure ValueConversion where
  desc : Desc
  stem : String

def ValueConversion.newIdent (c : ValueConversion) : String := "New" ++ c.stem

def ValueConversion.readIdent (c : ValueConversion) : String := "Read" ++ c.stem

structure PublicModule where
  state : MarshalState
  functions : Array PublicFn
  skipped : Array Skipped
  handles : Array PublicFn
  conversions : Array ValueConversion

def isNameCollision (reason : String) : Bool := reason.startsWith collisionLabel

partial def Desc.valueStem : Desc → String
  | .nat => "Nat"
  | .int => "Int"
  | .bool => "Bool"
  | .char => "Char"
  | .string => "String"
  | .float => "Float"
  | .float32 => "Float32"
  | .unit => "Unit"
  | .bytes => "ByteArray"
  | .uint b => s!"UInt{b}"
  | .sint b => s!"Int{b}"
  | .hostInt signed => if signed then "GoInt" else "GoUint"
  | .usize => "USize"
  | .isize => "ISize"
  | .fin n => s!"Fin{n}"
  | .list d => "List" ++ d.valueStem
  | .array d => "Array" ++ d.valueStem
  | .option d => "Option" ++ d.valueStem
  | .prod a b => "Pair" ++ a.valueStem ++ b.valueStem
  | .except e a => "Except" ++ e.valueStem ++ a.valueStem
  | .foreign _ n | .named n | .opaque n => n

partial def Desc.valueDependencies (d : Desc) : List Desc :=
  let children := match d with
    | .list a | .array a | .option a => a.valueDependencies
    | .prod a b | .except a b => a.valueDependencies ++ b.valueDependencies
    | _ => []
  if d.convertible then children ++ [d] else children

def PublicSig.valueInputs (sig : PublicSig) : List Desc :=
  sig.result.valueDependencies ++ (sig.params.toList.flatMap fun
    | .value _ d => d.valueDependencies
    | .world => [])

def collectPublic (types roots : Array Name) : MarshalM PublicModule := do
  let env ← getEnv
  let cfg ← read
  let mut skipped := #[]
  let mut functions := #[]
  for ty in types do
    let saved ← get
    let savedEnv ← getEnv
    try
      discard <| descOf (← mkConstWithLevelParams ty)
    catch e =>
      let reason ← e.toMessageData.toString
      if isNameCollision reason then throw e
      setEnv savedEnv
      set saved
      skipped := skipped.push { name := ty, reason }
  for r in roots do
    let saved ← get
    let savedEnv ← getEnv
    try
      if isPrivateName r then throwError "private definition `{r}`"
      let some target := IR.findEnvDecl env (csimpTarget env r) | throwError "no IR"
      let sig ← publicSig r target.params
      let ident ← freshIdent (publicMethod cfg.strip r)
      functions := functions.push { source := r, target, ident, sig }
    catch e =>
      let reason ← e.toMessageData.toString
      if isNameCollision reason then throw e
      setEnv savedEnv
      set saved
      skipped := skipped.push { name := r, reason }
  let mut handles := #[]
  let mut handleNames : NameClaims := {}
  for r in roots do
    let saved ← get
    let savedEnv ← getEnv
    try
      if isPrivateName r then continue
      let some target := IR.findEnvDecl env (csimpTarget env r) | continue
      let previous := functions.find? (·.source == r)
      let sig ← match previous with
        | some f => pure f.sig
        | none =>
          let sig ← publicSig r target.params handleDescOf
          let exports := exportedFns env
          discard <| ofExcept (collect env exports #[target.name] >>= checkExterns env exports)
          pure sig
      let base := reserveNames ["In"] (publicMethod cfg.strip r)
      let (ident, claims) := handleNames.claim base
      handleNames := claims
      handles := handles.push { source := r, target, ident, sig }
    catch e =>
      if isNameCollision (← e.toMessageData.toString) then throw e
      setEnv savedEnv
      set saved
  let types := (← get).types.toList.filter (fun t => !t.anonymous && t.model.isNone)
  let inputs := types.map (fun t => Desc.named t.ident) ++ handles.toList.flatMap (·.sig.valueInputs)
  let mut conversions : Array ValueConversion := #[]
  let mut conversionNames : NameClaims := {}
  for desc in inputs.eraseDups do
    let (stem, claims) := conversionNames.claim desc.valueStem
    conversionNames := claims
    conversions := conversions.push { desc, stem }
  return { state := ← get, functions, skipped, handles, conversions }

def inspectPublic (env : Environment) (cfg : MarshalCfg) (types roots : Array Name) :
    IO (PublicModule × Environment) := do
  let ctx : Core.Context := { fileName := "<leanfran-go>", fileMap := default, maxHeartbeats := 0 }
  let ((r, _), st) ← ((((collectPublic types roots).run {}).run cfg).run').toIO ctx { env }
  return (r, st.env)

structure RenderCfg where
  env : Environment
  state : MarshalState
  imports : Array String
  goPath : String
  codecs : Array Desc

def RenderCfg.findType (cfg : RenderCfg) (name : String) : TypeDef :=
  (cfg.state.types.find? (·.ident == name)).getD default

def RenderCfg.alias (cfg : RenderCfg) (path : String) : String :=
  s!"lfmod{(cfg.imports.findIdx? (· == path)).getD 0}"

partial def Desc.go (cfg : RenderCfg) : Desc → String
  | .nat | .int => "*big.Int"
  | .bool => "bool"
  | .char => "rune"
  | .string => "string"
  | .float => "float64"
  | .float32 => "float32"
  | .unit => "struct{}"
  | .bytes => "[]byte"
  | .uint b => s!"uint{b}"
  | .sint b => s!"int{b}"
  | .hostInt signed => if signed then "int" else "uint"
  | .usize => "uint64"
  | .isize => "int64"
  | .fin n => if n ≤ 2 ^ 64 then "uint64" else "*big.Int"
  | .list d | .array d => "[]" ++ d.go cfg
  | .option d => "*" ++ d.go cfg
  | .prod a b => s!"leanfran.Pair[{a.go cfg}, {b.go cfg}]"
  | .except e a => s!"leanfran.Except[{e.go cfg}, {a.go cfg}]"
  | .foreign path name => s!"{cfg.alias path}.{name}"
  | .opaque name => name
  | .named name =>
    match cfg.findType name with
    | { model := some m, .. } => if m.path == cfg.goPath then m.name else s!"{cfg.alias m.path}.{m.name}"
    | { anonymous := true, kind := .subtype d .., .. } => d.go cfg
    | _ => name

partial def Desc.valueType (cfg : RenderCfg) (d : Desc) : String :=
  match d with
  | .nat => "leanfran.NatType"
  | .int => "leanfran.IntType"
  | .char => "leanfran.CharType"
  | .usize => "leanfran.USizeType"
  | .isize => "leanfran.ISizeType"
  | .bytes => "[]byte"
  | .fin n =>
    let digits := (toString n).toList
    let tag := String.join (digits.map (fun c => s!"[{c}]")) ++ "struct{}"
    s!"leanfran.FinType[{tag}]"
  | .list a => s!"leanfran.ListType[{a.valueType cfg}]"
  | .array a => s!"leanfran.ArrayType[{a.valueType cfg}]"
  | .option a => s!"leanfran.OptionType[{a.valueType cfg}]"
  | .prod a b => s!"leanfran.PairType[{a.valueType cfg}, {b.valueType cfg}]"
  | .except a b => s!"leanfran.ExceptType[{a.valueType cfg}, {b.valueType cfg}]"
  | .named name =>
    let t := cfg.findType name
    if t.anonymous || t.model.isSome then name else d.go cfg
  | _ => d.go cfg

def Desc.value (cfg : RenderCfg) (d : Desc) : String :=
  s!"leanfran.Value[{d.valueType cfg}]"

def Desc.codec (cfg : RenderCfg) (d : Desc) : String :=
  match d with
  | .named name => s!"_lfCodec{name}"
  | _ => s!"_lfCodec{cfg.codecs.idxOf d}"

def Desc.codecExpr (cfg : RenderCfg) : Desc → String
  | .nat => "leanfran.Big(\"nat\", \"\")"
  | .int => "leanfran.Big(\"int\", \"\")"
  | .bool => "leanfran.Bool()"
  | .char => "leanfran.Char()"
  | .string => "leanfran.String()"
  | .float => "leanfran.Scalar(\"float\", 64, rt.Lean_box_float, rt.Lean_unbox_float)"
  | .float32 => "leanfran.Scalar(\"float32\", 32, rt.Lean_box_float32, rt.Lean_unbox_float32)"
  | .unit => "leanfran.Unit()"
  | .bytes => "leanfran.Scalar(\"bytes\", 0, rt.BytesFromSlice, rt.Bytes)"
  | .uint b => s!"leanfran.Fixed[uint{b}](\"uint\", {b})"
  | .sint b => s!"leanfran.Fixed[int{b}](\"sint\", {b})"
  | .hostInt true => "leanfran.Fixed[int](\"sint\", 64)"
  | .hostInt false => "leanfran.Fixed[uint](\"uint\", 64)"
  | .usize => "leanfran.Fixed[uint64](\"usize\", 64)"
  | .isize => "leanfran.Fixed[int64](\"isize\", 64)"
  | .fin n => if n ≤ 2 ^ 64 then s!"leanfran.Fin(\"{n}\")" else s!"leanfran.Big(\"fin\", \"{n}\")"
  | .list d => s!"leanfran.Sequence(\"list\", {d.codec cfg})"
  | .array d => s!"leanfran.Sequence(\"array\", {d.codec cfg})"
  | .option d => s!"leanfran.Option({d.codec cfg})"
  | .prod a b => s!"leanfran.Product({a.codec cfg}, {b.codec cfg})"
  | .except e a => s!"leanfran.Result({e.codec cfg}, {a.codec cfg})"
  | .foreign path name => s!"{cfg.alias path}.LeanfranCodec{name}()"
  | .named name => s!"leanfran.Ref(desc{name}, to{name}, from{name}, check{name})"
  | .opaque _ => ""

def boundsCode (bs : Array (String × Int)) : String :=
  if bs.isEmpty then "nil" else
    let entries := bs.foldl (fun (m : Std.TreeMap String Int) (k, v) =>
      m.alter k fun prev => some ((if k.startsWith "max" || k.endsWith "Maximum" then min else max)
        v (prev.getD v))) {}
    s!"map[string]string\{{joinArgs (entries.toArray.map fun (k, v) => s!"{quoteGo k}: \"{v}\"")}}"

def scalarOffset (v : VariantInfo) (f : FieldInfo) : Nat :=
  if f.slot.startsWith "u" && f.slot != "usize" || f.slot.startsWith "f" then
    f.pos + 8 * (v.size + v.usize) else f.pos

def fieldCode (cfg : RenderCfg) (f : FieldInfo) (v : VariantInfo) : String :=
  let pos := scalarOffset v f
  s!"\{Key: {quoteGo f.key}, Desc: {f.desc.codec cfg}.Desc, Slot: {quoteGo f.slot}, Offset: {pos}, Flat: {f.flat}, OmitNone: {f.omitNone}, Bounds: {boundsCode f.bounds}}"

def variantCode (cfg : RenderCfg) (v : VariantInfo) (trivial : Bool) : String :=
  let fields := joinArgs (v.fields.map (fieldCode cfg · v))
  s!"\{Name: {quoteGo v.name}, Tag: {v.cidx}, Objects: {v.size}, ScalarBytes: {8 * v.usize + v.ssize}, Trivial: {trivial}, Positional: {v.positional}, Fields: []schema.Field\{{fields}}}"

def descBody (cfg : RenderCfg) (t : TypeDef) : String :=
  let modelKind (kind : String) := quoteGo (if t.model.isSome then "model" else kind)
  let fields := match t.kind with
    | .enum cases => s!"Kind: {modelKind "enum"}, Cases: []string\{{joinArgs (cases.map (quoteGo ∘ Prod.fst))}}"
    | .subtype base _ bounds => s!"Kind: \"subtype\", First: {base.codec cfg}.Desc, Bounds: {boundsCode bounds}"
    | .struct v trivial => s!"Kind: {modelKind "struct"}, Variants: []schema.Variant\{{variantCode cfg v trivial.isSome}}"
    | .sum vs trivial =>
      let kind := if vs.size == 1 && vs[0]!.fields.isEmpty && vs[0]!.invariants.isEmpty then
        s!"Kind: \"enum\", Cases: []string\{{quoteGo vs[0]!.name}}"
        else "Kind: \"inductive\""
      s!"{kind}, Variants: []schema.Variant\{{joinArgs (vs.map (variantCode cfg · trivial.isSome))}}"
  let goType := if let some m := t.model then s!"GoType: {quoteGo (m.path ++ "." ++ m.name)}, " else ""
  s!"schema.Desc\{Name: {quoteGo (t.model.map (·.name) |>.getD t.ident)}, {goType}{fields}}"

def codecDecl (name ty : String) (external : Bool) : String :=
  s!"func desc{name}() *schema.Desc \{ return &_lfDesc{name} }\n\n" ++
    if external then
      s!"func LeanfranCodec{name}() leanfran.Codec[{ty}] \{ _lfCodecsOnce.Do(_lfBuildCodecs); return _lfCodec{name} }\n\n"
    else ""

def valueMethods (ty root : String) (unmarshal : Bool) : String :=
  let methods := s!"func (v {ty}) LeanfranDesc() *schema.Desc \{ _lfCodecsOnce.Do(_lfBuildCodecs); return desc{root}() }\n\n" ++
    s!"func (v {ty}) Validate() error \{ _lfCodecsOnce.Do(_lfBuildCodecs); return leanfran.Validate(_lfCodec{root}, {if ty == root then "v" else s!"{root}(v)"}, {quoteGo root}) }\n\n" ++
    s!"func (v {ty}) MarshalJSON() ([]byte, error) \{ _lfCodecsOnce.Do(_lfBuildCodecs); return leanfran.MarshalJSON(_lfCodec{root}, {if ty == root then "v" else s!"{root}(v)"}, {quoteGo root}) }\n\n" ++
    s!"func (v {ty}) JSONSchema(target string) (map[string]any, error) \{ _lfCodecsOnce.Do(_lfBuildCodecs); return schema.JSONSchema(desc{root}(), target) }\n\n"
  methods ++ if unmarshal then
    let body := if ty == root then "*v = out" else
      s!"typed, ok := out.({ty})\n\tif !ok \{ return &leanfran.ValidationError\{Issues: []leanfran.Issue\{\{Message: \"unexpected constructor\"}}} }\n\t*v = typed"
    s!"func (v *{ty}) UnmarshalJSON(data []byte) error \{\n\t_lfCodecsOnce.Do(_lfBuildCodecs)\n\tout, err := leanfran.UnmarshalJSON(_lfCodec{root}, data, {quoteGo root})\n\tif err != nil \{ return err }\n\t{body}\n\treturn nil\n}\n\n"
    else ""

def callDecider (cfg : RenderCfg) (inv : InvInfo) (fields : Array (Desc × String)) : Except String String := do
  let some d := IR.findEnvDecl cfg.env inv.decider | throw s!"missing decider {inv.decider}"
  let mut before := ""
  let mut args := #[]
  for (i, p) in d.params.zipIdx.map Prod.swap do
    if !liveParam p then continue
    let some (desc, expr) := (inv.args[i]?).bind (fields[·]?) | throw s!"invalid decider arity {inv.decider}"
    let value := s!"d{i}"
    before := before ++ s!"\t\t{value} := {desc.codec cfg}.ToLean({expr})\n"
    if p.borrow && p.ty.isPossibleRef then before := before ++ s!"\t\tdefer rt.Lean_dec({value})\n"
    args := args.push (unbox p.ty value)
  return before ++ s!"\t\treturn {methodName false d.name}({joinArgs args}) != 0\n"

def invariantCheck (cfg : RenderCfg) (invs : Array InvInfo) (fields : Array (Desc × String))
    (path : String) : Except String String := do
  if invs.isEmpty then return ""
  let mut lines := ""
  for inv in invs do
    let call ← callDecider cfg inv fields
    lines := lines ++ s!"\tif !func() bool \{\n{call}\t}() \{\n\t\te.Add({quoteGo inv.prop}{path}, {quoteGo inv.field})\n\t}\n"
  return lines

partial def flattenFields (cfg : RenderCfg) (fs : Array FieldInfo) : Except String (Array FieldInfo) := do
  let mut out := #[]
  for f in fs do
    if f.flat then
      let kind := match f.desc with
        | .named n => some (cfg.findType n).kind
        | .foreign p n => (cfg.state.foreignTypes[(p, n)]?).map TypeDef.kind
        | _ => none
      let some (.struct v _) := kind | throw s!"unexpected parent structure {f.key}"
      out := out ++ (← flattenFields cfg v.fields)
    else
      out := out.push f
  return out

def variantDecl (cfg : RenderCfg) (ty : String) (fs : Array FieldInfo) (ctor : Option String) : String := Id.run do
  let fields := String.join (fs.toList.map fun f => s!"\t{f.property} {f.desc.go cfg}\n")
  let defn := s!"type {ty} struct \{\n{fields}}\n\n"
  let some ctor := ctor | return defn
  let args := joinArgs (fs.zipIdx.map fun (f, i) => s!"a{i} {f.desc.go cfg}")
  let members := joinArgs (fs.zipIdx.map fun (f, i) => s!"{f.property}: a{i}")
  return defn ++ s!"func {ctor}({args}) ({ty}, error) \{\n\tv := {ty}\{{members}}\n\tif err := v.Validate(); err != nil \{ return {ty}\{}, err }\n\treturn v, nil\n}\n\n"

def directScalar : Desc → String → Option (String × String)
  | .uint b, slot => if slot == s!"u{b}" then some (s!"uint{b}", s!"uint{b}") else none
  | .sint b, slot => if slot == s!"u{b}" then some (s!"uint{b}", s!"int{b}") else none
  | .bool, "u8" => some ("bool", "bool")
  | _, _ => none

def setFieldCode (cfg : RenderCfg) (v : VariantInfo) (f : FieldInfo) (val : String) : String :=
  let pos := scalarOffset v f
  let lean := s!"{f.desc.codec cfg}.ToLean({val})"
  match f.slot, directScalar f.desc f.slot with
  | "obj", _ => s!"\trt.Lean_ctor_set(r, {pos}, {lean})\n"
  | _, some ("bool", _) => s!"\trt.Lean_ctor_set_uint8(r, {pos}, rt.Bool({val}))\n"
  | slot, some (setter, _) => s!"\trt.Lean_ctor_set_{slot.replace "u" "uint"}(r, {pos}, {setter}({val}))\n"
  | "usize", _ => s!"\trt.Lean_ctor_set_usize(r, {pos}, rt.Lean_unbox({lean}))\n"
  | "u8", _ => s!"\trt.Lean_ctor_set_uint8(r, {pos}, uint8(rt.Lean_unbox({lean})))\n"
  | "u16", _ => s!"\trt.Lean_ctor_set_uint16(r, {pos}, uint16(rt.Lean_unbox({lean})))\n"
  | "u32", _ | "f32", _ => s!"\trt.Lean_ctor_set_uint32(r, {pos}, uint32(rt.Lean_unbox({lean})))\n"
  | _, _ => s!"\trt.Lean_ctor_set_uint64(r, {pos}, rt.Lean_unbox({lean}))\n"

def getFieldCode (cfg : RenderCfg) (v : VariantInfo) (f : FieldInfo) : String :=
  let pos := scalarOffset v f
  let c := f.desc.codec cfg
  match f.slot, directScalar f.desc f.slot with
  | "obj", _ => s!"{c}.FromLean(rt.Lean_ctor_get(v, {pos}))"
  | _, some ("bool", _) => s!"rt.Lean_ctor_get_uint8(v, {pos}) != 0"
  | slot, some (_, goTy) => s!"{goTy}(rt.Lean_ctor_get_{slot.replace "u" "uint"}(v, {pos}))"
  | "usize", _ => s!"{c}.FromLean(rt.Lean_box(rt.Lean_ctor_get_usize(v, {pos})))"
  | "u8", _ => s!"{c}.FromLean(rt.Lean_box(uint64(rt.Lean_ctor_get_uint8(v, {pos}))))"
  | "u16", _ => s!"{c}.FromLean(rt.Lean_box(uint64(rt.Lean_ctor_get_uint16(v, {pos}))))"
  | "u32", _ | "f32", _ => s!"{c}.FromLean(rt.Lean_box(uint64(rt.Lean_ctor_get_uint32(v, {pos}))))"
  | _, _ => s!"{c}.FromLean(rt.Lean_box(rt.Lean_ctor_get_uint64(v, {pos})))"

def variantFuncs (cfg : RenderCfg) (stem ty : String) (v : VariantInfo) (trivial : Bool)
    (path : String) : Except String (String × Array FieldInfo) := do
  let mut flat := #[]
  let mut toFields := #[]
  let mut fromFields := #[]
  let mut prelude := ""
  let mut check := ""
  let mut invArgs := #[]
  let mut setters := ""
  for (f, i) in v.fields.zipIdx do
    let fs ← flattenFields cfg #[f]
    flat := flat ++ fs
    let c := f.desc.codec cfg
    let val := if !f.flat then s!"v.{f.property}" else
      s!"{f.desc.go cfg}\{{joinArgs (fs.map fun p => s!"{p.property}: v.{p.property}")}}"
    toFields := toFields.push s!"{c}.ToLean({val})"
    setters := setters ++ setFieldCode cfg v f val
    invArgs := invArgs.push (f.desc, val)
    let get := if trivial then s!"{c}.FromLean(v)" else getFieldCode cfg v f
    if f.flat then
      prelude := prelude ++ s!"\tp{i} := {get}\n"
      fromFields := fromFields ++ fs.map (fun p => s!"{p.property}: p{i}.{p.property}")
    else
      fromFields := fromFields.push s!"{f.property}: {get}"
    let key := if f.flat then "" else if v.positional then s!", {i}" else s!", {quoteGo f.key}"
    check := check ++ s!"\tleanfran.CheckAt(e, {c}, {val}{path}{key})\n"
  let mut used : Std.HashSet String := {}
  for f in flat do
    if used.contains f.property then throw (collisionLabel ++ f.property)
    used := used.insert f.property
  let invariants ← invariantCheck cfg v.invariants invArgs path
  let checkBody := if v.invariants.isEmpty then check else
    "\tstart := len(e.Issues)\n" ++ check ++ "\tif len(e.Issues) != start { return }\n" ++
      invariants
  let toBody :=
    if trivial then s!"\treturn {toFields[0]!}\n"
    else if v.size == 0 && v.usize == 0 && v.ssize == 0 then s!"\treturn rt.Lean_box({v.cidx})\n"
    else s!"\tr := rt.Lean_alloc_ctor({v.cidx}, {v.size}, {8 * v.usize + v.ssize})\n{setters}\treturn r\n"
  let fromParam := if fromFields.isEmpty then "_" else "v"
  let code := s!"func to{stem}(v {ty}) rt.V \{\n{toBody}}\n\n" ++
    s!"func from{stem}({fromParam} rt.V) {ty} \{\n{prelude}\treturn {ty}\{{joinArgs fromFields}}\n}\n\n" ++
    s!"func check{stem}(e *leanfran.ValidationError, v {ty}) \{\n{checkBody}}\n\n"
  return (code, flat)

def emitEnum (name ty label : String) (cases : Array (String × String)) (model : Bool) : String := Id.run do
  if !model then
    let constructors := cases.zipIdx.map fun ((_, ident), i) =>
      s!"func {ident}() {ty} \{ return {ty}\{tag: {i}} }\n\n"
    return s!"type {ty} struct \{ tag uint64 }\n\n" ++ String.join constructors.toList ++
      s!"func to{name}(v {ty}) rt.V \{ return rt.Lean_box(v.tag) }\n\n" ++
      s!"func from{name}(v rt.V) {ty} \{\n\ttag := rt.Lean_unbox(v)\n\tif tag >= {cases.size} \{ rt.Lean_internal_panic(\"invalid {label}\") }\n\treturn {ty}\{tag: tag}\n}\n\n" ++
      s!"func check{name}(e *leanfran.ValidationError, v {ty}) \{\n\tif v.tag >= {cases.size} \{ e.Add(\"expected {label}\") }\n}\n\n"
  return s!"func to{name}(v {ty}) rt.V \{\n\tfor i, c := range desc{name}().Cases \{\n\t\tif string(v) == c \{ return rt.Lean_box(uint64(i)) }\n\t}\n\trt.Lean_internal_panic(\"invalid {label}\")\n\treturn rt.V\{}\n}\n\n" ++
    s!"func from{name}(v rt.V) {ty} \{\n\treturn {ty}(desc{name}().Cases[rt.Lean_unbox(v)])\n}\n\n" ++
    s!"func check{name}(e *leanfran.ValidationError, v {ty}) \{\n\tfor _, c := range desc{name}().Cases \{\n\t\tif string(v) == c \{ return }\n\t}\n\te.Add(\"expected {label}\")\n}\n\n"

def emitSubtype (cfg : RenderCfg) (t : TypeDef) (base : Desc) (inv : InvInfo) : Except String String := do
  let name := t.ident
  let ty := if t.anonymous then base.go cfg else name
  let codec := base.codec cfg
  let val := if t.anonymous then "v" else "v.Val"
  let result := s!"{codec}.FromLean(v)"
  let result := if t.anonymous then result else s!"{ty}\{Val: {result}}"
  let decl := if t.anonymous then "" else
    variantDecl cfg name #[{ key := "val", property := "Val", desc := base, slot := "", pos := 0 }] t.constructor
  let check ← invariantCheck cfg #[inv] #[(base, val)] ""
  return decl ++
    s!"func to{name}(v {ty}) rt.V \{ return {codec}.ToLean({val}) }\n\n" ++
    s!"func from{name}(v rt.V) {ty} \{ return {result} }\n\n" ++
    s!"func check{name}(e *leanfran.ValidationError, v {ty}) \{\n\tstart := len(e.Issues)\n\tleanfran.CheckAt(e, {codec}, {val}, \"val\")\n\tif len(e.Issues) != start \{ return }\n{check}}\n\n"

def emitSum (cfg : RenderCfg) (name : String) (vs : Array VariantInfo) (decoder : String) :
    Except String String := do
  let mut out := s!"type {name} interface \{\n\tis{name}()\n\tValidate() error\n\tMarshalJSON() ([]byte, error)\n\tJSONSchema(string) (map[string]any, error)\n\tLeanfranDesc() *schema.Desc\n}\n\n"
  let mut toCases := ""
  let mut fromCases := ""
  let mut checks := ""
  for v in vs do
    let ty := v.ident
    let (code, fields) ← variantFuncs cfg ty ty v false s!", {quoteGo v.name}"
    out := out ++ variantDecl cfg ty fields v.constructor ++
      s!"func ({ty}) is{name}() \{}\n\n" ++ valueMethods ty name true ++ code
    toCases := toCases ++ s!"\tcase {ty}: return to{ty}(x)\n\tcase *{ty}: return to{ty}(*x)\n"
    fromCases := fromCases ++ s!"\tcase {v.cidx}: return from{ty}(v)\n"
    checks := checks ++ s!"\tcase {ty}: check{ty}(e, x); return\n\tcase *{ty}:\n\t\tif x != nil \{ check{ty}(e, *x); return }\n"
  let fromBody := s!"\tswitch rt.Lean_obj_tag(v) \{\n{fromCases}\t}\n\trt.Lean_internal_panic(\"invalid {name} tag\")\n\treturn nil\n"
  return out ++
    s!"func to{name}(v {name}) rt.V \{\n\tswitch x := v.(type) \{\n{toCases}\t}\n\trt.Lean_internal_panic(\"invalid {name}\")\n\treturn rt.V\{}\n}\n\n" ++
    s!"func from{name}(v rt.V) {name} \{\n{fromBody}}\n\n" ++
    s!"func check{name}(e *leanfran.ValidationError, v {name}) \{\n\tswitch x := v.(type) \{\n{checks}\t}\n\te.Add(\"expected {name}\")\n}\n\n" ++
    s!"func {decoder}(data []byte) ({name}, error) \{\n\t_lfCodecsOnce.Do(_lfBuildCodecs)\n\treturn leanfran.UnmarshalJSON(_lfCodec{name}, data, {quoteGo name})\n}\n\n"

def emitType (cfg : RenderCfg) (t : TypeDef) : Except String String := do
  let name := t.ident
  let ty := (Desc.named name).go cfg
  let (body, methods) ← match t.kind with
    | .enum cases => pure (emitEnum name ty (t.model.map (·.name) |>.getD name) cases t.model.isSome, t.model.isNone)
    | .struct v trivial =>
      let (code, fields) ← variantFuncs cfg name ty v trivial.isSome ""
      pure ((if t.model.isSome then "" else variantDecl cfg name fields v.constructor) ++ code, t.model.isNone)
    | .subtype base inv _ => pure (← emitSubtype cfg t base inv, !t.anonymous)
    | .sum vs trivial =>
      if vs.size == 1 then
        let v := vs[0]!
        let (code, fields) ← variantFuncs cfg name ty v trivial.isSome s!", {quoteGo v.name}"
        pure (variantDecl cfg name fields v.constructor ++ code, true)
      else
        pure (← emitSum cfg name vs t.decoder.get!, false)
  return codecDecl name ty (!t.anonymous && t.model.isNone) ++ body ++
    if methods then valueMethods name name true else ""

partial def Desc.needsCheck (st : MarshalState) (d : Desc) (seen : List Desc := []) : Bool :=
  let check := fun child => child.needsCheck st (d :: seen)
  let variant := fun (v : VariantInfo) => !v.invariants.isEmpty || v.fields.any (check ∘ FieldInfo.desc)
  if seen.contains d then false else
    match d with
    | .bool | .float | .float32 | .uint _ | .sint _ | .hostInt _ | .unit | .usize | .isize | .bytes => false
    | .list a | .array a | .option a => check a
    | .prod a b | .except a b => check a || check b
    | .named _ | .foreign .. =>
      let ty : Option TypeDef := match d with
        | .named name => st.types.find? (fun t => t.ident == name)
        | .foreign ns name => st.foreignTypes[(ns, name)]?
        | _ => none
      match ty with
      | some t =>
        match t.kind with
        | .enum cases => t.model.isSome || cases.isEmpty
        | .struct v _ => variant v
        | .sum vs _ => vs.size != 1 || variant vs[0]!
        | .subtype .. => true
      | none => true
    | _ => true

def PublicSig.canFail (sig : PublicSig) : Bool :=
  sig.io || (match sig.result with | .except .. => true | _ => false)

def returnSignature (types : Array String) (canFail : Bool) : String :=
  let types := if canFail then types.push "error" else types
  match types.size with
  | 0 => ""
  | 1 => types[0]! ++ " "
  | _ => "(" ++ joinArgs types ++ ") "

def returnValues (values : Array String) (canFail : Bool) : String :=
  let values := if canFail then values.push "nil" else values
  if values.isEmpty then "" else "\treturn " ++ joinArgs values ++ "\n"

def emitPublicFn (cfg : RenderCfg) (f : PublicFn) : Except String String := do
  let ret := f.sig.result
  let result := match ret with | .except _ a => a | _ => ret
  let unit := result == .unit
  let resultType := result.go cfg
  let fail := if unit then "err" else s!"leanfran.Zero[{resultType}](), err"
  let params := f.target.params
  let mut ownership := ""
  let mut args := #[]
  let mut binders := #[]
  let mut checks := ""
  for (param, i) in f.sig.params.zipIdx do
    match param with
    | .world => pure ()
    | .value name d =>
      let x := s!"a{i}"
      let some p := params[i]? | throw s!"incompatible IR parameters for {f.target.name}"
      binders := binders.push s!"{x} {d.go cfg}"
      let codec := d.codec cfg
      if d == .nat || d == .int then
        checks := checks ++ s!"\tif issue := leanfran.IntegerIssue({x}, {d == .nat}); issue != \"\" \{ _lfValidation.Add(issue, {quoteGo name}) }\n"
      else if d.needsCheck cfg.state then
        checks := checks ++ s!"\tleanfran.CheckAt(&_lfValidation, {codec}, {x}, {quoteGo name})\n"
      if !liveParam p then continue
      let value := s!"v{i}"
      ownership := ownership ++ s!"\t{value} := {codec}.ToLean({x})\n"
      if p.borrow && p.ty.isPossibleRef then
        ownership := ownership ++ s!"\tdefer rt.Lean_dec({value})\n"
      args := args.push (unbox p.ty value)
  unless args.size == (params.filter liveParam).size do throw s!"incompatible IR parameters for {f.target.name}"
  let canFail := f.sig.canFail || !checks.isEmpty
  let signature := returnSignature (if unit then #[] else #[resultType]) canFail
  let checkBody := if checks.isEmpty then "" else
    "\tvar _lfValidation leanfran.ValidationError\n" ++ checks ++
      s!"\tif len(_lfValidation.Issues) != 0 \{\n\t\terr := &leanfran.ValidationError\{Issues: _lfValidation.Issues}\n\t\treturn {fail}\n\t}\n"
  let call := s!"{methodName false f.target.name}({joinArgs args})"
  let ty := f.target.resultType
  let run := if ty.isVoid then s!"\t{call}\n" else s!"\t_lfResult := {box ty call}\n"
  let run := if !f.sig.io then run else run ++
    s!"\t_lfResult, err := leanfran.ReadIO(_lfResult)\n\tif err != nil \{ return {fail} }\n"
  let cleanup := if ty.isPossibleRef then "\tdefer rt.Lean_dec(_lfResult)\n" else ""
  let (run, cleanup) := if unit && !f.sig.io && !ty.isPossibleRef && ret == .unit then (s!"\t{call}\n", "") else (run, cleanup)
  let branch := match ret with
    | .except e _ =>
      let fail := if unit then "err" else s!"leanfran.Zero[{resultType}](), err"
      s!"\tif rt.Lean_obj_tag(_lfResult) == 0 \{\n\t\terr := &leanfran.ExceptError[{e.go cfg}]\{Value: {e.codec cfg}.FromLean(rt.Lean_ctor_get(_lfResult, 0))}\n\t\treturn {fail}\n\t}\n"
    | _ => ""
  let output := if unit then #[] else
    let value := if branch.isEmpty then "_lfResult" else "rt.Lean_ctor_get(_lfResult, 0)"
    #[s!"{result.codec cfg}.FromLean({value})"]
  let ready := if cfg.codecs.isEmpty && cfg.state.types.isEmpty then "" else
    "\t_lfCodecsOnce.Do(_lfBuildCodecs)\n"
  return s!"func {f.ident}({joinArgs binders}) {signature}\{\n{ready}{checkBody}{ownership}{run}{cleanup}{branch}{returnValues output canFail}}\n\n"

def valueNamespace (name : String) : String :=
  s!"var {name} lf{name}\n\ntype lf{name} struct\{}\n\ntype lfScoped{name} struct \{\n\tscope *leanfran.ValueScope\n}\n\n" ++
  s!"func (lf{name}) In(scope *leanfran.ValueScope) lfScoped{name} \{\n\treturn lfScoped{name}\{scope: scope}\n}\n\n"

def emitValueConversion (cfg : RenderCfg) (c : ValueConversion) : String :=
  let ty := c.desc.go cfg
  let marker := c.desc.valueType cfg
  let wrapped := c.desc.value cfg
  let codec := c.desc.codec cfg
  let ready := "_lfCodecsOnce.Do(_lfBuildCodecs)"
  let checked := c.desc.needsCheck cfg.state
  let signature := returnSignature #[wrapped] checked
  let newCall := if checked then
    s!"leanfran.NewValueIn[{marker}](api.scope, {codec}, v, {quoteGo c.desc.valueStem})"
    else s!"leanfran.NewUncheckedValueIn[{marker}](api.scope, {codec}, v)"
  s!"func (lfValue) {c.newIdent}(v {ty}) {signature}\{\n\treturn lfScopedValue\{}.{c.newIdent}(v)\n}\n\n" ++
  s!"func (api lfScopedValue) {c.newIdent}(v {ty}) {signature}\{\n\t{ready}\n\treturn {newCall}\n}\n\n" ++
  s!"func (lfValue) {c.readIdent}(v {wrapped}) {ty} \{\n\treturn lfScopedValue\{}.{c.readIdent}(v)\n}\n\n" ++
  s!"func (api lfScopedValue) {c.readIdent}(v {wrapped}) {ty} \{\n\t{ready}\n\treturn leanfran.ReadValueIn(api.scope, {codec}, v)\n}\n\n"

def emitValueFn (cfg : RenderCfg) (f : PublicFn) : Except String String := do
  let ret := f.sig.result
  let result := match ret with | .except _ a => a | _ => ret
  let results := match result with | .unit => #[] | .prod a b => #[a, b] | d => #[d]
  let types := results.map (·.value cfg)
  let canFail := f.sig.canFail
  let signature := returnSignature types canFail
  let zeroes := types.map (· ++ "{}")
  let fail := joinArgs (zeroes.push "err")
  let mut args := #[]
  let mut binders := #[]
  let mut forwarded := #[]
  let mut inputs := #[]
  let mut ownership := ""
  for (param, i) in f.sig.params.zipIdx do
    match param with
    | .world => continue
    | .value _ d =>
      let x := s!"a{i}"
      let some p := f.target.params[i]? | throw s!"incompatible IR parameters for {f.target.name}"
      forwarded := forwarded.push x
      binders := binders.push s!"{x} leanfran.ValueInput[{d.valueType cfg}]"
      let input := s!"inputs[{inputs.size}].Lean()"
      inputs := inputs.push s!"{x}.Use()"
      if !liveParam p then
        ownership := ownership ++ s!"\tdefer rt.Lean_dec({input})\n"
      else
        if p.borrow && p.ty.isPossibleRef then
          ownership := ownership ++ s!"\tdefer rt.Lean_dec({input})\n"
        args := args.push (unbox p.ty input)
  unless args.size == (f.target.params.filter liveParam).size do
    throw s!"incompatible IR parameters for {f.target.name}"
  let prepare := if inputs.isEmpty then
      "\top := leanfran.BeginValueOperation(api.scope, nil)\n\tdefer op.End()\n"
    else
      s!"\tinputs := [{inputs.size}]leanfran.ValueUse\{{joinArgs inputs}}\n\top := leanfran.BeginValueOperation(api.scope, inputs[:])\n\tdefer op.End()\n\top.Acquire(inputs[:])\n"
  let call := s!"{methodName false f.target.name}({joinArgs args})"
  let ty := f.target.resultType
  let keepResult := ret != .unit || f.sig.io
  let run := if !keepResult && !ty.isPossibleRef then s!"\t{call}\n" else
    s!"\traw := {box ty call}\n"
  let io := if !f.sig.io then "" else
    s!"\tvar err error\n\traw, err = leanfran.ReadIO(raw)\n\tif err != nil \{ return {fail} }\n"
  let mut raw := "raw"
  let mut body := ""
  match ret with
  | .except e _ =>
    let errType := if e.convertible then e.go cfg else e.value cfg
    let errValue := if e.convertible then s!"{e.codec cfg}.FromLean(rt.Lean_ctor_get(raw, 0))" else
      s!"leanfran.WrapValueIn[{e.valueType cfg}](op, leanfran.OwnValueField(raw, 0))"
    let ready := if e.convertible then "\t\t_lfCodecsOnce.Do(_lfBuildCodecs)\n" else ""
    body := body ++ s!"\tdefer rt.Lean_dec(raw)\n\tif rt.Lean_obj_tag(raw) == 0 \{\n{ready}\t\terr := &leanfran.ExceptError[{errType}]\{Value: {errValue}}\n\t\treturn {fail}\n\t}\n"
    raw := "rt.Lean_ctor_get(raw, 0)"
  | _ => pure ()
  let output := match result with
    | .unit => #[]
    | .prod .. => #["first", "second"]
    | d =>
      let owned := if raw == "raw" then raw else "leanfran.OwnValueField(raw, 0)"
      #[s!"leanfran.WrapValueIn[{d.valueType cfg}](op, {owned})"]
  if raw == "raw" && (match result with | .prod .. => true | .unit => ty.isPossibleRef | _ => false) then
    body := body ++ "\tdefer rt.Lean_dec(raw)\n"
  if let .prod a b := result then
    body := body ++ s!"\tfirst, second := leanfran.WrapFieldsIn[{a.valueType cfg}, {b.valueType cfg}](op, {raw})\n"
  let forward := if signature.isEmpty then "" else "return "
  let wrapper := s!"func (lfHandle) {f.ident}({joinArgs binders}) {signature}\{\n\t{forward}lfScopedHandle\{}.{f.ident}({joinArgs forwarded})\n}\n\n"
  return wrapper ++ s!"func (api lfScopedHandle) {f.ident}({joinArgs binders}) {signature}\{\n{prepare}{ownership}{run}{io}{body}{returnValues output canFail}}\n\n"

def usesQualifier (source qualifier : String) : Bool := Id.run do
  let mut plain := ""
  let mut inString := false
  let mut escape := false
  for c in source.toList do
    if escape then escape := false
    else if c == '"' then
      inString := !inString
      plain := plain.push ' '
    else if inString then
      if c == '\\' then escape := true
    else
      plain := plain.push c
  return (plain.splitOn (qualifier ++ ".")).length > 1

def packageSource (cfg : RenderCfg) (mod : Name) (pkg generatorVersion body : String) : String :=
  let aliases := #[("", "math/big", "big"), ("", "sync", "sync"),
    ("", "github.com/conao3/leanfran-go", "leanfran"),
    ("", "github.com/conao3/leanfran-go/rt", "rt"),
    ("", "github.com/conao3/leanfran-go/schema", "schema")] ++
    cfg.imports.map (fun path => (cfg.alias path, path, cfg.alias path))
  let imports := aliases.filterMap fun (alias, path, qualifier) =>
    if usesQualifier body qualifier then some <|
      if alias.isEmpty then quoteGo path else s!"{alias} {quoteGo path}"
    else none
  let imports := if imports.isEmpty then "" else
    "\nimport (\n" ++ String.join (imports.toList.map (fun i => s!"\t{i}\n")) ++ ")\n"
  let mod := (toString mod).replace "\n" "\\n" |>.replace "\r" "\\r"
  s!"// Code generated by leanfran-go (generator {generatorVersion}) from {mod}. DO NOT EDIT.\n\npackage {pkg}\n{imports}\n{body}"

def verificationTypes (st : MarshalState) (goPath : String) : Json := Json.arr <| Id.run do
  let mut entries := #[]
  for (type, desc) in st.byType.toArray do
    let some lean := type.constName? | continue
    let .named ident := desc | continue
    let some t := st.types.find? (·.ident == ident) | continue
    let path := (t.model.map (·.path)).getD goPath
    let name := (t.model.map (·.name)).getD ident
    let base := [("path", toJson path), ("name", toJson name), ("lean", toJson lean.toString),
      ("plain", toJson ((t.model.map (·.plain)).getD false))]
    match t.kind with
    | .struct shape _ =>
      if shape.positional || shape.fields.any (fun f => f.flat || f.omitNone) then continue
      if t.model.any (·.restricted) then continue
      let fields := Json.mkObj (shape.fields.toList.map fun f => (f.property, toJson f.key))
      entries := entries.push (Json.mkObj (base ++ [("fields", fields),
        ("invariants", toJson (!shape.invariants.isEmpty))]))
    | .enum cases =>
      if t.model.isNone then
        entries := entries.push (Json.mkObj (base ++ [("cases",
          Json.mkObj (cases.toList.map fun (name, _) => (name, toJson name))),
          ("constructors", Json.mkObj (cases.toList.map fun (name, ident) => (ident, toJson name))),
          ("zeroCase", toJson ((cases[0]?.map Prod.fst).getD ""))]))
    | _ => pure ()
  return entries

partial def Desc.codecDependencies (d : Desc) : List Desc :=
  match d with
  | .named _ => []
  | .list item | .array item | .option item => item.codecDependencies ++ [d]
  | .prod a b | .except a b => a.codecDependencies ++ b.codecDependencies ++ [d]
  | _ => [d]

def TypeDef.codecInputs (t : TypeDef) : List Desc :=
  let fields (v : VariantInfo) := v.fields.toList.map (·.desc)
  match t.kind with
  | .enum _ => []
  | .struct v _ => fields v
  | .sum vs _ => vs.toList.flatMap fields
  | .subtype base .. => [base]

def PublicFn.codecInputs (st : MarshalState) (f : PublicFn) : List Desc :=
  let inputs := f.sig.params.zipIdx.toList.filterMap fun (param, i) =>
    match param with
    | .world => none
    | .value _ d =>
      if (f.target.params[i]?.any liveParam) || (d.needsCheck st && d != .nat && d != .int) then
        some d
      else none
  let outputs := match f.sig.result with
    | .except e .unit => [e]
    | .except e a => [e, a]
    | .unit => []
    | d => [d]
  inputs ++ outputs

def packageCodecs (cfg : RenderCfg) (types : Array TypeDef) : String := Id.run do
  let named := types.map fun t => Desc.named t.ident
  let codecs := named ++ cfg.codecs
  if codecs.isEmpty then return ""
  let vars := codecs.map fun d => s!"var {d.codec cfg} leanfran.Codec[{d.go cfg}]\n"
  let descriptors := types.map fun t => s!"var _lfDesc{t.ident} schema.Desc\n"
  let makeCodecs := codecs.map fun d => s!"\t{d.codec cfg} = {d.codecExpr cfg}\n"
  let makeDescriptors := types.map fun t => s!"\t_lfDesc{t.ident} = {descBody cfg t}\n"
  return String.join ((vars ++ descriptors).toList) ++
    "\nvar _lfCodecsOnce sync.Once\n\nfunc _lfBuildCodecs() {\n" ++
    String.join ((makeCodecs ++ makeDescriptors).toList) ++ "}\n\n" ++
    "func init() { _lfCodecsOnce.Do(_lfBuildCodecs) }\n\n"

def publicSources (env : Environment) (mod : Name) (pkg version goPath : String) (collected : PublicModule) :
    Except String (Array (String × String)) := do
  let paths := collected.state.foreignTypes.toArray.map (·.1.1) ++
    (collected.state.types.filterMap (·.model.map (·.path))).filter (· != goPath)
  let imports := paths.toList.eraseDups.toArray.qsort (· < ·)
  let types := collected.state.types.qsort (fun a b => a.ident < b.ident)
  let funcs := collected.functions.qsort (fun a b => a.ident < b.ident)
  let conversions := collected.conversions.qsort (fun a b => a.newIdent < b.newIdent)
  let handles := collected.handles.qsort (fun a b => a.ident < b.ident)
  let inputs := types.toList.flatMap TypeDef.codecInputs ++ funcs.toList.flatMap (PublicFn.codecInputs collected.state) ++
    conversions.toList.map (·.desc)
  let codecs := (inputs.flatMap Desc.codecDependencies).eraseDups.toArray
  let cfg := { env, state := collected.state, imports, goPath, codecs : RenderCfg }
  let typeBody ← types.mapM (emitType cfg)
  let funcBody ← funcs.mapM (emitPublicFn cfg)
  let valueBody ← handles.mapM (emitValueFn cfg)
  let conversionBody := conversions.map (emitValueConversion cfg)
  let markers := cfg.state.opaqueTypes ++ (types.filterMap fun t =>
    if t.anonymous || t.model.isSome then some t.ident else none)
  let markerBody := String.join (markers.toList.map fun n => s!"type {n} struct\{}\n\n")
  let valueAPI := if conversions.isEmpty then "" else valueNamespace "Value" ++ String.join conversionBody.toList
  let handleAPI := if handles.isEmpty then "" else valueNamespace "Handle" ++ String.join valueBody.toList
  let lean ← generate env mod (collected.functions.map (·.target.name) ++ collected.handles.map (·.target.name) ++
      cfg.state.deciders) pkg none version false
  return #[("leanfran_types_gen.go", packageSource cfg mod pkg version (packageCodecs cfg types ++ String.join typeBody.toList ++ markerBody ++ valueAPI)),
    ("leanfran_funcs_gen.go", packageSource cfg mod pkg version (String.join funcBody.toList ++ handleAPI)),
    ("leanfran_lean_gen.go", lean)]

end LeanGo
