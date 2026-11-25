import LeanC.Verify.Translate

open Lean System
open LeanC.ClangAst

namespace LeanC.Verify

def translateUsage : String :=
  "Usage: leanfran-c translate --block name --out file.lean [--import Module]... file.c [-- clang-arg...]"

private def supportHeader := include_str "../../support/leanfran.h"

private structure Options where
  block : String := ""
  out : String := ""
  imports : Array String := #[]
  source : String := ""
  clangArgs : Array String := #[]

private def parseOptions (args : List String) : Except String Options := do
  let mut opts : Options := {}
  let mut rest := args
  while let arg :: tail := rest do
    rest := tail
    if arg == "--" then
      opts := {opts with clangArgs := tail.toArray}
      break
    if ["--block", "--out", "--import"].contains arg then
      let value :: tail' := tail | throw s!"missing value for '{arg}'"
      if value.isEmpty || value.startsWith "--" then throw s!"missing value for '{arg}'"
      rest := tail'
      if arg == "--block" then opts := {opts with block := value}
      else if arg == "--out" then opts := {opts with out := value}
      else opts := {opts with imports := opts.imports.push value}
    else if arg.startsWith "-" then throw s!"unknown option '{arg}'"
    else if opts.source.isEmpty then opts := {opts with source := arg}
    else throw s!"unexpected argument '{arg}'"
  if opts.block.isEmpty then throw "missing --block"
  unless cIdentifier opts.block do throw s!"invalid block name '{opts.block}'"
  if opts.out.isEmpty then throw "missing --out"
  if opts.source.isEmpty then throw "missing C source file"
  return opts

private def lineOf (source : ByteArray) (offset : Nat) : Nat :=
  1 + (source.extract 0 offset).data.countP (· == 10)

def translateMain (args : List String) : IO UInt32 := do
  let opts ← match parseOptions args with
    | .ok opts => pure opts
    | .error message => IO.eprintln s!"leanfran-c: {message}\n{translateUsage}"; return 252
  let cwd ← IO.currentDir
  let file := absolute cwd ⟨opts.source⟩
  unless ← file.pathExists do
    IO.eprintln s!"leanfran-c: {opts.source}: no such file"
    return 254
  let file ← IO.FS.realPath file
  try
    IO.FS.withTempDir fun tmp => do
      IO.FS.writeFile (tmp / "leanfran.h") supportHeader
      let root ← dump {directory := cwd, file, flags := opts.clangArgs} #["-I", tmp.toString, "-x", "c"]
      let output := translate root file cwd
      let source ← IO.FS.readBinFile file
      for (name, problem) in output.unextracted do
        let line := lineOf source problem.location.offset
        IO.eprintln s!"{opts.source}:{line}:{problem.location.column}: unextracted {name}: {problem.reason}"
      for fn in output.functions do
        IO.println s!"translated {fn.name}"
      IO.FS.writeFile ⟨opts.out⟩ (emitModule opts.block opts.imports output.functions)
    return 0
  catch error =>
    IO.eprintln s!"leanfran-c: {error}"
    return 254

end LeanC.Verify
