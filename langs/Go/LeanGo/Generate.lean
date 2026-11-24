import LeanGo.Marshal

open Lean Meta Lean.IR

namespace LeanGo

structure Skipped where
  name : Name
  reason : String

structure PublicFn where
  target : IR.Decl
  ident : String
  sig : PublicSig

structure PublicModule where
  state : MarshalState
  functions : Array PublicFn
  skipped : Array Skipped

def isNameCollision (reason : String) : Bool := reason.startsWith collisionLabel

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
      functions := functions.push { target, ident, sig }
    catch e =>
      let reason ← e.toMessageData.toString
      if isNameCollision reason then throw e
      setEnv savedEnv
      set saved
      skipped := skipped.push { name := r, reason }
  return { state := ← get, functions, skipped }

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
  | .named name =>
    match cfg.findType name with
    | { model := some m, .. } => if m.path == cfg.goPath then m.name else s!"{cfg.alias m.path}.{m.name}"
    | { anonymous := true, kind := .subtype d .., .. } => d.go cfg
    | _ => name

partial def Desc.codec (cfg : RenderCfg) : Desc → String
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
  | .named name => s!"codec{name}()"

def boundsCode (bs : Array (String × Int)) : String :=
  if bs.isEmpty then "nil" else
    let entries := bs.foldl (fun (m : Std.TreeMap String Int) (k, v) =>
      m.alter k fun prev => some ((if k.startsWith "max" || k.endsWith "Maximum" then min else max)
        v (prev.getD v))) {}
    s!"map[string]string\{{joinArgs (entries.toArray.map fun (k, v) => s!"{quoteGo k}: \"{v}\"")}}"

def fieldCode (cfg : RenderCfg) (f : FieldInfo) (v : VariantInfo) : String :=
  let pos := if f.slot.startsWith "u" && f.slot != "usize" || f.slot.startsWith "f" then
    f.pos + 8 * (v.size + v.usize) else f.pos
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
    | .sum vs trivial => s!"Kind: \"inductive\", Variants: []schema.Variant\{{joinArgs (vs.map (variantCode cfg · trivial.isSome))}}"
  let goType := if let some m := t.model then s!"GoType: {quoteGo (m.path ++ "." ++ m.name)}, " else ""
  s!"func desc{t.ident}() *schema.Desc \{\n\treturn &schema.Desc\{Name: {quoteGo (t.model.map (·.name) |>.getD t.ident)}, {goType}{fields}}\n}\n\n"

def codecDecl (name ty : String) (external : Bool) : String :=
  let privateCodec := s!"func codec{name}() leanfran.Codec[{ty}] \{\n\treturn leanfran.Ref(desc{name}, to{name}, from{name}, check{name})\n}\n\n"
  privateCodec ++ if external then
    s!"func LeanfranCodec{name}() leanfran.Codec[{ty}] \{\n\treturn codec{name}()\n}\n\n" else ""

def valueMethods (ty root : String) (unmarshal : Bool) : String :=
  let methods := s!"func (v {ty}) LeanfranDesc() *schema.Desc \{ return desc{root}() }\n\n" ++
    s!"func (v {ty}) Validate() error \{ return leanfran.Validate(codec{root}(), {if ty == root then "v" else s!"{root}(v)"}, {quoteGo root}) }\n\n" ++
    s!"func (v {ty}) MarshalJSON() ([]byte, error) \{ return leanfran.MarshalJSON(codec{root}(), {if ty == root then "v" else s!"{root}(v)"}, {quoteGo root}) }\n\n" ++
    s!"func (v {ty}) JSONSchema(target string) (map[string]any, error) \{ return schema.JSONSchema(desc{root}(), target) }\n\n"
  methods ++ if unmarshal then
    let body := if ty == root then "*v = out" else
      s!"typed, ok := out.({ty})\n\tif !ok \{ return &leanfran.ValidationError\{Issues: []leanfran.Issue\{\{Message: \"unexpected constructor\"}}} }\n\t*v = typed"
    s!"func (v *{ty}) UnmarshalJSON(data []byte) error \{\n\tout, err := leanfran.UnmarshalJSON(codec{root}(), data, {quoteGo root})\n\tif err != nil \{ return err }\n\t{body}\n\treturn nil\n}\n\n"
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

