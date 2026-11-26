import LeanC.ClangAst
import LeanC.Desc

open Lean System
open LeanC.ClangAst

namespace LeanC.Verify

inductive Ty where
  | int (lean : String) (signed : Bool) (width : Nat)
  | bool
  | double
  | unit
  | record (key : String)
  | status
  | enum (key : String)
  | variant (key : String)
  | members (key : String)
  | payload (key : String) (member : String)
  deriving BEq, Inhabited

structure Field where
  lean : String
  ty : Option Ty
  boundary : String
  deriving Inhabited

structure Record where
  lean : String
  fields : Std.HashMap String Field
  deriving Inhabited

structure Enum where
  lean : String
  ctors : Array String
  count : Nat
  underlying : Ty
  deriving Inhabited

structure Member where
  ctor : String
  fields : Std.HashMap String Field
  deriving Inhabited

structure Variant where
  lean : String
  ctors : Nat
  members : Std.HashMap String Member
  tag : Option Ty := none
  deriving Inhabited

structure Problem where
  location : Location
  reason : String
  deriving Inhabited

inductive ParamKind where
  | value
  | array (elem : Ty) (boundary : String) (length : String)
  | length (array : String)
  | out
  deriving Inhabited

structure Param where
  name : String
  id : String
  lean : String
  ty : Ty
  boundary : String
  kind : ParamKind
  cType : String := ""
  deriving Inhabited

inductive Result where
  | value (ty : Ty) (boundary : String)
  | status (ty : Ty) (boundary : String)
  deriving Inhabited

structure Function where
  name : String
  lean : String
  params : Array Param
  result : Result
  fallible : Bool
  source : String
  resultType : String := ""
  deriving Inhabited

structure Env where
  records : Std.HashMap String Record := {}
  enums : Std.HashMap String Enum := {}
  enumerators : Std.HashMap String Int := {}
  variants : Std.HashMap String Variant := {}
  names : Std.HashMap String String := {}
  functions : Std.HashMap String Function := {}
  defined : Std.HashSet String := {}
  deriving Inhabited

def leanIdent (name : String) : String := s!"«{name}»"

private def strip (ty : String) : String :=
  let ty := ty.trimAscii.toString
  if ty.startsWith "const " then (ty.drop 6).trimAscii.toString else ty

private def intTy (lean : String) : Ty :=
  let signed := lean.startsWith "Int"
  let width := (lean.dropWhile (!·.isDigit)).toString.toNat!
  .int lean signed width

private def sugarTypes : List (String × Ty) :=
  [("int8_t", intTy "Int8"), ("uint8_t", intTy "UInt8"), ("int16_t", intTy "Int16"),
    ("uint16_t", intTy "UInt16"), ("int32_t", intTy "Int32"), ("uint32_t", intTy "UInt32"),
    ("int64_t", intTy "Int64"), ("uint64_t", intTy "UInt64"), ("size_t", intTy "UInt64"),
    ("bool", .bool), ("_Bool", .bool), ("double", .double), ("void", .unit),
    ("signed char", intTy "Int8"), ("unsigned char", intTy "UInt8"), ("short", intTy "Int16"),
    ("unsigned short", intTy "UInt16"), ("int", intTy "Int32"), ("unsigned int", intTy "UInt32"),
    ("long", intTy "Int64"), ("unsigned long", intTy "UInt64"), ("long long", intTy "Int64"),
    ("unsigned long long", intTy "UInt64")]

def Env.resolve (env : Env) (qual : String) (desugared : String := "") : Option Ty := do
  if qual.contains "volatile" || desugared.contains "volatile" then none
  let names := [strip qual] ++ (if desugared.isEmpty then [] else [strip desugared])
  names.findSome? fun name =>
    sugarTypes.lookup name <|> (env.names[name]? >>= fun id =>
      if env.records.contains id then some (Ty.record id)
      else if env.variants.contains id then some (Ty.variant id)
      else env.enums[id]?.map fun e => if e.lean.isEmpty then e.underlying else Ty.enum id)

def Env.lean (env : Env) : Ty → String
  | .int lean _ _ => lean
  | .bool => "Bool"
  | .double => "Float"
  | .unit => "Unit"
  | .status => "C.Status"
  | .record key => (env.records[key]?.map (·.lean)).getD "Unit"
  | .enum key => (env.enums[key]?.map (·.lean)).getD "Unit"
  | .variant key => (env.variants[key]?.map (·.lean)).getD "Unit"
  | .members _ | .payload .. => "Unit"

private partial def Env.leaves (env : Env) : Ty → Option (Array Ty)
  | .int _ _ w => some #[.int "" false w]
  | .enum _ => some #[.int "" false 32]
  | .record key => env.records[key]?.bind fun r =>
    (r.fields.toArray.mapM fun ((_, f) : String × Field) => f.ty >>= env.leaves).map Array.flatten
  | .variant key => env.variants[key]?.bind fun v => do
    let fields := (v.members.toArray.flatMap fun (_, m) => m.fields.toArray).map (·.2.ty)
    let leaves ← (fields.push v.tag).mapM (· >>= env.leaves)
    return leaves.flatten
  | ty => some #[ty]

def Env.mayOverlap (env : Env) (a b : Ty) : Bool :=
  let char : Ty → Bool := fun | .int _ _ 8 => true | _ => false
  char a || char b || match env.leaves a, env.leaves b with
    | some xs, some ys => xs.any ys.contains
    | _, _ => true

private def boundaryOf (env : Env) (qual : String) (ty : Ty) : String :=
  if strip qual == "size_t" then "USize" else env.lean ty

private def annotation (attr : Node) : Option (Array String) := do
  guard (attr.kind == "AnnotateAttr")
  attr.children.mapM fun expr => do
    let literal ← expr.walk.find? (·.kind == "StringLiteral")
    let .ok (.str value) := Json.parse (literal.string "value") | none
    return value

private def annotations (node : Node) (kind : String) : Array (Array String) :=
  node.children.filterMap fun attr => do
    let args ← annotation attr
    guard (args[0]? == some kind)
    return args.extract 1 args.size

private def tagId (node : Node) : Option String := do
  let info ← node.get? "ownedTagDecl" <|> node.get? "decl"
  guard ((info.getObjValAs? String "kind").toOption |>.any (["RecordDecl", "EnumDecl"].contains ·))
  (info.getObjValAs? String "id").toOption

private def leanPath (name : String) : String :=
  if name.contains '«' then name else ".".intercalate ((name.splitOn ".").map leanIdent)

private def leanName (node : Node) : Option String :=
  (annotations node "lean")[0]? >>= (·[0]?)

private def readEnum (node : Node) : Option Enum := do
  let constants := node.children.filter (·.kind == "EnumConstantDecl")
  let mut values := #[]
  let mut next : Int := 0
  for c in constants do
    let value ← match c.children.find? (·.kind == "ConstantExpr") with
      | some init => (init.string "value").toInt?
      | none => some next
    values := values.push value
    next := value + 1
  let underlying ← if values.all (fun v => 0 ≤ v ∧ v < 2 ^ 32) then some (intTy "UInt32")
    else if values.all (fun v => -(2 ^ 31) ≤ v ∧ v < 2 ^ 31) then some (intTy "Int32") else none
  let lean := (leanName node).map leanPath |>.getD ""
  let ctors := constants.filterMap leanName
  if !lean.isEmpty then
    guard (ctors.size == constants.size && values == (Array.range values.size).map Int.ofNat)
  return {lean, ctors, count := constants.size, underlying}

