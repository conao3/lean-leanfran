import Leanfran.Embed

open Lean System Leanfran.Embed

namespace LeanGo.Embed

def tool : String := "github.com/conao3/leanfran-go/cmd/leanfran-go"

def goLibSource : String := include_str "../lean/LeanGoLib/Go.lean"

def lakefile : String :=
  "name = \"leanfran-go-workspace\"\n" ++
  "defaultTargets = [\"LeanGoEmbed\", \"LeanGoModels\"]\n" ++
  "\n[[lean_lib]]\nname = \"LeanGoEmbed\"\n" ++
  "\n[[lean_lib]]\nname = \"LeanGoModels\"\n" ++
  "\n[[lean_lib]]\nname = \"LeanGoLib\"\n" ++
  "\n[[lean_lib]]\nname = \"LeanGoModel\"\nsrcDir = \"verification\"\n" ++
  "\n[[lean_lib]]\nname = \"Proofs\"\nsrcDir = \"verification\"\n"

def launch : Host.Launch := fun ctx => do
  let install := s!"in your Go project, run `go get -tool {tool}` with the Go module version that matches this compiler"
  match ← (IO.Process.output {cmd := "go", args := #["tool", "-n", tool], cwd := some ctx.root}).toBaseIO with
  | .error error => return .error (.environment s!"leanfran --lang go: could not run Go ({error}); put Go on PATH, then {install}")
  | .ok out =>
    unless out.exitCode == 0 do
      return .error (.environment s!"{out.stderr}leanfran --lang go: could not load the leanfran-go module tool; {install}")
    return .ok ("go", #["tool", tool])

partial def findModule (dir : FilePath) : IO (Option FilePath) := do
  if ← (dir / "go.mod").pathExists then return some dir
  match dir.parent with
  | some parent => if parent == dir then return none else findModule parent
  | none => return none

def projectRoot (dir : FilePath) : IO (Except Failure FilePath) := do
  let start ← match ← (IO.FS.realPath dir).toBaseIO with
    | .ok start => pure start
    | .error error => return .error (.content s!"{dir}: {error}")
  match ← findModule start with
  | some root => return .ok root
  | none => return .error (.content s!"{start} is outside a Go module; run leanfran --lang go in a directory with go.mod")

def goQuote (text : String) : String :=
  "\"" ++ String.join (text.toList.map fun
    | '"' => "\\\""
    | '\\' => "\\\\"
    | '\n' => "\\n"
    | '\t' => "\\t"
    | '\r' => "\\r"
    | c => c.toString) ++ "\""

def gofmt (source : String) : IO (Except Failure String) := do
  let child ← match ← (IO.Process.spawn {cmd := "gofmt", stdin := .piped, stdout := .piped, stderr := .piped}).toBaseIO with
    | .ok child => pure child
    | .error error => return .error (.environment s!"could not run gofmt: {error}")
  let (stdin, child) ← child.takeStdin
  stdin.putStr source
  stdin.flush
  let stdout ← IO.asTask child.stdout.readToEnd Task.Priority.dedicated
  let stderr ← child.stderr.readToEnd
  let stdout ← IO.ofExcept stdout.get
  unless (← child.wait) == 0 do return .error (.environment s!"gofmt: {stderr}")
  return .ok stdout

structure Model where
  id : String
  dir : String
  package : String
  function : String
  spec : String
  requires : String
  checks : Array (String × String)
  valid : Bool
  deriving Inhabited

def Model.path (m : Model) : String := (m.id.dropEnd (m.function.length + 1)).toString

def Model.ofFunction (f : Function) : Except String Model := do
  let d := f.data
  let checks ← (← d.getObjValAs? (Array (Array String)) "checks").mapM fun
    | #[label, name] => pure (label, name)
    | _ => throw "expected [label, name]"
  return {
    id := f.id, dir := ← d.getObjValAs? String "dir", package := ← d.getObjValAs? String "package"
    function := ← d.getObjValAs? String "function", spec := ← d.getObjValAs? String "spec"
    requires := (d.getObjValAs? String "requires").toOption.getD "", checks
    valid := !(d.getObjVal? "error").toBool}

def testSource (pkg : String) (models : Array Model) (summaries : Summaries) : String := Id.run do
  let mut imports : Array (String × String) := #[]
  let mut cases := ""
  let mut testerNeeded := false
  for m in models do
    let summary := ((summaries.find? (·.1 == m.spec)).map (·.2)).getD Json.null
    let wrapper := fun (name : String) => ((summary.getObjValD "functions").getObjValAs? String name).toOption.getD ""
    let names := (if m.requires.isEmpty then #[] else #[m.requires]) ++ m.checks.map (·.2)
    let missing := names.find? (wrapper · == "")
    let specPackage := (summary.getObjValAs? String "package").toOption.getD ""
    cases := cases ++ s!"\tt.Run({goQuote m.function}, func(t *testing.T) \{\n"
    if let some missing := missing then
      cases := cases ++ s!"\t\tt.Fatal({goQuote s!"no generated Go function for Lean spec {m.spec}:{missing}"})\n"
    else if specPackage == "main" && m.path != m.spec then
      cases := cases ++ s!"\t\tt.Fatal({goQuote s!"cannot import spec from command package {m.spec}"})\n"
    else
      testerNeeded := true
      let mut pre := ""
      if m.path != m.spec then
        let alias ← match imports.find? (·.1 == m.spec) with
          | some (_, alias) => pure alias
          | none =>
            let alias := s!"spec{imports.size}"
            imports := imports.push (m.spec, alias)
            pure alias
        pre := alias ++ "."
      cases := cases ++ s!"\t\tleanfrantest.Check(t, leanfrantest.Model\{Name: {goQuote m.function}, Function: {m.function},\n"
      unless m.requires.isEmpty do
        cases := cases ++ s!"\t\t\tRequires: {pre}{wrapper m.requires},\n"
      for (label, name) in m.checks do
        if label == "refines" then cases := cases ++ s!"\t\t\tRefines: {pre}{wrapper name},\n"
      let ensures := m.checks.filter (·.1 != "refines")
      unless ensures.isEmpty do
        cases := cases ++ "\t\t\tEnsures: map[string]any{\n"
        for (label, name) in ensures do
          cases := cases ++ s!"\t\t\t\t{goQuote label}: {pre}{wrapper name},\n"
        cases := cases ++ "\t\t\t},\n"
      cases := cases ++ "\t\t})\n"
    cases := cases ++ "\t})\n"
  let mut source := s!"// Code generated by leanfran-go model tests. DO NOT EDIT.\n\npackage {pkg}\n\nimport (\n\t\"testing\"\n"
  if testerNeeded then source := source ++ "\t\"github.com/conao3/leanfran-go/leanfrantest\"\n"
  for (path, alias) in imports.qsort (·.1 < ·.1) do
    source := source ++ s!"\t{alias} {goQuote path}\n"
  return source ++ s!")\n\nfunc TestLeanfranModels(t *testing.T) \{\n{cases}}\n"

def extraOutputs (_ : Context) (_ : Unit) (scan : Scan) (summaries : Summaries) :
    IO (Except Failure (Array ProjectFile)) := do
  let mut packages : Array (String × String × Array Model) := #[]
  for f in scan.functions do
    let m ← match Model.ofFunction f with
      | .ok m => pure m
      | .error message => return .error (.environment s!"{f.id}: invalid function data: {message}")
    unless m.valid && scan.blocks.any (·.name == m.spec) do continue
    match packages.findIdx? (·.1 == m.path) with
    | some i => packages := packages.modify i fun (path, dir, models) => (path, dir, models.push m)
    | none => packages := packages.push (m.path, m.dir, #[m])
  let mut files := #[]
  for (_, dir, models) in packages do
    let pkg := models[0]!.package
    let text ← match ← gofmt (testSource pkg models summaries) with
      | .ok text => pure text
      | .error failure => return .error failure
    let path := if dir == "." then "leanfran_model_test.go" else s!"{dir}/leanfran_model_test.go"
    files := files.push {path, text}
  return .ok files

def backend (version generatorVersion : String) : Backend := {
  lang := "go", version, generatorVersion, dirOption := "--dir", dirRequired := false, State := Unit
  root := projectRoot
  scan := Host.scan launch version generatorVersion
  translate := Host.translate launch version generatorVersion
  lakefile, supportFiles := #[{path := "LeanGoLib/Go.lean", text := goLibSource}]
  ownedDirs := #["LeanGoEmbed"], verificationDir := "verification"
  generatedHeaders := #["// Code generated by leanfran-go (generator ", "// Code generated by leanfran-go model tests. DO NOT EDIT."]
  columnUnit := .byte, job := Batch.withOutput, generateArgs := #[]
  generate := fun ctx _ _ blocks => Batch.run Batch.withOutput #[] ctx blocks
  supportModules := fun _ _ => #[], extraOutputs}

end LeanGo.Embed
