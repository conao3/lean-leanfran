import Lean.Compiler.LCNF.ToImpureType

open Lean Lean.Meta Lean.Compiler.LCNF

namespace LeanC

def snakeCase (name : String) : String := Id.run do
  let chars := name.toList.toArray
  let mut result := ""
  for i in [:chars.size] do
    let c := chars[i]!
    if c.isUpper && i > 0 then
      let prev := chars[i - 1]!
      if prev.isLower || prev.isDigit || (prev.isUpper && chars[i + 1]?.any Char.isLower) then
        result := result.push '_'
    result := result.push (if c.isAlphanum then c.toLower else '_')
  return result

def lastComponent : Name → String
  | .str _ s => s
  | n => n.toString

def cIdentifier (s : String) : Bool :=
  s.toList.head?.any (fun c => c.isAlpha || c == '_') &&
    s.toList.all (fun c => c.isAlphanum || c == '_')

def escapeIdentifier (s : String) : String :=
  if ["auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else",
      "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register",
      "restrict", "return", "short", "signed", "sizeof", "static", "struct", "switch",
      "typedef", "union", "unsigned", "void", "volatile", "while", "alignas", "alignof", "bool",
      "false", "true", "static_assert", "thread_local", "nullptr", "constexpr", "typeof",
      "typeof_unqual", "asm", "class", "concept", "namespace", "new", "delete", "private",
      "public", "protected", "template", "this", "operator", "using", "friend", "catch", "throw",
      "try", "virtual", "requires", "and", "or", "not", "xor", "bitand", "bitor", "compl",
      "and_eq", "or_eq", "xor_eq", "not_eq", "typeid", "typename", "export", "mutable",
      "consteval", "constinit", "decltype", "explicit", "noexcept", "co_await", "co_return",
      "co_yield", "static_cast", "dynamic_cast", "reinterpret_cast", "const_cast",
      "wchar_t", "char8_t", "char16_t", "char32_t", "atomic_bool", "errno"].contains s ||
      ["NULL", "offsetof"].contains s then s ++ "_"
  else s

abbrev Renames := Std.HashMap Name String

def publicName (renames : Renames) (name : Name) (fallback : String) : String :=
  escapeIdentifier (renames[name]?.getD (snakeCase fallback))

inductive CType where
  | bool | uint8 | uint16 | uint32 | uint64 | int8 | int16 | int32 | int64
  | usize | float | float32 | char | string | unit
  | nat | int | bytes | named (name : String)
  deriving BEq, Inhabited

