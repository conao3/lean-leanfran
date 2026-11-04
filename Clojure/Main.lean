import LeanClj

open Lean LeanClj

def version : String := "0.1.0"

def usage : String := "usage: lean-clj [--version] <command> <subcommand> [parameters]

commands:
  module generate-namespace  Emit a Clojure namespace for functions of a Lean module

lean-clj module generate-namespace
  --module-name <Name>        Lean module to import (required)
  --namespace <ns>            Clojure namespace of the output (required)
  --roots <Name> ...          Functions to export (default: the module's public definitions)
  --strip-namespace <Name>    Lean namespace removed from public names (default: the module name)
  --search-path <dir> ...     Extra .olean search directories
  --output-file <path>        Write the namespace here (default: standard output)
  --forms-only | --no-forms-only
                              Omit the `ns` form (used by deflean)
  --output json|text          Format of the summary printed when --output-file is given
"

structure Opts where
  moduleName : Option Name := none
  ns : Option String := none
  roots : Array Name := #[]
  strip : Option Name := none
  searchPath : Array System.FilePath := #[]
  outputFile : Option System.FilePath := none
  formsOnly : Bool := false
  output : String := "json"

def parseName (s : String) : Name := s.toName

partial def parseOpts (args : List String) (o : Opts) : Except String Opts :=
  let takeMany (rest : List String) : List String × List String :=
    (rest.takeWhile (!·.startsWith "--"), rest.dropWhile (!·.startsWith "--"))
  match args with
  | [] => .ok o
  | "--module-name" :: v :: rest => parseOpts rest { o with moduleName := parseName v }
  | "--namespace" :: v :: rest => parseOpts rest { o with ns := v }
  | "--strip-namespace" :: v :: rest => parseOpts rest { o with strip := parseName v }
  | "--output-file" :: v :: rest => parseOpts rest { o with outputFile := some v }
  | "--output" :: v :: rest =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else .error s!"--output must be json or text: {v}"
  | "--forms-only" :: rest => parseOpts rest { o with formsOnly := true }
  | "--no-forms-only" :: rest => parseOpts rest { o with formsOnly := false }
  | "--roots" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with roots := o.roots ++ vs.toArray.map parseName }
  | "--search-path" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with searchPath := o.searchPath ++ vs.toArray.map System.FilePath.mk }
  | a :: _ => .error s!"unknown parameter: {a}"

/-- Definitions of `mod` worth exporting by default. -/
def defaultRoots (env : Environment) (mod : Name) : Array Name := Id.run do
  let some idx := env.getModuleIdx? mod | return #[]
  let insts : Std.HashSet Name := (Meta.instanceExtension.ext.getModuleEntries env idx).foldl
    (fun s e => match e with
      | .global i | .scoped _ i => match i.globalName? with | some n => s.insert n | none => s) {}
  let underInstance (n : Name) : Bool := Id.run do
    let mut p := n
    while !p.isAnonymous do
      if insts.contains p then return true
      p := p.getPrefix
    return false
  let mut out := #[]
  for n in env.header.moduleData[idx.toNat]!.constNames do
    if n.isInternal || isPrivateName n || underInstance n then continue
    let some (.defnInfo _) := env.find? n | continue
    if (IR.findEnvDecl env n).isNone then continue
    out := out.push n
  return out

def jsonStr (s : String) : String := (Json.str s).compress

def runGenerate (o : Opts) : IO UInt32 := do
  let some mod := o.moduleName | throw <| IO.userError "--module-name is required"
  let some ns := o.ns | throw <| IO.userError "--namespace is required"
  initSearchPath (← findSysroot) o.searchPath.toList
  let env ← importModules #[{ module := mod }] {} (trustLevel := 1024)
  let explicit := !o.roots.isEmpty
  let roots := if explicit then o.roots else defaultRoots env mod
  let strip := o.strip.getD mod
  let ctx : Core.Context := { fileName := "<lean-clj>", fileMap := default, maxHeartbeats := 0 }
  let act : MetaM Output := do
    if explicit then generate roots strip
    else
      -- keep only the defaults that have a marshallable public signature
      let mut ok := #[]
      for r in roots do
        let some d := IR.findEnvDecl (← getEnv) r | continue
        let r' ← try
            discard <| (publicSig r d.params).run {}
            pure (some r)
          catch _ => pure none
        if let some r := r' then ok := ok.push r
      generate ok strip
  let (out, _) ← (act.run' {}).toIO ctx { env }
  let body := renderForms out.forms
  let text := if o.formsOnly then body
    else (nsForm ns (out.publics.map (·.2))).render 0 ++ "\n\n" ++ body
  match o.outputFile with
  | none => IO.print text
  | some f =>
    if let some dir := f.parent then IO.FS.createDirAll dir
    IO.FS.writeFile f text
    if o.output == "json" then
      let pubs := out.publics.map fun (l, c) =>
        "{\"LeanName\":" ++ jsonStr (toString l) ++ ",\"ClojureName\":" ++ jsonStr c ++ "}"
      IO.println <| "{\"OutputFile\":" ++ jsonStr f.toString ++
        ",\"Functions\":[" ++ ",".intercalate pubs.toList ++ "]" ++
        ",\"Externs\":[" ++ ",".intercalate (out.externs.toList.map jsonStr) ++ "]}"
    else
      for (l, c) in out.publics do IO.println s!"{c}\t{l}"
  return 0

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println s!"lean-clj {version} (Lean {Lean.versionString})"; return 0
  | [] | ["help"] | ["module", "help"] | ["module", "generate-namespace", "help"] =>
    IO.print usage; return 0
  | "module" :: "generate-namespace" :: rest =>
    match parseOpts rest {} with
    | .error e => IO.eprintln e; IO.eprint usage; return 252
    | .ok o =>
      if o.moduleName.isNone || o.ns.isNone then
        IO.eprintln "--module-name and --namespace are required"; return 252
      try runGenerate o
      catch e => IO.eprintln s!"error: {e}"; return 254
  | _ => IO.eprint usage; return 252
