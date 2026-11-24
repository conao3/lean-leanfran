import Lean

open Lean System

namespace LeanC

def sharedLibrary (cPrefix : String) : String :=
  s!"lib{cPrefix}.{if Platform.isOSX then "dylib" else "so"}"

private def shellQuote (arg : String) : String :=
  "'" ++ arg.replace "'" "'\\''" ++ "'"

private def shellFlags (args : Array String) : String :=
  " ".intercalate (args.toList.map shellQuote)

private def pkgFlags (args : Array String) : String :=
  " ".intercalate (args.toList.map fun arg =>
    let escaped := arg.replace "\\" "\\\\" |>.replace "\"" "\\\""
    "\"" ++ escaped ++ "\"")

private def cmakeQuote (arg : String) : String :=
  Id.run do
    let mut equals := ""
    while arg.contains s!"]{equals}]" do
      equals := equals ++ "="
    return s!"[{equals}[{arg}]{equals}]"

private def withoutLeanLibraries (flags : List String) : List String :=
  flags.filter fun flag => ![
    "-Wl,--start-group", "-Wl,--end-group", "-lleancpp", "-lLean", "-lStd", "-lInit", "-lleanrt",
    "-lLeanExport", "-lLake", "-lLake_shared", "-Wl,-Bsymbolic"].contains flag

private def group (flags : Array String) : Array String :=
  if Platform.isOSX then flags else #["-Wl,--start-group"] ++ flags ++ #["-Wl,--end-group"]

structure LinkFlags where
  leanLibDir : FilePath
  staticFlags : Array String

def linkFlags (leanPrefix : FilePath) (flags : String) (withLean withStd : Bool) : Except String LinkFlags := do
  let leanLibDir := leanPrefix / "lib" / "lean"
  let [_, suffix] := flags.splitOn s!" -L {leanLibDir} "
    | throw "could not read Lean's library search path from leanc --print-ldflags"
  let runtime := withoutLeanLibraries (suffix.trimAscii.toString.splitOn " " |>.filter (!·.isEmpty))
  let core := #["-lInit", "-lleanrt"]
  let libs := if withLean then group (#["-lleancpp", "-lLean", "-lStd"] ++ core) else
    (if withStd then #["-lStd"] else #[]) ++ group core
  return {leanLibDir, staticFlags :=
    #[s!"-L{leanLibDir}", s!"-L{leanPrefix / "lib"}"] ++ libs ++ runtime.toArray}

def LinkFlags.sharedFlags (flags : LinkFlags) : Array String :=
  #[s!"-L{flags.leanLibDir}", s!"-Wl,-rpath,{flags.leanLibDir}", "-lleanshared", "-pthread"]

def writeLinkFiles (out : FilePath) (cPrefix lib version : String) (dependencies : Array String) :
    IO Unit := do
  let libs := #[(out / lib).toString] ++ dependencies
  let cflags := #[s!"-I{out}"]
  let pc := s!"Name: {cPrefix}\nDescription: Lean C bindings for {cPrefix}\nVersion: {version}\n" ++
    s!"Cflags: {pkgFlags cflags}\nLibs: {pkgFlags libs}\n"
  IO.FS.writeFile (out / s!"{cPrefix}.pc") pc
  let makeFlags := fun args => (shellFlags args).replace "$" "$$" |>.replace "#" "\\#"
  let makePrefix := cPrefix.toUpper
  IO.FS.writeFile (out / s!"{cPrefix}.mk")
    s!"{makePrefix}_CFLAGS := {makeFlags cflags}\n{makePrefix}_LDLIBS := {makeFlags libs}\n"
  let kind := if lib.endsWith ".a" then "STATIC" else "SHARED"
  let target := s!"{cPrefix}::{cPrefix}"
  let isSearchFlag := fun (arg : String) => arg.startsWith "-L" || arg.startsWith "-Wl,-rpath,"
  let options := dependencies.filter isSearchFlag
  let libraries := dependencies.filter (!isSearchFlag ·)
  let cmakeArgs := fun (args : Array String) => " ".intercalate (args.toList.map cmakeQuote)
  let cmake := s!"if(NOT TARGET {target})\n  add_library({target} {kind} IMPORTED)\n" ++
    s!"  set_target_properties({target} PROPERTIES\n" ++
    s!"    IMPORTED_LOCATION {cmakeQuote (out / lib).toString}\n" ++
    s!"    INTERFACE_INCLUDE_DIRECTORIES {cmakeQuote out.toString})\n" ++
    s!"  target_link_options({target} INTERFACE {cmakeArgs options})\n" ++
    s!"  target_link_libraries({target} INTERFACE {cmakeArgs libraries})\nendif()\n"
  IO.FS.writeFile (out / s!"{cPrefix}-config.cmake") cmake

end LeanC