def CType.ofName : Name → Option CType
  | `Bool => some .bool
  | `UInt8 => some .uint8
  | `UInt16 => some .uint16
  | `UInt32 => some .uint32
  | `UInt64 => some .uint64
  | `Int8 => some .int8
  | `Int16 => some .int16
  | `Int32 => some .int32
  | `Int64 => some .int64
  | `USize => some .usize
  | `Float => some .float
  | `Float32 => some .float32
  | `Char => some .char
  | `String => some .string
  | `Unit | `PUnit => some .unit
  | `Nat => some .nat
  | `Int => some .int
  | `ByteArray => some .bytes
  | _ => none

def CType.cName : CType → String
  | .bool => "bool"
  | .uint8 => "uint8_t"
  | .uint16 => "uint16_t"
  | .uint32 | .char => "uint32_t"
  | .uint64 => "uint64_t"
  | .int8 => "int8_t"
  | .int16 => "int16_t"
  | .int32 => "int32_t"
  | .int64 => "int64_t"
  | .usize => "size_t"
  | .float => "double"
  | .float32 => "float"
  | .string => "lf_str"
  | .unit => "lf_unit"
  | .nat => "lf_nat"
  | .int => "lf_int"
  | .bytes => "lf_byte_array"
  | .named name => name

def CType.byPointer : CType → Bool
  | .nat | .int | .bytes | .named _ => true
  | _ => false

def CType.isSignedInt : CType → Bool
  | .int8 | .int16 | .int32 | .int64 => true
  | _ => false

def CType.abiName : CType → String
  | .bool | .int8 => "uint8_t"
  | .int16 => "uint16_t"
  | .int32 => "uint32_t"
  | .int64 => "uint64_t"
  | .string | .unit | .nat | .int | .bytes | .named _ => "lean_object *"
  | ty => ty.cName

structure Field where
  name : String
  leanName : String
  type : CType
  layout : CtorFieldInfo
  indirect : Bool
  deriving Inhabited

structure Constructor where
  name : String
  leanName : String
  layout : CtorLayout
  fields : Array Field
  positional : Bool
  deriving Inhabited

inductive Shape where
  | record | enum | variant | option | array | list | pair
  deriving BEq, Inhabited

structure Desc where
  type : Expr
  name : String
  shape : Shape := .record
  ctors : Array Constructor := #[]
  item : CType := .unit
  trivial : Bool := false
  deriving Inhabited

abbrev DescribeM := StateT (Array Desc) MetaM

def typeStem (cPrefix : String) (ty : CType) : String :=
  match ty with
  | .named name => String.ofList (name.toList.drop (cPrefix.length + 1))
  | .string => "string"
  | .char => "char"
  | .nat => "nat"
  | .int => "int"
  | .bytes => "byte_array"
  | .unit => "unit"
  | .usize => "usize"
  | .float => "float"
  | .float32 => "float32"
  | _ => (ty.cName.splitOn "_t").head!

partial def readType (cPrefix : String) (renames : Renames) (type : Expr) : DescribeM CType :=
  Meta.withIncRecDepth do
    let type ← whnf type
    let .const name levels := type.getAppFn | throwError "unsupported type {type}"
    if let some primitive := CType.ofName name then
      return primitive
    for desc in ← get do
      if desc.type.getAppFn.constName? == some name && (← isDefEq desc.type type) then
        return .named desc.name
    let env ← getEnv
    let some (.inductInfo ind) := env.find? name | throwError "unsupported type {type}"
    if ind.numIndices != 0 || ind.ctors.isEmpty || isClass env name || isPrivateName name ||
        (← isProp type) then
      throwError "unsupported type {type}"
    let params := type.getAppArgs
    if params.size != ind.numParams then throwError "unsupported type {type}"
    let mut stems := #[]
    for param in params do
      unless (← inferType param).isSort do throwError "unsupported type argument {param}"
      stems := stems.push (typeStem cPrefix (← readType cPrefix renames param))
    let base := if name == `Prod then "pair" else name.toString
    let stem := publicName renames name base
    let nameC := escapeIdentifier s!"{cPrefix}_{String.intercalate "_" (stem :: stems.toList)}"
    if (← get).any (·.name == nameC) then throwError "C name collision: {nameC}"
    let desc : Desc := { type, name := nameC }
    modify (·.push desc)
    let item ← if name == `Array || name == `List then readType cPrefix renames params[0]!
      else pure CType.unit
    let isStruct := Lean.isStructure env name
    let mut ctors := #[]
    unless name == `Array || name == `List do
      for ctorName in ind.ctors do
        let info ← getConstInfoCtor ctorName
        let ty ← Meta.instantiateForall (info.type.instantiateLevelParams info.levelParams levels) params
        let layout ← getCtorLayout ctorName
        let (fields, positional) ← forallTelescopeReducing ty fun fields _ => do
          let mut result := #[]
          let mut positional := false
          for i in [:fields.size] do
            let position := layout.fieldInfo[i]!
            match position with
            | .erased | .void =>
              unless ← isProof fields[i]! do
                throwError "unsupported erased field in {ctorName}"
            | _ =>
              let localDecl ← fields[i]!.fvarId!.getDecl
              let rawName := localDecl.userName
              let anonymous := rawName.isAnonymous || rawName.hasMacroScopes || rawName.isInternal
              positional := positional || anonymous
              let leanName := if anonymous then s!"a{result.size}" else lastComponent rawName
              let fieldKey := (if isStruct then name else ctorName) ++ leanName.toName
              let fieldName := publicName renames fieldKey leanName
              let fieldType ← readType cPrefix renames localDecl.type
              let indirect := (← get).any fun t => t.name == fieldType.cName &&
                t.ctors.isEmpty && t.shape == .record
              if result.any (·.name == fieldName) then
                throwError "C name collision: {nameC}.{fieldName}"
              result := result.push {
                name := fieldName, leanName, type := fieldType,
                layout := position, indirect}
          return (result, positional)
        ctors := ctors.push {
          name := publicName renames ctorName (lastComponent ctorName),
          leanName := lastComponent ctorName, layout, fields, positional}
    let shape :=
      if name == `Option then .option
      else if name == `Array then .array
      else if name == `List then .list
      else if name == `Prod then .pair
      else if isStruct then .record
      else if ctors.all (·.fields.isEmpty) then .enum
      else .variant
    let trivial := (← hasTrivialImpureStructure? name).isSome
    modify fun ds => (ds.filter (·.name != nameC)).push { desc with ctors, shape, item, trivial }
    return .named nameC

def leanTypeSource (type : Expr) : MetaM String :=
  withOptions (fun o => o.setBool `pp.fullNames true |>.setBool `pp.notation false
      |>.setBool `pp.explicit true) do
    return (← ppExpr type).pretty

end LeanC
