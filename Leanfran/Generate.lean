import Lake.Toml.Load
import LeanRust.Cli
import LeanTs.Marshal
import LeanPhp.Marshal
import LeanClj.Cli

open Lean Lake System

namespace Leanfran.Generate

def usage : String := "usage: leanfran generate [--dir <dir>] [--output json|text]

Runs every [[generate]] table of leanfran.toml:

  --dir <dir>            Directory of leanfran.toml (default: the working directory)
  --output json|text     Format of the summary (default: text)

[[generate]]
  lang = \"rust\" | \"python\" | \"go\" | \"typescript\" | \"php\" | \"clojure\"
  lake-dir = \"<Lake package>\"
  out-dir = \"<directory of the generated code>\"
  path = \"<Rust module path, Python package, Go import path, PHP namespace, or Clojure namespace prefix (required for these languages)>\"
  modules = [\"<Module>\", \"<Module>.*\", { name = \"<Module>\", as = \"<name>\", bind = { \"<Namespace>\" = \"<path>\" } }]
  bind = { \"<Namespace>\" = \"<path>\" }   (not for clojure)

exit codes: 0 success, 252 invalid parameters or leanfran.toml, 254 input that cannot be converted, 255 other errors"

structure ModuleSpec where
  name : Name
  glob : Option Bool := none
  as? : Option String := none
  bind : Array (Name × String) := #[]

structure Entry where
  index : Nat
  lang : String
  lakeDir : FilePath
  outDir : FilePath
  path : String
  modules : Array ModuleSpec
  bind : Array (Name × String)

structure Module where
  name : Name
  output : String
  bind : Array (Name × String)

def languages : Array String := #["rust", "python", "go", "typescript", "php", "clojure"]

private def keyString : Name → String
  | .str .anonymous s => s
  | n => n.toString (escape := false)

private def string (table : Toml.Table) (key : Name) (required := true) : Except String (Option String) :=
  match table.find? key with
  | some (.string _ value) => pure (some value)
  | none => if required then throw s!"'{keyString key}' is required" else pure none
  | _ => throw s!"'{keyString key}' must be a string"

private def bindings (table : Toml.Table) (key : Name) : Except String (Array (Name × String)) :=
  match table.find? key with
  | none => pure #[]
  | some (.table _ t) => t.items.mapM fun
    | (ns, .string _ path) => pure ((keyString ns).toName, path)
    | (ns, _) => throw s!"'{keyString key}.\"{keyString ns}\"' must be a string"
  | _ => throw s!"'{keyString key}' must be a table"

private def known (table : Toml.Table) (keys : List Name) : Except String Unit :=
  for (key, _) in table.items do
    unless keys.contains key do throw s!"unknown key '{keyString key}'"

private def moduleSpec : Toml.Value → Except String ModuleSpec
  | .string _ value =>
    if value.endsWith ".*" then pure { name := (value.dropEnd 2).toString.toName, glob := some true }
    else if value.endsWith ".+" then pure { name := (value.dropEnd 2).toString.toName, glob := some false }
    else pure { name := value.toName }
  | .table _ t => do
    known t [`name, `as, `bind]
    let some name ← string t `name | throw "'name' is required"
    return { name := name.toName, as? := ← string t `as false, bind := ← bindings t `bind }
  | _ => throw "'modules' must contain module names or tables"

private def entry (root : FilePath) (index : Nat) : Toml.Value → Except String Entry
  | .table _ t => do
    known t [`lang, `«lake-dir», `«out-dir», `path, `modules, `bind]
    let some lang ← string t `lang | throw "'lang' is required"
    unless languages.contains lang do
      throw s!"'lang' must be one of {", ".intercalate languages.toList}, got '{lang}'"
    let some lakeDir ← string t `«lake-dir» | throw "'lake-dir' is required"
    let some outDir ← string t `«out-dir» | throw "'out-dir' is required"
    let path := (← string t `path (lang != "typescript")).getD ""
    let modules ← match t.find? `modules with
      | some (.array _ values) => values.mapM moduleSpec
      | _ => throw "'modules' must be an array"
    if modules.isEmpty then throw "'modules' is empty"
    let bind ← bindings t `bind
    if lang == "clojure" && (!bind.isEmpty || modules.any (!·.bind.isEmpty)) then
      throw "'bind' is not supported for clojure; generated namespaces pass values as maps"
    return { index, lang, lakeDir := root / lakeDir, outDir := root / outDir, path, modules, bind }
  | _ => throw "must be a table"

def readConfig (root : FilePath) : IO (Except String (Array Entry)) := do
  let path := root / "leanfran.toml"
  unless ← path.pathExists do return .error s!"{path} not found"
  let source ← IO.FS.readFile path
  let table ← match ← (Toml.loadToml (Parser.mkInputContext source path.toString)).toBaseIO with
    | .ok table => pure table
    | .error messages =>
      return .error ("".intercalate (← messages.toList.mapM (fun message => (message.toString : IO String)))).trimAscii.toString
  let values ← match table.find? `generate with
    | some (.array _ values) => pure values
    | none => return .error s!"{path} has no [[generate]] table"
    | _ => return .error s!"{path}: 'generate' must be an array of tables ([[generate]])"
  let mut entries := #[]
  for value in values, index in [1:values.size + 1] do
    match entry root index value with
    | .ok e => entries := entries.push e
    | .error message => return .error s!"{path}: [[generate]] {index}: {message}"
  return .ok entries

/-- Name of the generated code of a module in the language, unless the table names it with `as`. -/
def defaultOutput (lang : String) (module : Name) : String :=
  if lang == "go" then
    match module with
    | .str _ s => s.toLower
    | _ => module.toString
  else if lang == "typescript" then "/".intercalate (module.components.map LeanTs.componentString)
  else if lang == "php" then LeanPhp.componentString module
  else if lang == "clojure" then ".".intercalate (module.components.map fun c => LeanClj.kebab (c.toString (escape := false)))
  else LeanRust.Cli.rustModName module

/-- How the language names the generated code of a module of a table. -/
def target (lang path output : String) : String :=
  match lang with
  | "rust" => s!"{path}::{output}"
  | "python" => s!"{path}.{output}"
  | "php" => s!"{path}\\{output}"
  | "clojure" => s!"{path}.{output}"
  | _ => s!"{path}/{output}"

/-- Module bindings override table bindings. Longer namespaces come first. -/
def bindingsOf (e : Entry) (m : Module) : Array (Name × String) := Id.run do
  let mut out : Array (Name × String) := #[]
  for (ns, path) in e.bind ++ m.bind do
    out := (out.filter (·.1 != ns)).push (ns, path)
  return out.qsort fun a b =>
    if a.1.components.length == b.1.components.length then a.1.toString < b.1.toString
    else a.1.components.length > b.1.components.length

def job (e : Entry) (m : Module) : Json :=
  let bind := bindingsOf e m
  let path := target e.lang e.path m.output
  Json.mkObj <| [("module", toJson m.name.toString), ("type_group", toJson e.index)] ++ match e.lang with
  | "rust" => [
      ("rust_path", path), ("output_file", (e.outDir / s!"{m.output}.rs").toString),
      ("type_paths", Json.mkObj (bind.toList.map fun (ns, path) => (ns.toString, Json.str path)))]
  | "python" | "typescript" =>
    let outputFile := e.outDir / s!"{m.output}{if e.lang == "python" then ".py" else ".ts"}"
    (if e.lang == "python" then [("python_path", Json.str path)] else []) ++ [
      ("output_file", Json.str outputFile.toString),
      ("type_modules", Json.arr (bind.map fun (ns, path) =>
        Json.mkObj [("namespace", ns.toString), ("module", path)]))]
  | "php" => [
      ("php_namespace", path), ("facade", m.output), ("output_dir", (e.outDir / m.output).toString),
      ("type_modules", Json.arr (bind.map fun (ns, path) =>
        Json.mkObj [("namespace", ns.toString), ("php_namespace", path)]))]
  | _ => [
      ("go_path", path), ("package", m.output), ("output_dir", (e.outDir / m.output).toString),
      ("type_modules", Json.arr (bind.map fun (ns, path) => Json.str s!"{ns}={path}"))]

private def lakeOutput (lake : String) (args : Array String) (cwd : FilePath) : IO (Except String String) := do
  let out ← IO.Process.output { cmd := lake, args, cwd }
  if out.exitCode != 0 then
    return .error s!"{lake} {" ".intercalate args.toList} failed in {cwd} ({out.exitCode}):\n{out.stdout}{out.stderr}"
  return .ok out.stdout.trimAscii.toString

structure Package where
  searchPath : Array String
  sysroot : String
  built : Array Name

private def package (lake : String) (lakeDir : FilePath) (entries : Array Entry) : IO (Except String Package) := do
  unless ← lakeDir.isDir do return .error s!"not a directory: {lakeDir}"
  let specs := entries.flatMap (·.modules)
  let names := (specs.filter (·.glob.isNone)).map (·.name.toString)
  if specs.any (·.glob.isSome) then
    if let .error e ← lakeOutput lake #["build"] lakeDir then return .error e
  unless names.isEmpty do
    if let .error e ← lakeOutput lake (#["build"] ++ names.toList.eraseDups.toArray) lakeDir then return .error e
  let leanPath ← match ← lakeOutput lake #["env", "printenv", "LEAN_PATH"] lakeDir with
    | .ok s => pure s
    | .error e => return .error e
  let sysroot ← match ← lakeOutput lake #["env", "printenv", "LEAN_SYSROOT"] lakeDir with
    | .ok s => pure s
    | .error e => return .error e
  let lib := lakeDir / ".lake" / "build" / "lib" / "lean"
  let built ← if ← lib.isDir then LeanRust.Cli.oleanModules lib lib .anonymous else pure #[]
  return .ok { searchPath := ((leanPath.splitOn ":").filter (!·.isEmpty)).toArray, sysroot, built }

/-- Dot-separated segments that start with a letter and continue with letters, digits, `-` and `_`. -/
def cljNamespace (s : String) : Bool :=
  (s.splitOn ".").all fun seg => match seg.toList with
    | c :: cs => c.isAlpha && cs.all fun c => c.isAlphanum || c == '-' || c == '_'
    | [] => false

/-- The source file of the namespace of a module of a Clojure table, as `project generate` writes it. -/
def cljFile (e : Entry) (m : Module) : FilePath :=
  e.outDir / LeanClj.Cli.namespacePath (target e.lang e.path m.output)

private def expand (e : Entry) (built : Array Name) : Except String (Array Module) := do
  let mut out : Array Module := #[]
  for spec in e.modules do
    let names ← match spec.glob with
      | none => pure #[spec.name]
      | some self =>
        let found := (built.filter fun m => spec.name.isPrefixOf m && (self || m != spec.name)).qsort
          (·.toString < ·.toString)
        if found.isEmpty then throw s!"no module of {e.lakeDir} matches '{spec.name}'"
        pure found
    for name in names do
      if out.any (·.name == name) then throw s!"module '{name}' is listed twice"
      let output := spec.as?.getD (defaultOutput e.lang name)
      if e.lang == "php" && !LeanPhp.phpIdentifier output then
        throw s!"'{output}' is not a PHP identifier; supply a PHP identifier with 'as' for module '{name}'"
      if e.lang == "clojure" && !cljNamespace output then
        throw s!"'{output}' is not a Clojure namespace; supply one with 'as' for module '{name}'"
      out := out.push { name, output, bind := spec.bind }
  for m in out do
    let sameName (other : Module) :=
      if e.lang == "php" then other.output.toLower == m.output.toLower
      else if e.lang == "clojure" then cljFile e other == cljFile e m
      else other.output == m.output
    if (out.filter sameName).size > 1 then
      throw s!"two modules are generated as '{m.output}'; name one of them with 'as'"
  return out

structure Opts where
  dir : FilePath := "."
  output : String := "text"

private def parseOpts : List String → Opts → Except String Opts
  | [], o => pure o
  | "--dir" :: v :: rest, o => parseOpts rest { o with dir := v }
  | "--output" :: v :: rest, o =>
    if v == "json" || v == "text" then parseOpts rest { o with output := v }
    else throw s!"--output must be json or text, got '{v}'"
  | a :: _, _ => throw s!"unknown parameter: {a}"

private def fail (code : UInt32) (message : String) : IO UInt32 := do
  IO.eprintln s!"leanfran: {message}"
  return code

def main (args : List String) : IO UInt32 := do
  if args == ["--help"] || args == ["help"] then
    IO.println usage
    return 0
  let o ← match parseOpts args {} with
    | .ok o => pure o
    | .error e => return ← fail 252 e
  unless ← o.dir.isDir do return ← fail 252 s!"not a directory: {o.dir}"
  let root ← IO.FS.realPath o.dir
  let entries ← match ← readConfig root with
    | .ok entries => pure entries
    | .error e => return ← fail 252 e
  let lake := (← IO.getEnv "LAKE").getD "lake"
  let self ← IO.appPath
  let mut code : UInt32 := 0
  let mut summaries : Array Json := #[]
  let lakeDirs := (entries.map (·.lakeDir)).toList.eraseDups
  for lakeDir in lakeDirs do
    let mine := entries.filter (·.lakeDir == lakeDir)
    let pkg ← match ← package lake lakeDir mine with
      | .ok pkg => pure pkg
      | .error e => return ← fail 255 e
    for e in mine.filter (·.lang == "clojure") do
      let modules ← match expand e pkg.built with
        | .ok modules => pure modules
        | .error message => return ← fail 252 s!"[[generate]] {e.index}: {message}"
      for m in modules do
        let ns := target e.lang e.path m.output
        let file := cljFile e m
        let child ← IO.Process.output {
          cmd := self.toString
          args := #["--lang", "clojure", "module", "generate-namespace", "--module-name", m.name.toString,
            "--namespace", ns, "--output-file", file.toString, "--output", o.output, "--search-path"] ++ pkg.searchPath
          cwd := root
          env := #[("LEAN_SYSROOT", some pkg.sysroot)] }
        IO.eprint child.stderr
        code := max code child.exitCode
        if o.output == "json" then
          match Json.parse child.stdout with
          | .ok (.obj fields) =>
            summaries := summaries.push <| Json.mkObj ([("module", toJson m.name.toString), ("namespace", toJson ns)] ++
              fields.toArray.toList.map fun ⟨k, v⟩ => (k, v))
          | _ => IO.print child.stdout
        else if child.exitCode == 0 then
          IO.println s!"{m.name}: namespace {ns}\n  wrote {file}"
          for line in child.stdout.splitOn "\n" do
            unless line.isEmpty do IO.println s!"  {line}"
    for lang in languages.erase "clojure" do
      let mut jobs : Array Json := #[]
      let mut rustDirs : Array (FilePath × Array Module) := #[]
      for e in mine.filter (·.lang == lang) do
        let modules ← match expand e pkg.built with
          | .ok modules => pure modules
          | .error message => return ← fail 252 s!"[[generate]] {e.index}: {message}"
        IO.FS.createDirAll e.outDir
        jobs := jobs ++ modules.map (job e)
        if lang == "rust" then rustDirs := rustDirs.push (e.outDir, modules)
      if jobs.isEmpty then continue
      let status ← IO.FS.withTempDir fun tmp => do
        let batch := tmp / "batch.json"
        IO.FS.writeFile batch (Json.arr jobs).pretty
        let child ← IO.Process.output {
          cmd := self.toString
          args := #["--lang", lang, "module", "generate", "--batch", batch.toString, "--output", o.output,
            "--search-path"] ++ pkg.searchPath
          cwd := root
          env := #[("LEAN_SYSROOT", some pkg.sysroot)] }
        IO.eprint child.stderr
        pure (child.exitCode, child.stdout)
      if o.output == "json" then
        match Json.parse status.2 >>= (·.getArr?) with
        | .ok arr => summaries := summaries ++ arr
        | .error _ => IO.print status.2
      else IO.print status.2
      code := max code status.1
      for (dir, modules) in rustDirs do
        IO.FS.writeFile (dir / "mod.rs") (LeanRust.Cli.modRs (modules.map (·.output)))
  if o.output == "json" then IO.println (Json.arr summaries).compress
  return code

end Leanfran.Generate
