import LeanC.Build
import LeanC.Embed.Models
import LeanC.Embed.ModelTest
import Leanfran.Embed.Types

open Lean Lake System

namespace LeanC.Embed

private def supportHeader := include_str "../../support/leanfran.h"
private def supportSource := include_str "../../support/leanfran.c"

def outputFiles : Array String :=
  #["leanfran.h", "leanfran.pc", "leanfran.mk", "leanfran-config.cmake", "libleanfran.a"]

def imports (modules : Array String) : String :=
  String.join (modules.toList.map (fun name => s!"import {name}\n"))

unsafe def buildProject (dir : FilePath) (blocks : Array Block) (models : Models)
    (scratch stage out : FilePath) (lake : Array String → IO Unit) :
    IO (Std.HashMap String (Array Export) × Array Desc) := do
  let ws ← loadWorkspace dir
  let mut exports : Std.HashMap String (Array Export) := {}
  let mut types : Array Desc := #[]
  let mut symbols : Std.HashSet String := .ofList ["leanfran_init", "lf_project_initialized"]
  let mut modules := #[]
  let mut sources := #[]
  IO.FS.createDirAll scratch
  IO.FS.createDirAll stage
  for block in blocks do
    let target := {moduleName := Block.moduleName block.name, cPrefix := block.name : Target}
    let names ← match ← generate ws target scratch #[] {} {} true models.types with
      | .ok (names, entries, descs) =>
        exports := exports.insert block.name entries
        types := types ++ descs
        pure names
      | .error error => throw <| IO.userError s!"{block.file}:{block.line}:1: error: {error}"
    for name in names do
      if symbols.contains name then
        throw <| IO.userError s!"{block.file}:{block.line}:1: error: C name collision: {name}"
      symbols := symbols.insert name
    let header := s!"{block.name}.h"
    let text ← IO.FS.readFile (scratch / header)
    IO.FS.writeFile (stage / header) text
    let scratchHeader := models.headers.foldl (init := text) fun text (header, file) =>
      text.replace s!"#include \"{header}\"" s!"#include \"{file}\""
    IO.FS.writeFile (scratch / header) scratchHeader
    let exportFile := exportPath target dir
    IO.FS.createDirAll exportFile.parent.get!
    discard <| Leanfran.Embed.writeChanged exportFile (← IO.FS.readFile (exportPath target scratch))
    modules := modules.push (exportModule target.moduleName.toName).toString
    sources := sources.push (scratch / s!"{block.name}.c", s!"block_{block.name}", true)
  let projectModule := "LeanfranProject"
  discard <| Leanfran.Embed.writeChanged (dir / s!"{projectModule}.lean") (imports modules)
  lake #["build", s!"+{projectModule}:olean"]
  let ws ← loadWorkspace dir
  let mod ← findModule ws {moduleName := projectModule, cPrefix := "leanfran"}
  let objects ← moduleObjects ws mod
  let flags ← moduleLinkFlags ws mod
  let support := scratch / "leanfran.c"
  let init := scratch / "leanfran-init.c"
  let header := supportHeader.replace "void lf_error_clear("
    "lf_status leanfran_init(lf_error *err);\nvoid lf_error_clear("
  IO.FS.writeFile (stage / "leanfran.h") header
  IO.FS.writeFile (scratch / "leanfran.h") header
  IO.FS.writeFile support supportSource
  IO.FS.writeFile init (emitProjectInitializer (Lean.mkModuleInitializationFunctionName mod.name mod.pkg.id?))
  let lean := ws.lakeEnv.lean
  let wrappers ← compileCObjects lean scratch sources (#["-iquote", scratch.toString] ++ models.flags)
  let native ← compileCObjects lean scratch #[(support, "support", true), (init, "init", true)]
  let native := wrappers ++ native
  let archive := "libleanfran.a"
  let library := scratch / archive
  let some () ← (Lake.compileStaticLib library (native ++ objects) lean.ar).toBaseIO
    | throw <| IO.userError s!"could not create {archive}"
  IO.FS.rename library (stage / archive)
  writeLinkFiles stage "leanfran" archive releaseVersion flags.staticFlags out
  return (exports, types)

def writeModelTest (root scratch stage out : FilePath) (config : Config) (blocks : Array Block)
    (models : Models) (verified : Array FilePath) (exports : Std.HashMap String (Array Export))
    (types : Array Desc) : IO Unit := do
  let functions ← discoverModels root config blocks verified models.source scratch
  if functions.isEmpty then return
  let (source, files) := modelTest functions blocks exports types
  IO.FS.writeFile (stage / modelTestSource) source
  IO.FS.writeFile (stage / "leanfran_model_test.h") modelTestSupport
  let mk := stage / "leanfran.mk"
  IO.FS.writeFile mk ((← IO.FS.readFile mk) ++ modelTestMake out config (files.map (root / ·)))

end LeanC.Embed