def variantFuncs (cfg : RenderCfg) (stem ty : String) (v : VariantInfo) (layout : String)
    (path : String) : Except String (String × Array FieldInfo) := do
  let mut flat := #[]
  let mut toFields := #[]
  let mut fromFields := #[]
  let mut prelude := ""
  let mut check := ""
  let mut invArgs := #[]
  for (f, i) in v.fields.zipIdx do
    let fs ← flattenFields cfg #[f]
    flat := flat ++ fs
    let c := f.desc.codec cfg
    let val := if !f.flat then s!"v.{f.property}" else
      s!"{f.desc.go cfg}\{{joinArgs (fs.map fun p => s!"{p.property}: v.{p.property}")}}"
    toFields := toFields.push s!"{c}.ToLean({val})"
    invArgs := invArgs.push (f.desc, val)
    if f.flat then
      prelude := prelude ++ s!"\tp{i} := {c}.FromLean(layout.Get(v, {i}))\n"
      fromFields := fromFields ++ fs.map (fun p => s!"{p.property}: p{i}.{p.property}")
    else
      fromFields := fromFields.push s!"{f.property}: {c}.FromLean(layout.Get(v, {i}))"
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
  let fromLayout := if fromFields.isEmpty then "" else s!"\tlayout := {layout}\n"
  let code := s!"func to{stem}(v {ty}) rt.V \{\n\treturn {layout}.Build([]rt.V\{{joinArgs toFields}})\n}\n\n" ++
    s!"func from{stem}(v rt.V) {ty} \{\n{fromLayout}{prelude}\treturn {ty}\{{joinArgs fromFields}}\n}\n\n" ++
    s!"func check{stem}(e *leanfran.ValidationError, v {ty}) \{\n{checkBody}}\n\n"
  return (code, flat)

def emitEnum (name ty label : String) (cases : Array (String × String)) (model : Bool) : String := Id.run do
  let constants := cases.map fun (c, ident) => s!"\t{ident} {name} = {quoteGo c}\n"
  let decl := if model then "" else s!"type {ty} string\n\nconst (\n{String.join constants.toList})\n\n"
  return decl ++
    s!"func to{name}(v {ty}) rt.V \{\n\tfor i, c := range desc{name}().Cases \{\n\t\tif string(v) == c \{ return rt.Lean_box(uint64(i)) }\n\t}\n\trt.Lean_internal_panic(\"invalid {label}\")\n\treturn rt.V\{}\n}\n\n" ++
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

def emitSum (cfg : RenderCfg) (name : String) (vs : Array VariantInfo) (trivial : Bool) (decoder : String) :
    Except String String := do
  let mut out := s!"type {name} interface \{\n\tis{name}()\n\tValidate() error\n\tMarshalJSON() ([]byte, error)\n\tJSONSchema(string) (map[string]any, error)\n\tLeanfranDesc() *schema.Desc\n}\n\n"
  let mut toCases := ""
  let mut fromCases := ""
  let mut checks := ""
  for (v, i) in vs.zipIdx do
    let ty := v.ident
    let (code, fields) ← variantFuncs cfg ty ty v s!"desc{name}().Variants[{i}]" s!", {quoteGo v.name}"
    out := out ++ variantDecl cfg ty fields v.constructor ++
      s!"func ({ty}) is{name}() \{}\n\n" ++ valueMethods ty name true ++ code
    toCases := toCases ++ s!"\tcase {ty}: return to{ty}(x)\n\tcase *{ty}: return to{ty}(*x)\n"
    fromCases := fromCases ++ s!"\tcase {v.cidx}: return from{ty}(v)\n"
    checks := checks ++ s!"\tcase {ty}: check{ty}(e, x); return\n\tcase *{ty}:\n\t\tif x != nil \{ check{ty}(e, *x); return }\n"
  let fromBody := if trivial then s!"\treturn from{vs[0]!.ident}(v)\n" else
    s!"\tswitch rt.Lean_obj_tag(v) \{\n{fromCases}\t}\n\trt.Lean_internal_panic(\"invalid {name} tag\")\n\treturn nil\n"
  return out ++
    s!"func to{name}(v {name}) rt.V \{\n\tswitch x := v.(type) \{\n{toCases}\t}\n\trt.Lean_internal_panic(\"invalid {name}\")\n\treturn rt.V\{}\n}\n\n" ++
    s!"func from{name}(v rt.V) {name} \{\n{fromBody}}\n\n" ++
    s!"func check{name}(e *leanfran.ValidationError, v {name}) \{\n\tswitch x := v.(type) \{\n{checks}\t}\n\te.Add(\"expected {name}\")\n}\n\n" ++
    s!"func {decoder}(data []byte) ({name}, error) \{\n\treturn leanfran.UnmarshalJSON(codec{name}(), data, {quoteGo name})\n}\n\n"

