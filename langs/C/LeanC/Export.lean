import Lean

open Lean

namespace LeanC

inductive CType where
  | bool | uint8 | uint16 | uint32 | uint64 | int8 | int16 | int32 | int64
  | usize | float | float32 | char | string | unit
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
  | _ => none

def CType.leanName : CType → String
  | .bool => "Bool"
  | .uint8 => "UInt8"
  | .uint16 => "UInt16"
  | .uint32 => "UInt32"
  | .uint64 => "UInt64"
  | .int8 => "Int8"
  | .int16 => "Int16"
  | .int32 => "Int32"
  | .int64 => "Int64"
  | .usize => "USize"
  | .float => "Float"
  | .float32 => "Float32"
  | .char => "Char"
  | .string => "String"
  | .unit => "Unit"

structure Export where
  name : Name
  symbol : String
  args : Array CType
  result : CType
  io : Bool

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

def validPrefix (cPrefix : String) : Bool :=
  cPrefix.toList.head?.any Char.isAlpha && cPrefix.toList.all (fun c => c.isAlphanum || c == '_') &&
    cPrefix != "lf" && cPrefix != "leanfran"

def exportModule (mod : Name) : Name :=
  `LeanfranExport ++ mod

def defaultRoots (env : Environment) (mod : Name) : Array Name := Id.run do
  let some idx := env.getModuleIdx? mod | return #[]
  return env.header.moduleData[idx.toNat]!.constNames.filter fun name =>
    !name.isInternalDetail && !isPrivateName name &&
      (declRangeExt.find? (level := .exported) env name).isSome &&
      (match env.find? name with
       | some (.defnInfo info) => !info.type.isSort
       | some (.opaqueInfo _) => true
       | _ => false)

def readExport (env : Environment) (cPrefix : String) (name : Name) : Except String Export := do
  let some info := env.find? name | throw s!"unknown declaration '{name}'"
  match info with
  | .defnInfo _ | .opaqueInfo _ => pure ()
  | _ => throw s!"'{name}' is not a definition"
  if name.isInternalDetail || isPrivateName name then throw s!"'{name}' is not public"
  let mut type := info.type
  let mut args := #[]
  while let .forallE _ domain body _ := type do
    let some arg := domain.consumeMData.constName? >>= CType.ofName | throw s!"'{name}' has an unsupported parameter type"
    if arg == .unit then throw s!"'{name}' has an unsupported parameter type"
    args := args.push arg
    type := body
  let io := type.isAppOfArity `IO 1
  let result := if io then type.appArg! else type
  let some nameOfResult := result.constName? | throw s!"'{name}' has an unsupported result type"
  let some result := CType.ofName nameOfResult | throw s!"'{name}' has an unsupported result type"
  if result == .unit && !io then throw s!"'{name}' has an unsupported result type"
  return { name, symbol := s!"{cPrefix}_{snakeCase (lastComponent name)}", args, result, io }

def emitExportModule (mod : Name) (exports : Array Export) : String :=
  s!"import {mod}\n\n" ++ String.join (exports.toList.map fun entry =>
    let args := entry.args.toList.zipIdx.map fun (ty, i) => s!" (a{i} : {ty.leanName})"
    let names := entry.args.toList.zipIdx.map fun (_, i) => s!" a{i}"
    let dummy := if args.isEmpty then " (_ : UInt8)" else ""
    let result := if entry.io then s!"IO {entry.result.leanName}" else entry.result.leanName
    s!"@[export lf_{entry.symbol}]\ndef lf_{entry.symbol}{dummy}{String.join args} : {result} :=\n" ++
      s!"  @_root_.{entry.name}{String.join names}\n\n")

end LeanC
