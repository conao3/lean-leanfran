import LeanClj

open Lean LeanClj

def version : String := "0.5.0"

def usage : String := "usage: leanfran [--version] <command> <subcommand> [parameters]

commands:
  module generate-namespace  Emit a Clojure namespace for functions of a Lean module
  project generate           Build a lake project and emit a namespace for each of its modules

leanfran module generate-namespace
  --module-name <Name>        Lean module to import (required)
  --namespace <ns>            Clojure namespace of the output (required)
  --roots <Name> ...          Functions to export (default: the module's public definitions)
  --strip-namespace <Name>    Lean namespace removed from public names (default: the module name)
  --search-path <dir> ...     Extra .olean search directories
  --output-file <path>        Write the namespace here (default: standard output)
  --forms-only | --no-forms-only
                              Omit the `ns` form (used by deflean)
  --output json|text          Format of the summary printed when --output-file is given

leanfran project generate
  --lake-dir <dir>            Directory of the lake project (required)
  --namespace-prefix <ns>     Prefix of the Clojure namespaces (required)
  --output-dir <dir>          Source directory to write the namespaces in (required)
  --modules <Name> ...        Modules to emit (default: every module under --lake-dir)
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
  lakeDir : Option System.FilePath := none
  nsPrefix : Option String := none
  outputDir : Option System.FilePath := none
  modules : Array Name := #[]

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
  | "--lake-dir" :: v :: rest => parseOpts rest { o with lakeDir := some v }
  | "--namespace-prefix" :: v :: rest => parseOpts rest { o with nsPrefix := v }
  | "--output-dir" :: v :: rest => parseOpts rest { o with outputDir := some v }
  | "--modules" :: rest =>
    let (vs, rest) := takeMany rest
    parseOpts rest { o with modules := o.modules ++ vs.toArray.map parseName }
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
    if let some (.defnInfo _) := env.find? n.getPrefix then continue
    let some (.defnInfo _) := env.find? n | continue
    if (IR.findEnvDecl env n).isNone then continue
    if ((LeanClj.externSymbol env n).bind LeanClj.cljVar).isSome then continue
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
  let ctx : Core.Context := { fileName := "<leanfran>", fileMap := default, maxHeartbeats := 0 }
  let act : MetaM Output := do
    if explicit then generate roots strip
    else
      -- keep only the defaults that have a marshallable public signature
      let mut ok := #[]
      for r in roots do
        let some d := IR.findEnvDecl (← getEnv) r | continue
        try
          discard <| (publicSig r d.params).run {}
          ok := ok.push r
        catch e =>
          IO.eprintln s!"leanfran: skipped {r}: {← e.toMessageData.toString}"
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

/-- The Lean modules of the `.lean` files under `dir`, outside `.lake` and the
    lakefile. -/
partial def sourceModules (dir : System.FilePath) (pfx : List String := []) : IO (Array Name) := do
  let mut out := #[]
  for e in ← dir.readDir do
    if e.fileName.startsWith "." then continue
    if ← e.path.isDir then
      out := out ++ (← sourceModules e.path (pfx ++ [e.fileName]))
    else if e.fileName.endsWith ".lean" && e.fileName != "lakefile.lean" then
      let base := String.ofList (e.fileName.toList.take (e.fileName.length - 5))
      out := out.push ((pfx ++ [base]).foldl Name.str .anonymous)
  return out

/-- The Clojure namespace of the module `m` under `pfx`: `Roman.Core` → `pfx.roman.core`. -/
def moduleNamespace (pfx : String) (m : Name) : String :=
  ".".intercalate (pfx :: m.componentsRev.reverse.map fun c => kebab (c.toString (escape := false)))

def namespacePath (ns : String) : System.FilePath :=
  System.mkFilePath ((ns.replace "-" "_").splitOn ".") |>.addExtension "clj"

def runProject (o : Opts) : IO UInt32 := do
  let some dir := o.lakeDir | return 252
  let some pfx := o.nsPrefix | return 252
  let some outDir := o.outputDir | return 252
  let build ← IO.Process.output { cmd := "lake", args := #["build"], cwd := dir }
  if build.exitCode != 0 then
    IO.eprint (build.stdout ++ build.stderr)
    return 254
  let env ← IO.Process.output { cmd := "lake", args := #["env", "printenv", "LEAN_PATH"], cwd := dir }
  let paths := ((env.stdout.trimAscii.toString).splitOn ":").filter (!·.isEmpty) |>.toArray.map System.FilePath.mk
  let mods ← if o.modules.isEmpty then sourceModules dir else pure o.modules
  for m in mods do
    let ns := moduleNamespace pfx m
    let o' : Opts := { moduleName := some m, ns := some ns, searchPath := paths,
                       outputFile := some (outDir / namespacePath ns), output := "text" }
    let code ← runGenerate o'
    if code != 0 then return code
  return 0

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println s!"leanfran {version} (Lean {Lean.versionString})"; return 0
  | [] | ["help"] | ["module", "help"] | ["module", "generate-namespace", "help"] =>
    IO.print usage; return 0
  | "project" :: "generate" :: rest =>
    match parseOpts rest {} with
    | .error e => IO.eprintln e; IO.eprint usage; return 252
    | .ok o =>
      if o.lakeDir.isNone || o.nsPrefix.isNone || o.outputDir.isNone then
        IO.eprintln "--lake-dir, --namespace-prefix, and --output-dir are required"; return 252
      try runProject o
      catch e => IO.eprintln s!"error: {e}"; return 254
  | "module" :: "generate-namespace" :: rest =>
    match parseOpts rest {} with
    | .error e => IO.eprintln e; IO.eprint usage; return 252
    | .ok o =>
      if o.moduleName.isNone || o.ns.isNone then
        IO.eprintln "--module-name and --namespace are required"; return 252
      try runGenerate o
      catch e => IO.eprintln s!"error: {e}"; return 254
  | _ => IO.eprint usage; return 252
