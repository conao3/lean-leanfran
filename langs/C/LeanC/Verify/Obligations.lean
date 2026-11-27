import Lean

open Lean Meta

namespace LeanC.Verify

def standardAxioms : List Name := [``propext, ``Quot.sound, ``Classical.choice]

structure ObligationRef where
  model : Name
  label : String

def ObligationRef.statement (o : ObligationRef) : Name := o.model ++ `obligation ++ .mkSimple o.label

def ObligationRef.theorem (o : ObligationRef) : Name := o.model ++ `proof ++ .mkSimple o.label

private def moduleFile (mod : Name) : String :=
  "/".intercalate (mod.components.map toString) ++ ".lean"

partial def untrustedClosure (env : Environment) (trusted : NameSet) (roots : List Name) :
    Std.HashMap Name ConstantInfo := Id.run do
  let isTrusted := fun (n : Name) => match env.getModuleIdxFor? n with
    | some idx => trusted.contains env.header.moduleNames[idx.toNat]!
    | none => false
  let mut todo := roots
  let mut found : Std.HashMap Name ConstantInfo := {}
  while let n :: rest := todo do
    todo := rest
    if found.contains n || isTrusted n then continue
    let some ci := env.find? n | continue
    found := found.insert n ci
    todo := ci.getUsedConstantsAsSet.toList ++ todo
    match ci with
    | .inductInfo info => todo := info.all ++ info.ctors ++ todo
    | .ctorInfo info => todo := info.induct :: todo
    | .recInfo info => todo := info.all ++ todo
    | _ => pure ()
  return found

def replayProblem (env : Environment) (trusted : NameSet) (base : Kernel.Environment) (names : List Name) :
    IO (Option String) := do
  try
    discard <| base.replay (untrustedClosure env trusted names)
    return none
  catch e => return some (" ".intercalate ((e.toString.take 1000).toString.splitOn "\n" |>.map (·.trimAscii.toString)))

def orphanInstance (trusted : NameSet) (stmt : Name) : MetaM (Option (Name × Name)) := do
  let env ← getEnv
  let moduleOf := fun (n : Name) => (env.getModuleIdxFor? n).map fun idx => env.header.moduleNames[idx.toNat]!
  let ours := fun (n : Name) => match moduleOf n with
    | some m => trusted.contains m || (`LeanCLib).isPrefixOf m
    | none => false
  let translated := fun (n : Name) => match moduleOf n with
    | some m => (`LeanCModel).isPrefixOf m
    | none => true
  let mut todo := [stmt]
  let mut seen : NameSet := {}
  while let n :: rest := todo do
    todo := rest
    if seen.contains n then continue
    seen := seen.insert n
    let some ci := env.find? n | continue
    for c in ci.getUsedConstantsAsSet do
      if translated c then todo := c :: todo
      else if !ours c && (← isInstance c) then
        let some info := env.find? c | continue
        let args := info.type.getForallBody.getAppArgs
        unless args.any fun a => a.getUsedConstants.any fun t => !ours t do
          return some (c, (moduleOf c).getD .anonymous)
  return none

def checkObligation (trusted : NameSet) (base : Kernel.Environment) (o : ObligationRef) : MetaM Json := do
  let env ← getEnv
  let base' := [("model", toJson o.model.toString), ("label", toJson o.label)]
  let stmt := o.statement
  let thm := o.theorem
  unless env.contains stmt do
    return Json.mkObj (base' ++ [("status", toJson "unextracted"), ("detail", toJson s!"{stmt} is not defined")])
  let some ci := env.find? thm | return Json.mkObj (base' ++ [("status", toJson "missing")])
  let mod := match env.getModuleIdxFor? thm with
    | some idx => moduleFile env.header.moduleNames[idx.toNat]!
    | none => ""
  let line := match ← findDeclarationRanges? thm with
    | some r => r.range.pos.line
    | none => 0
  let place := [("file", toJson mod), ("line", toJson line)]
  let expected := mkConst stmt
  let same ← if ci.type == expected then pure true
    else try withTransparency .default (isDefEq ci.type expected) catch _ => pure false
  unless same do
    return Json.mkObj (base' ++ place ++ [("status", toJson "mismatch"), ("detail", toJson s!"{thm} : {← ppExpr ci.type}")])
  if let some problem ← replayProblem env trusted base [thm, stmt] then
    return Json.mkObj (base' ++ place ++ [("status", toJson "failed"),
      ("detail", toJson s!"the kernel rejected {thm} or a declaration it uses: {problem}")])
  if let some (inst, mod) ← orphanInstance trusted stmt then
    return Json.mkObj (base' ++ place ++ [("status", toJson "unextracted"),
      ("detail", toJson s!"the translated definition uses the instance {inst} from {mod} on standard types")])
  let axioms := (← collectAxioms thm).toList.map (·.toString) |>.mergeSort (· ≤ ·)
  let status :=
    if axioms.contains "sorryAx" then "sorry"
    else if axioms.all (fun a => standardAxioms.contains a.toName) then "proved"
    else "axioms"
  return Json.mkObj (base' ++ place ++ [("status", toJson status), ("axioms", toJson axioms)])

def parseObligations (j : Json) : Except String (Array ObligationRef) := do
  let arr ← j.getArr?
  arr.mapM fun e => do
    let model := (← e.getObjValAs? String "model").toName
    let label ← e.getObjValAs? String "label"
    return { model, label }

def obligationsUsage : String :=
  "Usage: leanfran --lang c obligations check --modules Module... --obligations file.json"

unsafe def obligationsMain (args : List String) : IO UInt32 := do
  let fail := fun (message : String) => do
    IO.eprintln s!"leanfran --lang c: {message}\n{obligationsUsage}"
    return (252 : UInt32)
  let "check" :: "--modules" :: rest := args | fail "expected 'obligations check'"
  let modules := rest.takeWhile (! ·.startsWith "--")
  if modules.isEmpty then return ← fail "--modules requires at least one name"
  let ["--obligations", file] := rest.drop modules.length
    | return ← fail "expected --modules Module... --obligations file.json"
  let refs ← match Json.parse (← IO.FS.readFile file) >>= parseObligations with
    | .ok refs => pure refs
    | .error message => return ← fail s!"{file}: {message}"
  enableInitializersExecution
  initSearchPath (← findSysroot)
  let names := modules.toArray.map String.toName
  let searchPath ← searchPathRef.get
  for m in names do
    if (← searchPath.findWithExt "olean" m).isNone then
      return ← fail s!"module not found: {m}"
  let env ← importModules (names.map fun m => { module := m }) {} (loadExts := true)
  let toolchain := (← findSysroot) / "lib" / "lean"
  let trusted ← env.header.moduleNames.filterM fun m => do
    return (← findOLean m).toString.startsWith (toolchain.toString ++ "/")
  let baseEnv ← importModules (trusted.map fun m => { module := m }) {}
  let trustedSet := trusted.foldl (init := {}) NameSet.insert
  let ctx : Core.Context := { fileName := file, fileMap := default, maxHeartbeats := 0 }
  let (results, _) ← ((refs.mapM (checkObligation trustedSet baseEnv.toKernelEnv)).run').toIO ctx { env }
  IO.println (Json.arr results).compress
  return 0

end LeanC.Verify
