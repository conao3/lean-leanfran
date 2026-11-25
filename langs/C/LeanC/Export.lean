import Lean
import LeanC.Json

open Lean

namespace LeanC

structure Export where
  name : Name
  symbol : String
  args : Array CType
  result : CType
  io : Bool
  argTypes : Array String
  resultType : String
  exception : Option CType := none

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

def readExport (cPrefix : String) (renames : Renames) (name : Name) : DescribeM Export := do
  let some info := (← getEnv).find? name | throwError "unknown declaration '{name}'"
  match info with
  | .defnInfo _ | .opaqueInfo _ => pure ()
  | _ => throwError "'{name}' is not a definition"
  if name.isInternalDetail || isPrivateName name then throwError "'{name}' is not public"
  let mut type := info.type
  let mut args := #[]
  let mut argTypes := #[]
  while let .forallE _ domain body _ := type do
    let domain := domain.consumeMData
    let arg ← try readType cPrefix renames domain catch e =>
      let message ← e.toMessageData.toString
      if message.startsWith "C name collision:" || message.startsWith "C invariant:" then throw e
      throwError "'{name}' has an unsupported parameter type: {e.toMessageData}"
    if arg == .unit then throwError "'{name}' has an unsupported parameter type"
    args := args.push arg
    argTypes := argTypes.push (← leanTypeSource domain)
    type := body
  let io := type.isAppOfArity `IO 1
  let result := if io then type.appArg! else type
  let exception ← if result.isAppOfArity `Except 2 then
    some <$> readType cPrefix renames result.appFn!.appArg!
    else pure none
  let value := if exception.isSome then result.appArg! else result
  let resultC ← try readType cPrefix renames value catch e =>
    let message ← e.toMessageData.toString
    if message.startsWith "C name collision:" || message.startsWith "C invariant:" then throw e
    throwError "'{name}' has an unsupported result type: {e.toMessageData}"
  if resultC == .unit && !io && exception.isNone then
    throwError "'{name}' has an unsupported result type"
  return {
    name, symbol := escapeIdentifier s!"{cPrefix}_{publicName renames name (lastComponent name)}",
    args, result := resultC, io, argTypes, resultType := ← leanTypeSource result, exception }

def Export.boxResult (entry : Export) : Bool :=
  !entry.io && entry.exception.isNone && entry.result.byPointer

def apiTypes (exports : Array Export) : Array CType :=
  exports.foldl (init := #[]) fun types entry =>
    let result := if entry.result == .unit then #[] else #[entry.result]
    (entry.args ++ result ++ entry.exception.toArray).foldl (init := types) fun types ty =>
      if types.contains ty then types else types.push ty

def exportJsonApis (cPrefix : String) (exports : Array Export) (descs : Array Desc) : Array JsonApi :=
  jsonApis cPrefix descs ((apiTypes exports).filter fun ty => if let .named _ := ty then false else true)

def emitExportModule (mod : Name) (cPrefix : String) (exports : Array Export) (descs : Array Desc) (apis : Array JsonApi) : String :=
  s!"import {mod}\n" ++
  (if apis.isEmpty then "\n" else "import LeanfranC.Json\n\n") ++
  s!"@[export lf_{cPrefix}_nat_decimal]\ndef lf_{cPrefix}_nat_decimal (n : Nat) : String := toString n\n\n" ++
  s!"@[export lf_{cPrefix}_int_decimal]\ndef lf_{cPrefix}_int_decimal (n : Int) : String := toString n\n\n" ++
  String.join (exports.toList.map fun entry =>
    let args := entry.argTypes.toList.zipIdx.map fun (ty, i) =>
      if entry.args[i]!.byPointer then s!" (a{i} : Prod ({ty}) Bool)" else s!" (a{i} : {ty})"
    let names := entry.args.toList.zipIdx.map fun (ty, i) =>
      if ty.byPointer then s!" a{i}.1" else s!" a{i}"
    let dummy := if args.isEmpty then " (_ : UInt8)" else ""
    let result := if entry.io then s!"IO ({entry.resultType})"
      else if entry.boxResult then s!"Prod ({entry.resultType}) Bool"
      else entry.resultType
    let call := s!"@_root_.{entry.name}{String.join names}"
    let body := if entry.boxResult then s!"({call}, false)" else call
    s!"@[export lf_{entry.symbol}]\ndef lf_{entry.symbol}{dummy}{String.join args} : {result} :=\n" ++
      s!"  {body}\n\n") ++
  (if apis.isEmpty then "" else emitJsonExports descs apis)

end LeanC