def emitType (cfg : RenderCfg) (t : TypeDef) : Except String String := do
  let name := t.ident
  let ty := (Desc.named name).go cfg
  let (body, methods) ← match t.kind with
    | .enum cases => pure (emitEnum name ty (t.model.map (·.name) |>.getD name) cases t.model.isSome, t.model.isNone)
    | .struct v _ =>
      let (code, fields) ← variantFuncs cfg name ty v s!"desc{name}().Variants[0]" ""
      pure ((if t.model.isSome then "" else variantDecl cfg name fields v.constructor) ++ code, t.model.isNone)
    | .subtype base inv _ => pure (← emitSubtype cfg t base inv, !t.anonymous)
    | .sum vs trivial => pure (← emitSum cfg name vs trivial.isSome t.decoder.get!, false)
  return descBody cfg t ++ codecDecl name ty (!t.anonymous && t.model.isNone) ++ body ++
    if methods then valueMethods name name true else ""

def Desc.needsCheck : Desc → Bool
  | .bool | .float | .float32 | .uint _ | .sint _ | .hostInt _ | .unit | .usize | .isize | .bytes => false
  | _ => true

def emitPublicFn (cfg : RenderCfg) (f : PublicFn) : Except String String := do
  let ret := f.sig.result
  let result := match ret with | .except _ a => a | _ => ret
  let unit := result == .unit
  let resultType := result.go cfg
  let signature := if unit then "error" else s!"({resultType}, error)"
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
      if d.needsCheck then
        checks := checks ++ s!"\tleanfran.CheckAt(&_lfValidation, {codec}, {x}, {quoteGo name})\n"
      if !liveParam p then continue
      let value := s!"v{i}"
      ownership := ownership ++ s!"\t{value} := {codec}.ToLean({x})\n"
      if p.borrow && p.ty.isPossibleRef then
        ownership := ownership ++ s!"\tdefer rt.Lean_dec({value})\n"
      args := args.push (unbox p.ty value)
  unless args.size == (params.filter liveParam).size do throw s!"incompatible IR parameters for {f.target.name}"
  let checkBody := if checks.isEmpty then "" else
    "\tvar _lfValidation leanfran.ValidationError\n" ++ checks ++
      s!"\tif err := _lfValidation.Err(); err != nil \{ return {fail} }\n"
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
  let output := if ret == .unit || unit then "nil" else
    let value := if branch.isEmpty then "_lfResult" else "rt.Lean_ctor_get(_lfResult, 0)"
    s!"{result.codec cfg}.FromLean({value}), nil"
  return s!"func {f.ident}({joinArgs binders}) {signature} \{\n{checkBody}{ownership}{run}{cleanup}{branch}\treturn {output}\n}\n\n"

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
  let aliases := #[("", "math/big", "big"),
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

def publicSources (env : Environment) (mod : Name) (pkg version goPath : String) (collected : PublicModule) :
    Except String (Array (String × String)) := do
  let paths := collected.state.foreignTypes.toArray.map (·.1.1) ++
    (collected.state.types.filterMap (·.model.map (·.path))).filter (· != goPath)
  let imports := paths.toList.eraseDups.toArray.qsort (· < ·)
  let cfg := { env, state := collected.state, imports, goPath : RenderCfg }
  let types ← (cfg.state.types.qsort (fun a b => a.ident < b.ident)).mapM (emitType cfg)
  let funcs ← (collected.functions.qsort (fun a b => a.ident < b.ident)).mapM (emitPublicFn cfg)
  let lean ← generate env mod (collected.functions.map (·.target.name) ++ cfg.state.deciders) pkg none version false
  return #[("leanfran_types_gen.go", packageSource cfg mod pkg version (String.join types.toList)),
    ("leanfran_funcs_gen.go", packageSource cfg mod pkg version (String.join funcs.toList)),
    ("leanfran_lean_gen.go", lean)]

end LeanGo