def readRecords (nodes : Array Node) : Env := Id.run do
  let mut env : Env := {}
  for node in nodes do
    if node.kind != "EnumDecl" then continue
    let some info := readEnum node | continue
    let id := node.string "id"
    let tag := node.string "name"
    unless tag.isEmpty do env := {env with names := env.names.insert s!"enum {tag}" id}
    env := {env with enums := env.enums.insert id info}
    let mut next : Int := 0
    for c in node.children.filter (·.kind == "EnumConstantDecl") do
      let value := ((c.children.find? (·.kind == "ConstantExpr")).bind fun (e : Node) => (e.string "value").toInt?).getD next
      env := {env with enumerators := env.enumerators.insert (c.string "id") value}
      next := value + 1
  let mut tagged : Array (String × Node × String) := #[]
  let mut variants : Array (String × Node) := #[]
  let mut structs : Std.HashMap String Node := {}
  for node in nodes do
    if node.kind != "RecordDecl" || (node.get? "completeDefinition") != some (.bool true) ||
        node.string "tagUsed" != "struct" then continue
    let id := node.string "id"
    let tag := node.string "name"
    structs := structs.insert id node
    unless tag.isEmpty do env := {env with names := env.names.insert s!"struct {tag}" id}
    let isVariant := node.children.any (fun c => c.kind == "RecordDecl" && c.string "tagUsed" == "union") &&
      node.children.any (fun c => c.kind == "FieldDecl" && c.string "name" == "tag")
    if let (some name, true) := (leanName node, isVariant) then
      variants := variants.push (id, node)
      env := {env with variants := env.variants.insert id {lean := leanPath name, ctors := 0, members := {}}}
    else if let some #[name] := (annotations node "lean")[0]? then
      tagged := tagged.push (id, node, leanPath name)
    else if (annotations node "struct").size == 1 then
      tagged := tagged.push (id, node, if cIdentifier tag then leanIdent tag else "")
  let mut aliases : Std.HashMap String (Array String) := {}
  for node in nodes do
    if node.kind != "TypedefDecl" then continue
    let byTag := env.names[strip node.typeName]?
    let some id := byTag <|> (node.walk.filterMap tagId).findSome? fun id =>
      if tagged.any (·.1 == id) || env.enums.contains id || structs.contains id then some id else none | continue
    let name := node.string "name"
    env := {env with names := env.names.insert name id}
    aliases := aliases.insert id ((aliases[id]?.getD #[]).push name)
  for (id, _, lean) in tagged do
    let lean := if lean.isEmpty then
        ((((aliases[id]?.getD #[]).filter cIdentifier).qsort (· < ·))[0]?.map leanIdent).getD ""
      else lean
    unless lean.isEmpty do env := {env with records := env.records.insert id {lean, fields := {}}}
  for (id, node, _) in tagged do
    let some record := env.records[id]? | continue
    let mut fields := {}
    for field in node.children.filter (·.kind == "FieldDecl") do
      let name := field.string "name"
      let leanName := ((annotations field "lean")[0]?.bind (·[0]?)).getD name
      let qual := field.typeName
      let ty := if (field.get? "isBitfield") == some (.bool true) then none
        else env.resolve qual (field.typeName "desugaredQualType")
      let boundary := ty.map (boundaryOf env qual) |>.getD ""
      fields := fields.insert name {lean := leanIdent leanName, ty, boundary}
    env := {env with records := env.records.insert id {record with fields}}
  for (id, node) in variants do
    let some variant := env.variants[id]? | continue
    let tagEnum := (node.children.find? fun c => c.kind == "FieldDecl" && c.string "name" == "tag").bind fun f =>
      env.names[strip (f.typeName "desugaredQualType")]? <|> env.names[strip f.typeName]?
    let ctors := (tagEnum.bind (env.enums[·]?)).map (·.count) |>.getD 0
    let tag := (node.children.find? fun c => c.kind == "FieldDecl" && c.string "name" == "tag").bind fun f =>
      env.resolve f.typeName (f.typeName "desugaredQualType")
    let mut members := {}
    for union in node.children.filter (fun c => c.kind == "RecordDecl" && c.string "tagUsed" == "union") do
      for member in union.children.filter (·.kind == "FieldDecl") do
        let some ctor := leanName member | continue
        let some payload := env.names[strip (member.typeName "desugaredQualType")]? <|>
          env.names[strip member.typeName]? | continue
        let some payloadNode := structs[payload]? | continue
        let mut fields := {}
        for field in payloadNode.children.filter (·.kind == "FieldDecl") do
          let some key := leanName field | continue
          let qual := field.typeName
          let ty := env.resolve qual (field.typeName "desugaredQualType")
          let boundary := ty.map (boundaryOf env qual) |>.getD ""
          fields := fields.insert (field.string "name") {lean := key, ty, boundary}
        members := members.insert (member.string "name") {ctor, fields}
    env := {env with variants := env.variants.insert id {variant with ctors, members, tag}}
  return env

structure Code where
  text : String
  ty : Ty
  lifts : Bool := false
  bool : Option String := none
  prop : Option String := none
  literal : Option Int := none
  deriving Inhabited

inductive Context where
  | loop
  | switch
  deriving BEq

structure Local where
  lean : String
  ty : Ty
  array : Option (Ty × String) := none
  length : Option String := none
  deriving Inhabited

structure State where
  lines : Array String := #[]
  depth : Nat := 1
  fallible : Bool := false
  locals : Std.HashMap String Local := {}
  used : Std.HashSet String := {}
  counter : Nat := 0
  contexts : List Context := []
  out : Option Local := none
  outCall : Bool := false
  assigned : Std.HashSet String := {}
  lastLet : Bool := false
  result : Result := .value .unit "Unit"

abbrev M := StateT State (ReaderT Env (Except Problem))

private def fail (node : Node) (reason : String) : M α :=
  throw {location := node.location, reason}

private def emit (line : String) : M Unit :=
  modify fun s => {s with
    lines := s.lines.push (String.ofList (List.replicate (2 * s.depth) ' ') ++ line), lastLet := false}

private def indented (body : M α) : M α := do
  modify fun s => {s with depth := s.depth + 1}
  let result ← body
  modify fun s => {s with depth := s.depth - 1}
  return result

private def fresh (base : String) : M String := do
  modify fun s => {s with counter := s.counter + 1}
  return leanIdent s!"{base}#{(← get).counter}"

private def localName (name : String) : M String := do
  let s ← get
  let mut candidate := name
  let mut i := 0
  while s.used.contains candidate do
    i := i + 1
    candidate := s!"{name}'{i}"
  modify fun s => {s with used := s.used.insert candidate}
  return leanIdent candidate

private def lift (text : String) : M String := do
  modify fun s => {s with fallible := true}
  return s!"(← {text})"

private def child (node : Node) (i : Nat) : M Node := do
  let some c := node.children[i]? | fail node s!"malformed {node.kind}"
  return c

private def resolve (node : Node) (qual : String) (desugared : String := "") : M Ty := do
  if strip qual == "lf_status" then return .status
  let some ty := (← read).resolve qual desugared | fail node s!"unsupported type '{qual}'"
  if ty == .unit then fail node "unsupported type 'void'"
  return ty

private def nodeTy (node : Node) : M Ty :=
  resolve node node.typeName (node.typeName "desugaredQualType")

private def leanOf (ty : Ty) : M String := return (← read).lean ty

private def castCode (node : Node) (code : Code) (to : Ty) : M Code := do
  if code.ty == to then return code
  if code.ty == .status || to == .status then fail node "lf_status used as an integer"
  let target ← leanOf to
  match code.ty, to with
  | .int .., .int _ signed width =>
    let lower : Int := if signed then -(2 ^ (width - 1)) else 0
    let upper : Int := if signed then 2 ^ (width - 1) else 2 ^ width
    if let some value := code.literal then
      if lower ≤ value ∧ value < upper then
        return {code with text := s!"({value} : {target})", ty := to}
    return {code with text := s!"(C.cast {code.text} : {target})", ty := to, prop := none, literal := none}
  | .bool, .int .. =>
    return {code with text := s!"(C.cast {code.text} : {target})", ty := to, bool := some code.text, literal := none}
  | .int .., .bool | .double, .bool =>
    let literal := code.literal.map fun value => if value == 0 then "false" else "true"
    let text := (code.bool <|> literal).getD s!"(C.cast {code.text} : Bool)"
    return {code with text, ty := .bool, bool := some text, literal := none}
  | .int .., .double | .bool, .double =>
    return {code with text := s!"(C.cast {code.text} : Float)", ty := to, bool := none, prop := none, literal := none}
  | .double, .int .. =>
    return {text := ← lift s!"(C.floatToInt {code.text} : C.M {target})", ty := to, lifts := true}
  | .enum _, .int .. =>
    return {code with text := s!"(C.IntType.ofInt (Int.ofNat {code.text}.ctorIdx) : {target})", ty := to, literal := none}
  | .enum _, .bool =>
    let text := s!"({code.text}.ctorIdx != 0)"
    return {code with text, ty := .bool, bool := some text, literal := none}
  | .int .., .enum key =>
    let some info := (← read).enums[key]? | fail node "unknown enum"
    let some value := code.literal | fail node s!"conversion from an integer to enum '{node.typeName}'"
    let some ctor := (if value < 0 then none else info.ctors[value.toNat]?)
      | fail node s!"value {value} has no constructor in enum '{node.typeName}'"
    return {text := s!"{info.lean}.{leanIdent ctor}", ty := to, lifts := code.lifts}
  | _, _ => fail node "unsupported conversion"

private def boolOf (node : Node) (code : Code) : M String := do
  return (← castCode node code .bool).text

private def condition (node : Node) (code : Code) : M String := do
  if let some prop := code.prop then return prop
  boolOf node code

private partial def literalValue (node : Node) : Option Int :=
  match node.kind with
  | "IntegerLiteral" => (node.string "value").toNat?.map Int.ofNat
  | "ParenExpr" | "ConstantExpr" | "ImplicitCastExpr" => node.children[0]? >>= literalValue
  | "UnaryOperator" =>
    if node.string "opcode" == "-" then (node.children[0]? >>= literalValue).map (- ·) else none
  | _ => none

private def boundaryIn (code : String) (boundary : String) (ty : Ty) : M String := do
  if boundary == (← leanOf ty) then return code
  return s!"(C.cast {code} : {← leanOf ty})"

private def boundaryOut (code : String) (boundary : String) (ty : Ty) : M String := do
  if boundary == (← leanOf ty) then return code
  return s!"(C.cast {code} : {boundary})"

private def truth (bool : String) (prop : Option String := none) : Code :=
  {text := s!"(C.cast {bool} : Int32)", ty := intTy "Int32", bool := some bool, prop}



private partial def stripCasts (node : Node) : Node :=
  if ["ImplicitCastExpr", "ParenExpr", "ConstantExpr"].contains node.kind then
    match node.children[0]? with
    | some c => stripCasts c
    | none => node
  else node

private def referenced (node : Node) : Option (String × String × String) := do
  guard (node.kind == "DeclRefExpr")
  let decl ← node.get? "referencedDecl"
  let id ← (decl.getObjValAs? String "id").toOption
  let kind ← (decl.getObjValAs? String "kind").toOption
  let name := ((decl.getObjValAs? String "name").toOption).getD ""
  return (id, kind, name)

private def statusName (node : Node) : Option String := do
  let (_, kind, name) ← referenced (stripCasts node)
  guard (kind == "EnumConstantDecl")
  [("LF_OK", "ok"), ("LF_INVALID", "invalid"), ("LF_EXCEPT", "except"), ("LF_IO", "io"),
    ("LF_NOT_INITIALIZED", "notInitialized")].lookup name

private def isStatus (node : Node) : Bool :=
  (statusName node).isSome || strip node.typeName == "lf_status"

private def arith (node : Node) (op : String) (ty : Ty) (a b : Code) : M Code := do
  let lifted := a.lifts || b.lifts
  let pure' (text : String) : Code := {text, ty, lifts := lifted}
  match ty, op with
  | .int _ true _, "+" => return {pure' (← lift s!"C.addS {a.text} {b.text}") with lifts := true}
  | .int _ true _, "-" => return {pure' (← lift s!"C.subS {a.text} {b.text}") with lifts := true}
  | .int _ true _, "*" => return {pure' (← lift s!"C.mulS {a.text} {b.text}") with lifts := true}
  | .int _ false _, "+" | .double, "+" => return pure' s!"({a.text} + {b.text})"
  | .int _ false _, "-" | .double, "-" => return pure' s!"({a.text} - {b.text})"
  | .int _ false _, "*" | .double, "*" => return pure' s!"({a.text} * {b.text})"
  | .int .., "/" => return {pure' (← lift s!"C.div {a.text} {b.text}") with lifts := true}
  | .int .., "%" => return {pure' (← lift s!"C.mod {a.text} {b.text}") with lifts := true}
  | .double, "/" => return pure' s!"({a.text} / {b.text})"
  | .int .., "<<" =>
    return {pure' (← lift s!"C.shl {a.text} (C.IntType.toInt {b.text})") with lifts := true}
  | .int .., ">>" =>
    return {pure' (← lift s!"C.shr {a.text} (C.IntType.toInt {b.text})") with lifts := true}
  | .int .., "&" => return pure' s!"({a.text} &&& {b.text})"
  | .int .., "|" => return pure' s!"({a.text} ||| {b.text})"
  | .int .., "^" => return pure' s!"({a.text} ^^^ {b.text})"
  | _, _ => fail node s!"unsupported operator '{op}'"

private def promoted (ty : Ty) : Ty :=
  match ty with
  | .int _ _ width => if width < 32 then intTy "Int32" else ty
  | _ => ty

mutual

private partial def expr (node : Node) : M Code := do
  match node.kind with
  | "ParenExpr" | "ConstantExpr" =>
    let inner ← expr (← child node 0)
    return {inner with text := inner.text}
  | "ImplicitCastExpr" | "CStyleCastExpr" => cast node
  | "IntegerLiteral" =>
    let ty ← nodeTy node
    return {text := s!"({node.string "value"} : {← leanOf ty})", ty, literal := (node.string "value").toNat?.map Int.ofNat}
  | "FloatingLiteral" =>
    let ty ← nodeTy node
    let value := node.string "value"
    unless ty == .double && value.toList.all (fun c => c.isDigit || ".eE+-".contains c) &&
        value.toList.any Char.isDigit do
      fail node s!"unsupported floating-point literal '{value}'"
    let value := if value.contains '.' || value.contains 'e' || value.contains 'E' then value
      else value ++ ".0"
    return {text := s!"({value} : Float)", ty}
  | "DeclRefExpr" =>
    let some (id, kind, name) := referenced node | fail node "malformed reference"
    if let some status := statusName node then return {text := s!"C.Status.{status}", ty := .status}
    if kind == "EnumConstantDecl" then
      let some value := (← read).enumerators[id]? | fail node s!"enumerator '{name}' without a value"
      let ty ← nodeTy node
      return {text := s!"({value} : {← leanOf ty})", ty, literal := some value}
    if kind == "ParmVarDecl" || kind == "VarDecl" then
      let some var := (← get).locals[id]? | fail node s!"global variable '{name}'"
      if var.array.isSome then fail node s!"array '{name}' used as a value"
      if (← get).out.any (·.lean == var.lean) then fail node "reading the out parameter"
      return {text := var.lean, ty := var.ty}
    fail node s!"unsupported reference to {kind} '{name}'"
  | "BinaryOperator" => binary node
  | "UnaryOperator" => unary node
  | "ConditionalOperator" =>
    let cond ← expr (← child node 0)
    let c ← condition node cond
    let a ← expr (← child node 1)
    let b ← expr (← child node 2)
    let ty ← nodeTy node
    if a.lifts || b.lifts then
      let text ← lift s!"(if {c} then (do pure {a.text}) else (do pure {b.text}) : C.M {← leanOf ty})"
      return {text, ty, lifts := true}
    return {text := s!"(if {c} then {a.text} else {b.text})", ty, lifts := cond.lifts}
  | "ArraySubscriptExpr" =>
    let base := stripCasts (← child node 0)
    if base.kind == "StringLiteral" then fail base "string literal"
    let some (id, _, name) := referenced base | fail node "array subscript of a non-parameter"
    let some {lean, array := some (elem, boundary), ..} := (← get).locals[id]?
      | fail node s!"subscript of '{name}', which is not an LF_ARRAY parameter"
    let index ← expr (← child node 1)
    let read ← lift s!"C.index {lean} (C.IntType.toInt {index.text})"
    return {text := ← boundaryIn read boundary elem, ty := elem, lifts := true}
  | "MemberExpr" =>
    if (node.get? "isArrow") == some (.bool true) then fail node "member access through a pointer"
    let base ← expr (← child node 0)
    let member := node.string "name"
    match base.ty with
    | .variant key =>
      if member == "tag" then
        let ty ← nodeTy node
        return {text := s!"(C.IntType.ofInt (Int.ofNat {base.text}.ctorIdx) : {← leanOf ty})", ty, lifts := base.lifts}
      if member == "as" then return {base with ty := .members key}
      fail node s!"unknown member '{member}' of a tagged union"
    | .members key => return {base with ty := .payload key member}
    | .payload key m =>
      let some variant := (← read).variants[key]? | fail node "unknown tagged union"
      let some info := variant.members[m]? | fail node s!"unknown constructor member '{m}'"
      let some field := info.fields[member]? | fail node s!"unknown field '{member}'"
      let some ty := field.ty | fail node s!"unsupported type of field '{member}'"
      let var ← fresh "field"
      let args := if field.lean.startsWith "#" then
          String.join (List.replicate (field.lean.drop 1).toString.toNat! "_ ") ++ var
        else s!"({leanIdent field.lean} := {var})"
      let other := if variant.ctors > 1 then " | _ => throw C.Exc.inactiveMember" else ""
      let read' ← lift s!"(match {base.text} with | {variant.lean}.{leanIdent info.ctor} {args} .. => pure {var}{other} : C.M {field.boundary})"
      return {text := ← boundaryIn read' field.boundary ty, ty, lifts := true}
    | _ => pure ()
    let .record key := base.ty | fail node "member access on a non-struct value"
    let some record := (← read).records[key]? | fail node "unknown struct"
    let some field := record.fields[node.string "name"]?
      | fail node s!"unknown field '{node.string "name"}'"
    let some ty := field.ty | fail node s!"unsupported type of field '{node.string "name"}'"
    let text ← boundaryIn s!"{base.text}.{field.lean}" field.boundary ty
    return {text, ty, lifts := base.lifts}
  | "CallExpr" => call node
  | "StringLiteral" => fail node "string literal"
  | kind => fail node s!"unsupported expression {kind}"

private partial def cast (node : Node) : M Code := do
  let inner ← child node 0
  match node.string "castKind" with
  | "LValueToRValue" | "NoOp" => expr inner
  | "IntegralCast" | "IntegralToBoolean" | "IntegralToFloating" | "FloatingToIntegral"
  | "FloatingToBoolean" | "FloatingCast" =>
    let to ← nodeTy node
    castCode node (← expr inner) to
  | kind => fail node s!"unsupported conversion {kind}"

private partial def binary (node : Node) : M Code := do
  let op := node.string "opcode"
  if op == "=" then fail node "assignment used as a value"
  if op == "," then fail node "comma operator"
  if op == "&&" || op == "||" then
    let a ← expr (← child node 0)
    let b ← expr (← child node 1)
    let aBool ← boolOf node a
    let bBool ← boolOf node b
    if b.lifts then
      let fn := if op == "&&" then "C.andThen" else "C.orElse"
      let text ← lift s!"{fn} {aBool} (fun () => do pure {bBool})"
      return {truth text with lifts := true}
    let bool := if op == "&&" then s!"({aBool} && {bBool})" else s!"({aBool} || {bBool})"
    let prop := match a.prop, b.prop with
      | some pa, some pb => some (if op == "&&" then s!"({pa} ∧ {pb})" else s!"({pa} ∨ {pb})")
      | _, _ => none
    return {truth bool prop with lifts := a.lifts}
  if op == "==" || op == "!=" then
    let sa := stripCasts (← child node 0)
    let sb := stripCasts (← child node 1)
    if isStatus sa || isStatus sb then
      let a ← expr sa
      let b ← expr sb
      unless a.ty == .status && b.ty == .status do fail node "lf_status compared with an integer"
      let prop := if op == "==" then s!"({a.text} = {b.text})" else s!"({a.text} ≠ {b.text})"
      return {truth s!"(decide {prop})" (some prop) with lifts := a.lifts || b.lifts}
  let a ← expr (← child node 0)
  let b ← expr (← child node 1)
  if ["<", "<=", ">", ">=", "==", "!="].contains op then
    let lifts := a.lifts || b.lifts
    let rel := [("<", "<"), ("<=", "≤"), (">", ">"), (">=", "≥")].lookup op
    if let some rel := rel then
      let prop := s!"({a.text} {rel} {b.text})"
      return {truth s!"(decide {prop})" (some prop) with lifts}
    if a.ty == .double then
      let bool := if op == "==" then s!"({a.text} == {b.text})" else s!"({a.text} != {b.text})"
      return {truth bool with lifts}
    let prop := if op == "==" then s!"({a.text} = {b.text})" else s!"({a.text} ≠ {b.text})"
    return {truth s!"(decide {prop})" (some prop) with lifts}
  arith node op (← nodeTy node) a b

private partial def unary (node : Node) : M Code := do
  let op := node.string "opcode"
  let operand ← child node 0
  match op with
  | "-" =>
    let ty ← nodeTy node
    let literal := stripCasts operand
    if literal.kind == "IntegerLiteral" && operand.kind != "ImplicitCastExpr" then
      if let .int _ true width := ty then
        let value := (literal.string "value").toNat!
        if value ≤ 2 ^ (width - 1) then
          return {text := s!"(-{value} : {← leanOf ty})", ty, literal := some (-(Int.ofNat value))}
    let a ← expr operand
    match ty with
    | .int _ true _ => return {text := ← lift s!"C.negS {a.text}", ty, lifts := true}
    | .int .. | .double => return {a with text := s!"(-{a.text})", bool := none, prop := none, literal := none}
    | _ => fail node "unsupported operand of '-'"
  | "+" => expr operand
  | "~" =>
    let a ← expr operand
    let .int .. := a.ty | fail node "unsupported operand of '~'"
    return {a with text := s!"(~~~{a.text})", bool := none, prop := none, literal := none}
  | "!" =>
    let a ← expr operand
    let bool ← boolOf node a
    return {truth s!"(!{bool})" (a.prop.map (s!"(¬{·})")) with lifts := a.lifts}
  | "++" | "--" => fail node s!"'{op}' used as a value"
  | "&" => fail node "address-of operator"
  | "*" => fail node "pointer dereference"
  | _ => fail node s!"unsupported operator '{op}'"

private partial def arrayArg (node : Node) (elem : Ty) (boundary : String) : M Local := do
  let arg := stripCasts node
  let some (id, _, name) := referenced arg | fail node "array argument other than an LF_ARRAY parameter"
  let some var := (← get).locals[id]? | fail node s!"array argument '{name}' is a global variable"
  let some (elem', boundary') := var.array
    | fail node s!"array argument '{name}', which is not an LF_ARRAY parameter"
  unless elem' == elem && boundary' == boundary do
    fail node s!"array argument '{name}' of a different element type"
  return var

private partial def lengthArg (node : Node) (array : Local) (param : Param) : M String := do
  if let some (id, _, _) := referenced (stripCasts node) then
    if let some var := (← get).locals[id]? then
      if var.length == some array.lean && !(← get).assigned.contains id then return array.lean
  let n ← castCode node (← expr node) param.ty
  lift s!"C.arrayPrefix {array.lean} (C.IntType.toInt {n.text})"

private partial def outArg (node : Node) (ty : Ty) : M Local := do
  let arg := stripCasts node
  if let some (id, _, _) := referenced arg then
    if let some out := (← get).out then
      if (← get).locals[id]?.any (·.lean == out.lean) then
        unless out.ty == ty do fail node "out argument of a different type"
        return out
    fail node "out argument other than the address of a local variable"
  unless arg.kind == "UnaryOperator" && arg.string "opcode" == "&" do
    fail node "out argument other than the address of a local variable"
  let some (id, _, name) := referenced (stripCasts (← child arg 0))
    | fail node "out argument other than the address of a local variable"
  let some var := (← get).locals[id]? | fail node s!"out argument '{name}' is a global variable"
  if var.array.isSome || (← get).out.any (·.lean == var.lean) then
    fail node "out argument other than the address of a local variable"
  unless var.ty == ty do fail node s!"out argument '{name}' of a different type"
  return var

private partial def call (node : Node) : M Code := do
  let callee := stripCasts (← child node 0)
  let some (_, "FunctionDecl", name) := referenced callee | fail node "indirect call"
  let some fn := (← read).functions[name]?
    | fail node (if (← read).defined.contains name then s!"call to unextracted function '{name}'"
        else s!"call to '{name}', which has no definition in this file")
  let outCall := (← get).outCall
  modify fun s => {s with outCall := false}
  if let .status .. := fn.result then
    unless outCall do fail node s!"call to '{name}', which returns lf_status, inside an expression"
  let mut args := #[]
  let mut lifts := false
  let mut out : Option Local := none
  for (param, i) in fn.params.zipIdx do
    let argNode ← child node (i + 1)
    match param.kind with
    | .value =>
      let arg ← expr argNode
      lifts := lifts || arg.lifts
      args := args.push (← boundaryOut arg.text param.boundary param.ty)
    | .array elem boundary length =>
      let array ← arrayArg argNode elem boundary
      let some j := fn.params.findIdx? (·.name == length) | fail node s!"malformed call to '{name}'"
      let text ← lengthArg (← child node (j + 1)) array fn.params[j]!
      lifts := lifts || text != array.lean
      args := args.push text
    | .length _ => pure ()
    | .out => out := some (← outArg argNode param.ty)
  let applied := if args.isEmpty then fn.lean else s!"{fn.lean} {" ".intercalate args.toList}"
  match fn.result with
  | .value ty boundary =>
    if fn.fallible then
      let text ← boundaryIn (← lift applied) boundary ty
      return {text, ty, lifts := true}
    let text ← boundaryIn s!"({applied})" boundary ty
    return {text, ty, lifts}
  | .status ty boundary =>
    let some var := out | fail node s!"malformed call to '{name}'"
    let r ← fresh "call"
    if fn.fallible then
      modify fun s => {s with fallible := true}
      emit s!"let {r} ← {applied}"
    else emit s!"let {r} := {applied}"
    let v ← fresh "out"
    let value ← boundaryIn v boundary ty
    let callerOut := (← get).out.any (·.lean == var.lean)
    let stored ← if callerOut then
        match (← get).result with
        | .status _ b => pure s!"some {← boundaryOut value b ty}"
        | _ => fail node s!"malformed call to '{name}'"
      else pure value
    emit s!"if let some {v} := {r}.2 then {var.lean} := {stored}"
    return {text := s!"{r}.1", ty := .status}

end

private def topExpr (node : Node) : M Code := do
  let n := stripCasts node
  let compared := n.kind == "BinaryOperator" && ["==", "!="].contains (n.string "opcode") &&
    n.children.any (fun c => (statusName c).isSome) &&
    n.children.any (fun c => (stripCasts c).kind == "CallExpr")
  if n.kind == "CallExpr" || compared then modify fun s => {s with outCall := true}
  let code ← expr node
  modify fun s => {s with outCall := false}
  return code

private def target (node : Node) : M (Local × String) := do
  let node := stripCasts node
  if node.kind == "MemberExpr" then fail node "assignment to a struct field"
  if node.kind == "ArraySubscriptExpr" then fail node "assignment to an array element"
  let some (id, _, name) := referenced node | fail node "unsupported assignment target"
  let some var := (← get).locals[id]? | fail node s!"assignment to global variable '{name}'"
  if var.array.isSome then fail node s!"assignment to array '{name}'"
  return (var, id)

private def assignOut (node : Node) (value : Node) : M Bool := do
  let lhs := stripCasts node
  unless lhs.kind == "UnaryOperator" && lhs.string "opcode" == "*" do return false
  let some out := (← get).out | fail lhs "pointer dereference"
  let some (id, _, _) := referenced (stripCasts (← child lhs 0)) | fail lhs "pointer dereference"
  unless (← get).locals[id]?.any (·.lean == out.lean) do fail lhs "pointer dereference"
  let v ← castCode value (← expr value) out.ty
  let .status _ boundary := (← get).result | fail lhs "pointer dereference"
  emit s!"{out.lean} := some {← boundaryOut v.text boundary out.ty}"
  return true

private def update (node : Node) (var : Local) (opTy : Ty) (op : String) (rhs : Code) : M Unit := do
  let current ← castCode node {text := var.lean, ty := var.ty} opTy
  let result ← arith node op opTy current rhs
  let value ← castCode node result var.ty
  emit s!"{var.lean} := {value.text}"

private partial def alwaysReturns (node : Node) : Bool :=
  match node.kind with
  | "ReturnStmt" => true
  | "CompoundStmt" =>
    match (node.children.filter (·.kind != "NullStmt")).back? with
    | some last => alwaysReturns last
    | none => false
  | "IfStmt" =>
    (node.get? "hasElse") == some (.bool true) && node.children.size == 3 &&
      alwaysReturns node.children[1]! && alwaysReturns node.children[2]!
  | "SwitchStmt" =>
    match node.children[1]? with
    | some body =>
      let items := if body.kind == "CompoundStmt" then body.children else #[body]
      let isLabel := fun (n : Node) => n.kind == "CaseStmt" || n.kind == "DefaultStmt"
      let rec inner (fuel : Nat) (n : Node) : Node × Bool :=
        match fuel with
        | 0 => (n, false)
        | fuel + 1 =>
          if n.kind == "CaseStmt" then inner fuel (n.children[1]?.getD n)
          else if n.kind == "DefaultStmt" then ((inner fuel (n.children[0]?.getD n)).1, true)
          else (n, false)
      let hasDefault := items.any fun n => isLabel n && (inner 64 n).2
      let ends := items.zipIdx.filter fun (_, i) => i + 1 == items.size || isLabel items[i + 1]!
      hasDefault && !items.isEmpty && ends.all fun (n, _) => alwaysReturns (inner 64 n).1
    | none => false
  | _ => false

mutual

private partial def block (nodes : Array Node) : M Unit := do
  let before := (← get).lines.size
  for node in nodes do stmt node
  if (← get).lines.size == before || (← get).lastLet then emit "pure ()"

private partial def body (node : Node) : M Unit := indented do
  if node.kind == "CompoundStmt" then block node.children else block #[node]

private partial def loop (header : M Unit) (node : Node) : M Unit := do
  modify fun s => {s with fallible := true, contexts := .loop :: s.contexts}
  emit "for _ in C.Loop.forever do"
  indented do
    header
    block (if node.kind == "CompoundStmt" then node.children else #[node])
  modify fun s => {s with contexts := s.contexts.tail}

private partial def stmt (node : Node) : M Unit := do
  match node.kind with
  | "NullStmt" => pure ()
  | "CompoundStmt" =>
    emit "do"
    body node
  | "DeclStmt" =>
    for decl in node.children do
      unless decl.kind == "VarDecl" do fail decl s!"unsupported declaration {decl.kind}"
      let name := decl.string "name"
      unless (decl.string "storageClass").isEmpty do
        fail decl s!"'{decl.string "storageClass"}' local variable '{name}'"
      let some init := decl.children.find? (·.kind != "AnnotateAttr")
        | fail decl s!"local variable '{name}' without an initializer"
      let id := decl.string "id"
      if let some self := init.walk.find? fun n => (referenced n).any (·.1 == id) then
        fail self s!"'{name}' read in its own initializer"
      let ty ← resolve decl decl.typeName (decl.typeName "desugaredQualType")
      let value ← castCode init (← topExpr init) ty
      let lean ← localName name
      modify fun s => {s with locals := s.locals.insert id {lean, ty}}
      let keyword := if (← get).assigned.contains id then "let mut" else "let"
      emit s!"{keyword} {lean} : {← leanOf ty} := {value.text}"
      modify fun s => {s with lastLet := true}
  | "ReturnStmt" =>
    if let some out := (← get).out then
      let some value := node.children[0]? | fail node "return without a status"
      let code ← topExpr value
      unless code.ty == .status do fail value "lf_status return other than an lf_status value"
      emit s!"return ({code.text}, {out.lean})"
    else
      match node.children[0]? with
      | none => emit "return ()"
      | some value =>
        let .value ty boundary := (← get).result | fail node "return in a status function"
        let code ← castCode value (← expr value) ty
        emit s!"return {← boundaryOut code.text boundary ty}"
  | "IfStmt" =>
    let c ← condition node (← topExpr (← child node 0))
    emit s!"if {c} then"
    body (← child node 1)
    if let some other := node.children[2]? then
      emit "else"
      body other
  | "WhileStmt" =>
    let cond ← child node 0
    loop (do emit s!"unless {← condition cond (← topExpr cond)} do break") (← child node 1)
  | "DoStmt" =>
    let cond ← child node 1
    let first ← fresh "first"
    emit s!"let mut {first} := true"
    loop (do
      emit s!"if {first} then"
      indented (emit s!"{first} := false")
      emit "else"
      indented (emit s!"unless {← condition cond (← topExpr cond)} do break")) (← child node 0)
  | "ForStmt" =>
    let parts := node.children
    unless parts.size == 5 do fail node "malformed for statement"
    if parts[1]!.kind != "" then fail parts[1]! "declaration in a for condition"
    if parts[0]!.kind != "" then stmt parts[0]!
    let inc := parts[3]!
    let first ← if inc.kind != "" then
        let first ← fresh "first"
        emit s!"let mut {first} := true"
        pure (some first)
      else pure none
    loop (do
      if let some first := first then
        emit s!"if {first} then"
        indented (emit s!"{first} := false")
        emit "else"
        indented (stmt inc)
      if parts[2]!.kind != "" then
        let cond := parts[2]!
        emit s!"unless {← condition cond (← topExpr cond)} do break") parts[4]!
  | "SwitchStmt" => switch node
  | "BreakStmt" =>
    match (← get).contexts with
    | .loop :: _ => emit "break"
    | _ => fail node "break inside a switch case before its end"
  | "ContinueStmt" =>
    unless (← get).contexts.contains .loop do fail node "continue outside a loop"
    emit "continue"
  | "GotoStmt" => fail node "goto"
  | "LabelStmt" => fail node "label"
  | "BinaryOperator" =>
    unless node.string "opcode" == "=" do fail node s!"unsupported statement '{node.string "opcode"}'"
    let lhs ← child node 0
    let rhs ← child node 1
    if ← assignOut lhs rhs then return
    let (var, _) ← target lhs
    let value ← castCode rhs (← topExpr rhs) var.ty
    emit s!"{var.lean} := {value.text}"
  | "CompoundAssignOperator" =>
    let (var, _) ← target (← child node 0)
    let opTy ← resolve node (((node.get? "computeLHSType").getD .null).getObjValAs? String "qualType"
      |>.toOption.getD "")
    let op := (node.string "opcode").dropEnd 1 |>.toString
    let rhs ← expr (← child node 1)
    update node var opTy op rhs
  | "UnaryOperator" =>
    let op := node.string "opcode"
    unless op == "++" || op == "--" do fail node s!"unsupported statement '{op}'"
    let (var, _) ← target (← child node 0)
    let opTy := promoted var.ty
    let one ← match opTy with
      | .int lean .. => pure s!"(1 : {lean})"
      | .double => pure "(1.0 : Float)"
      | _ => fail node s!"'{op}' on a non-arithmetic variable"
    update node var opTy (if op == "++" then "+" else "-") {text := one, ty := opTy}
  | "CallExpr" =>
    let code ← topExpr node
    if code.lifts then emit s!"let _ := {code.text}"
  | "ParenExpr" => stmt (← child node 0)
  | kind => fail node s!"unsupported statement {kind}"

private partial def switch (node : Node) : M Unit := do
  let scrutinee ← expr (← child node 0)
  let .int .. := scrutinee.ty | fail node "switch on a non-integer value"
  let name ← fresh "switch"
  emit s!"let {name} := {scrutinee.text}"
  let bodyNode ← child node 1
  let items := if bodyNode.kind == "CompoundStmt" then bodyNode.children else #[bodyNode]
  let mut groups : Array (Array (Option Node) × Array Node) := #[]
  for item in items do
    let mut labels := #[]
    let mut current := item
    while current.kind == "CaseStmt" || current.kind == "DefaultStmt" do
      if current.kind == "CaseStmt" then
        labels := labels.push (some (← child current 0))
        current ← child current 1
      else
        labels := labels.push none
        current ← child current 0
    if labels.isEmpty then
      let some (labels', stmts) := groups.back? | fail item "statement before the first case"
      groups := groups.pop.push (labels', stmts.push current)
    else
      if let some (_, stmts) := groups.back? then
        unless stmts.back?.any (fun s => ["BreakStmt", "ReturnStmt", "ContinueStmt"].contains s.kind) do
          fail item "switch fallthrough"
      groups := groups.push (labels, #[current])
  let defaults := groups.filter (·.1.any Option.isNone)
  let cases := groups.filter (·.1.all Option.isSome)
  modify fun s => {s with contexts := .switch :: s.contexts}
  let emitGroup (stmts : Array Node) : M Unit := indented do
    let stmts := if stmts.back?.any (·.kind == "BreakStmt") then stmts.pop else stmts
    block stmts
  let mut first := true
  for (labels, stmts) in cases do
    let mut tests := #[]
    for label in labels do
      let env ← read
      let enumerator := (label.map stripCasts).bind fun n =>
        (referenced n).bind fun (id, _, _) => env.enumerators[id]?
      let some value := (label.bind literalValue) <|> enumerator
        | fail node "case label that is not an integer literal"
      tests := tests.push s!"{name} = ({value} : {← leanOf scrutinee.ty})"
    emit s!"{if first then "if" else "else if"} {" ∨ ".intercalate tests.toList} then"
    emitGroup stmts
    first := false
  if let some (_, stmts) := defaults[0]? then
    if first then
      emit "do"
      emitGroup stmts
    else
      emit "else"
      emitGroup stmts
  modify fun s => {s with contexts := s.contexts.tail}

end

private def assignedIds (node : Node) : Std.HashSet String :=
  node.walk.foldl (init := {}) fun ids n =>
    let targetNode := match n.kind with
      | "BinaryOperator" => if n.string "opcode" == "=" then n.children[0]? else none
      | "CompoundAssignOperator" => n.children[0]?
      | "UnaryOperator" =>
        if ["++", "--", "&"].contains (n.string "opcode") then n.children[0]? else none
      | _ => none
    match targetNode.bind (referenced ∘ stripCasts) with
    | some (id, _, _) => ids.insert id
    | none => ids

private def functionType (node : Node) : String × String :=
  let split := fun (ty : String) => ((ty.splitOn "(")[0]!).trimAscii.toString
  (split node.typeName, split (node.typeName "desugaredQualType"))

private def translateFunction (node : Node) : M Function := do
  let name := node.string "name"
  if (node.get? "variadic") == some (.bool true) then fail node "variadic function"
  if node.typeName.contains "(*" then fail node "function pointer type"
  let params := node.children.filter (·.kind == "ParmVarDecl")
  let some bodyNode := node.children.find? (·.kind == "CompoundStmt") | fail node "function without a body"
  let (resultQual, resultDesugared) := functionType node
  let isStatus := strip resultQual == "lf_status"
  let mut result : Result := .value .unit "Unit"
  unless isStatus do
    let some ty := (← read).resolve resultQual resultDesugared
      | fail node s!"unsupported result type '{resultQual}'"
    let env ← read
    result := .value ty (if ty == .unit then "Unit" else boundaryOf env resultQual ty)
  let mut out : Array Param := #[]
  let mut restricted : Array String := #[]
  modify fun s => {s with assigned := assignedIds bodyNode}
  for (param, index) in params.zipIdx do
    let pname := param.string "name"
    if pname.isEmpty then fail param "unnamed parameter"
    let qual := param.typeName
    let lean ← localName pname
    let id := param.string "id"
    let pointer := strip qual
    let isRestrict := pointer.endsWith "*restrict"
    let pointer := if isRestrict then (pointer.dropEnd 8).toString else pointer
    if pointer.endsWith "*" then
      if isRestrict then restricted := restricted.push pname
      let pointee := (pointer.dropEnd 1).trimAscii.toString
      let arrays := annotations param "array"
      if let some #[length] := arrays[0]? then
        unless qual.trimAscii.startsWith "const " do fail param s!"LF_ARRAY parameter '{pname}' must point to const"
        let some elem := (← read).resolve pointee | fail param s!"unsupported element type '{pointee}'"
        if elem == .unit then fail param s!"unsupported element type '{pointee}'"
        let boundary := boundaryOf (← read) pointee elem
        out := out.push {name := pname, id, lean, ty := elem, boundary, kind := .array elem boundary length, cType := strip pointee}
      else if isStatus && index + 1 == params.size && !pointee.startsWith "const " then
        let some ty := (← read).resolve pointee | fail param s!"unsupported out type '{pointee}'"
        if ty == .unit then fail param s!"unsupported out type '{pointee}'"
        let boundary := boundaryOf (← read) pointee ty
        result := .status ty boundary
        out := out.push {name := pname, id, lean, ty, boundary, kind := .out, cType := strip pointee}
      else fail param s!"pointer parameter '{pname}'"
    else
      let ty ← resolve param qual (param.typeName "desugaredQualType")
      let boundary := boundaryOf (← read) qual ty
      out := out.push {name := pname, id, lean, ty, boundary, kind := .value, cType := strip qual}
  match out.find? fun p => match p.kind with | .out => true | _ => false with
  | none => if isStatus then fail node "lf_status result without an out parameter"
  | some o =>
    for p in out do
      if let .array elem _ _ := p.kind then
        if (← read).mayOverlap o.ty elem && !restricted.contains p.name && !restricted.contains o.name then
          fail node s!"out parameter '{o.name}' of type '{o.cType} *' may point into LF_ARRAY parameter '{p.name}' of element type '{p.cType}'; declare one of them restrict"
  let mut params := out
  for p in out do
    if let .array _ _ length := p.kind then
      let some i := params.findIdx? (·.name == length)
        | fail node s!"LF_ARRAY({length}) names no parameter"
      let .value := params[i]!.kind | fail node s!"LF_ARRAY({length}) names a non-integer parameter"
      let .int .. := params[i]!.ty | fail node s!"LF_ARRAY({length}) names a non-integer parameter"
      params := params.set! i {params[i]! with kind := .length p.lean}
  for p in params do
    match p.kind with
    | .array elem boundary _ =>
      modify fun s => {s with locals := s.locals.insert p.id {lean := p.lean, ty := elem, array := some (elem, boundary)}}
    | .length array =>
      modify fun s => {s with locals := s.locals.insert p.id {lean := p.lean, ty := p.ty, length := some array}}
      let keyword := if (← get).assigned.contains p.id then "let mut" else "let"
      emit s!"{keyword} {p.lean} : {← leanOf p.ty} := C.IntType.ofInt (Int.ofNat {array}.size)"
    | .out =>
      let var : Local := {lean := p.lean, ty := p.ty}
      modify fun s => {s with locals := s.locals.insert p.id var, out := some var}
      emit s!"let mut {p.lean} : Option {p.boundary} := none"
    | .value =>
      modify fun s => {s with locals := s.locals.insert p.id {lean := p.lean, ty := p.ty}}
      if p.boundary != (← leanOf p.ty) then
        let keyword := if (← get).assigned.contains p.id then "let mut" else "let"
        emit s!"{keyword} {p.lean} : {← leanOf p.ty} := C.cast {p.lean}"
      else if (← get).assigned.contains p.id then
        emit s!"let mut {p.lean} := {p.lean}"
  let returnsValue := match result with | .value .unit _ => false | _ => true
  modify fun s => {s with result}
  block bodyNode.children
  unless alwaysReturns bodyNode do
    if returnsValue then
      modify fun s => {s with fallible := true}
      emit "throw C.Exc.missingReturn"
    else emit "pure ()"
  let st ← get
  let binders := params.filterMap fun p =>
    match p.kind with
    | .value => some s!"({p.lean} : {p.boundary})"
    | .array _ boundary _ => some s!"({p.lean} : Array {boundary})"
    | _ => none
  let resultType ← match result with
    | .value ty boundary => pure (if ty == .unit then "Unit" else boundary)
    | .status _ boundary => pure s!"C.Status × Option {boundary}"
  let lean := leanIdent name
  let header := s!"def {lean}{String.join (binders.toList.map (" " ++ ·))} : "
  let source := if st.fallible then s!"{header}C.M ({resultType}) := do\n"
    else s!"{header}{resultType} := Id.run do\n"
  let resultValue := match result with
    | .value ty boundary => Result.value ty boundary
    | .status ty boundary => Result.status ty boundary
  let source := source ++ "\n".intercalate st.lines.toList ++ "\n"
  return {name := name, lean := lean, params := params, result := resultValue, fallible := st.fallible, source := source, resultType := strip resultQual}

def callees (node : Node) : Array String :=
  (node.walk.filterMap fun n => do
    guard (n.kind == "CallExpr")
    let callee := stripCasts (← n.children[0]?)
    let (_, kind, name) ← referenced callee
    guard (kind == "FunctionDecl")
    return name).toList.eraseDups.toArray

structure Output where
  functions : Array Function
  unextracted : Array (String × Problem)

private partial def visit (byName : Std.HashMap String Node) (name : String) (path : List String) :
    StateM (Array String × Std.HashSet String × Std.HashSet String) Unit := do
  let (_, done, _) ← get
  if done.contains name then return
  if path.contains name then
    let cycle := name :: path.takeWhile (· != name)
    modify fun (order, done, recursive) => (order, done, cycle.foldl (·.insert ·) recursive)
    return
  let some node := byName[name]? | return
  for callee in callees node do
    if byName.contains callee then visit byName callee (name :: path)
  modify fun (order, done, recursive) =>
    if done.contains name then (order, done, recursive) else (order.push name, done.insert name, recursive)

def targetProblem (macros : Std.HashMap String String) : Option String :=
  [("__SIZEOF_SHORT__", "short", "2"), ("__SIZEOF_INT__", "int", "4"), ("__SIZEOF_LONG__", "long", "8"),
    ("__SIZEOF_LONG_LONG__", "long long", "8"), ("__SIZEOF_SIZE_T__", "size_t", "8")].findSome?
    fun (key, name, size) =>
      let actual := macros[key]?.getD "unknown"
      if actual == size then none
      else some s!"the target is not LP64: {name} has {actual} bytes, the translation needs {size}"

private def unsafeFloatFlags : List String :=
  ["-Ofast", "-funsafe-math-optimizations", "-fassociative-math", "-freciprocal-math", "-fno-signed-zeros",
    "-ffinite-math-only", "-fno-honor-nans", "-fno-honor-infinities", "-fapprox-func"]

def floatProblem (flags : Array String) (macros : Std.HashMap String String) : Option String :=
  let contract := (flags.filter (·.startsWith "-ffp-contract=")).back?
  if macros.contains "__FAST_MATH__" then some "compiled with -ffast-math, which changes double results"
  else if let some flag := flags.find? unsafeFloatFlags.contains then
    some s!"compiled with {flag}, which changes double results"
  else if let some flag := contract.filter (· != "-ffp-contract=off") then
    some s!"compiled with {flag}, which can contract double operations"
  else if contract.isNone && (macros.contains "__FP_FAST_FMA" || macros.contains "__FMA__") then
    some "the target has FMA instructions and the flags do not contain -ffp-contract=off"
  else none

def usesDouble (node : Node) : Bool :=
  node.walk.any fun n => (n.typeName.splitOn "double").length > 1 ||
    ((n.typeName "desugaredQualType").splitOn "double").length > 1

def translate (root : Node) (file : FilePath) (directory : FilePath) (target : Option String := none)
    (float : Option String := none) : Output := Id.run do
  let nodes := root.walk
  let mut env := readRecords nodes
  let defs := root.children.filter fun n =>
    n.kind == "FunctionDecl" && n.children.any (·.kind == "CompoundStmt") &&
      absolute directory n.location.file == file
  let byName : Std.HashMap String Node := defs.foldl (init := {}) fun m n => m.insert (n.string "name") n
  env := {env with defined := byName.fold (init := {}) fun s k _ => s.insert k}
  let ((), (order, _, recursive)) := (defs.forM fun n => visit byName (n.string "name") []).run (#[], {}, {})
  let mut functions := #[]
  let mut unextracted := #[]
  for name in order do
    let some node := byName[name]? | continue
    if let some reason := target then
      unextracted := unextracted.push (name, {location := node.location, reason})
      continue
    if let some reason := float.filter fun _ => usesDouble node then
      unextracted := unextracted.push (name, {location := node.location, reason})
      continue
    if recursive.contains name then
      unextracted := unextracted.push (name, {location := node.location, reason := "recursion"})
      continue
    match (translateFunction node).run {} |>.run env with
    | .ok (fn, _) =>
      functions := functions.push fn
      env := {env with functions := env.functions.insert name fn}
    | .error problem => unextracted := unextracted.push (name, problem)
  let rank : Std.HashMap String Nat := defs.zipIdx.foldl (init := {}) fun m (n, i) => m.insert (n.string "name") i
  return {functions, unextracted := unextracted.qsort fun a b => rank[a.1]?.getD 0 < rank[b.1]?.getD 0}

def emitModule (block : String) (imports : Array String) (functions : Array Function) : String :=
  let ns := s!"LeanCModel.{leanIdent block}"
  String.join ((#["LeanCLib.C"] ++ imports).toList.map (s!"import {·}\n")) ++
    s!"\nnamespace {ns}\n\n" ++ String.join (functions.toList.map (·.source ++ "\n")) ++ s!"end {ns}\n"

end LeanC.Verify
