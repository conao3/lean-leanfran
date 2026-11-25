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

def checkObligation (o : ObligationRef) : MetaM Json := do
  let env ← getEnv
  let base := [("model", toJson o.model.toString), ("label", toJson o.label)]
  let stmt := o.statement
  let thm := o.theorem
  unless env.contains stmt do
    return Json.mkObj (base ++ [("status", toJson "unextracted"), ("detail", toJson s!"{stmt} is not defined")])
  let some ci := env.find? thm | return Json.mkObj (base ++ [("status", toJson "missing")])
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
    return Json.mkObj (base ++ place ++ [("status", toJson "mismatch"), ("detail", toJson s!"{thm} : {← ppExpr ci.type}")])
  let axioms := (← collectAxioms thm).toList.map (·.toString) |>.mergeSort (· ≤ ·)
  let status :=
    if axioms.contains "sorryAx" then "sorry"
    else if axioms.all (fun a => standardAxioms.contains a.toName) then "proved"
    else "axioms"
  return Json.mkObj (base ++ place ++ [("status", toJson status), ("axioms", toJson axioms)])

def parseObligations (j : Json) : Except String (Array ObligationRef) := do
  let arr ← j.getArr?
  arr.mapM fun e => do
    let model := (← e.getObjValAs? String "model").toName
    let label ← e.getObjValAs? String "label"
    return { model, label }

def obligationsUsage : String :=
  "Usage: leanfran-c obligations check --modules Module... --obligations file.json"

unsafe def obligationsMain (args : List String) : IO UInt32 := do
  let fail := fun (message : String) => do
    IO.eprintln s!"leanfran-c: {message}\n{obligationsUsage}"
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
  let ctx : Core.Context := { fileName := file, fileMap := default, maxHeartbeats := 0 }
  let (results, _) ← ((refs.mapM checkObligation).run').toIO ctx { env }
  IO.println (Json.arr results).compress
  return 0

end LeanC.Verify
