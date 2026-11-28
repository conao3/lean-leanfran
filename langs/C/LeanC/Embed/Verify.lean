import LeanC.Verify.Translate
import LeanC.Embed.Scan
import Leanfran.Embed.Types

open Lean System
open LeanC.ClangAst
open LeanC.Verify (leanIdent)
open Leanfran.Embed (sha256)

namespace LeanC.Embed

def cLibSource : String := include_str "../../lean/LeanCLib/C.lean"
private def supportHeader := include_str "../../support/leanfran.h"

def releaseVersion : String :=
  ((supportHeader.splitOn "#define LEANFRAN_VERSION \"")[1]!.splitOn "\"").head!

def generatorVersion : String := "2"

structure ModelError where
  file : FilePath
  line : Nat
  column : Nat
  message : String

def ModelError.report (e : ModelError) (name : String) : String :=
  s!"{e.file}:{e.line}:{e.column}: unextracted {name}: {e.message}"

structure ModelCheck where
  label : String
  predicate : String

structure ModelFunction where
  name : String
  block : String
  file : FilePath
  line : Nat
  column : Nat
  requires : Option String := none
  checks : Array ModelCheck := #[]
  hash : String := ""
  error : Option ModelError := none
  closure : Array Verify.Function := #[]
  callees : Std.HashMap String (Array String) := {}
  declaration : Bool := false
  isStatic : Bool := false
  scope : String := ""
  home : String := ""
  fileScoped : Array String := #[]

def fileIdent (path : FilePath) : String :=
  "File_" ++ String.join (path.toString.toList.map fun c =>
    if c.isAlphanum then c.toString
    else match c with
      | '_' => "__"
      | '/' => "_s"
      | '.' => "_d"
      | '-' => "_h"
      | c => s!"_x{String.ofList (Nat.toDigits 16 c.toNat)}_")

def ModelFunction.model (m : ModelFunction) : String :=
  if m.block.isEmpty then s!"LeanCModel.{m.name}"
  else if m.scope.isEmpty then s!"LeanCModel.{m.block}.{m.name}"
  else s!"LeanCModel.{m.block}.{m.scope}.{m.name}"

def ModelFunction.labels (m : ModelFunction) : Array String :=
  if m.checks.isEmpty then #["model"] else m.checks.map (·.label)

def ModelFunction.id (m : ModelFunction) : String :=
  (m.model.drop "LeanCModel.".length).toString

private def annotation (attr : Node) : Option (Array String) := do
  guard (attr.kind == "AnnotateAttr")
  attr.children.mapM fun expr => do
    let literal ← expr.walk.find? (·.kind == "StringLiteral")
    let .ok (.str value) := Json.parse (literal.string "value") | none
    return value

private def annotations (node : Node) (kind : String) : Array (Array String) :=
  node.children.filterMap fun attr => do
    let args ← annotation attr
    guard (args[0]? == some kind)
    return args.extract 1 args.size

private partial def normalize : Json → Json
  | .obj fields => .obj <| fields.foldl (init := {}) fun acc key value =>
    if ["loc", "range", "isUsed", "isReferenced", "mangledName"].contains key then acc
    else match value with
      | .str text => if text.startsWith "0x" then acc else acc.insert key value
      | value => acc.insert key (normalize value)
  | .arr items => .arr (items.map normalize)
  | json => json

private def lineOf (source : ByteArray) (offset : Nat) : Nat :=
  1 + (source.extract 0 offset).data.countP (· == 10)

private def validLabel (label : String) : Bool :=
  cIdentifier label && label.toList.all (fun c => c.toNat < 128)

private def validName (name : String) : Bool :=
  !name.isEmpty && (name.splitOn ".").all validLabel

private def parseModel (args : Array String) : Except String (Option String × Option String × Array ModelCheck) := do
  let mut spec := none
  let mut requires := none
  let mut checks : Array ModelCheck := #[]
  for arg in args do
    let key :: rest := arg.splitOn "=" | throw s!"expected LF_MODEL(\"key=value\"), got '{arg}'"
    let value := "=".intercalate rest
    if rest.isEmpty || value.isEmpty then throw s!"expected LF_MODEL(\"key=value\"), got '{arg}'"
    match key with
    | "spec" =>
      if spec.isSome then throw "duplicate spec= in LF_MODEL"
      spec := some value
    | "requires" =>
      if requires.isSome then throw "duplicate requires= in LF_MODEL"
      unless validName value do throw s!"invalid Lean name '{value}' in requires="
      requires := some value
    | "refines" =>
      unless validName value do throw s!"invalid Lean name '{value}' in refines="
      checks := checks.push {label := "refines", predicate := value}
    | "ensures" =>
      let [label, predicate] := value.splitOn ":" | throw s!"expected ensures=<label>:<name>, got '{arg}'"
      unless validLabel label do throw s!"invalid ensures label '{label}'"
      unless validName predicate do throw s!"invalid Lean name '{predicate}' in ensures="
      checks := checks.push {label, predicate}
    | _ => throw s!"unknown LF_MODEL key '{key}'"
  if checks.isEmpty then throw "LF_MODEL requires refines= or ensures="
  for (check, i) in checks.zipIdx do
    if checks.extract 0 i |>.any (·.label == check.label) then
      throw s!"duplicate LF_MODEL obligation '{check.label}'"
  return (spec, requires, checks)

private def commandFor (db : Array CompileCommand) (config : Config) (root path : FilePath)
    (extra : Array String) : IO CompileCommand := do
  if let some command := db.find? (·.file == path) then return command
  if path.extension == some "h" then
    for candidate in db do
      if (← dependencies candidate extra).contains path then
        return {candidate with file := path}
  return {directory := root, file := path, flags := config.cflags}

private def blockClosure (blocks : Array Block) (name : String) : Array Block := Id.run do
  let mut pending := #[name]
  let mut seen : Std.HashSet String := {}
  let mut result := #[]
  while let some next := pending.back? do
    pending := pending.pop
    if seen.contains next then continue
    seen := seen.insert next
    let some block := blocks.find? (·.name == next) | continue
    result := result.push block
    pending := pending ++ block.imports
  return result.qsort (·.name < ·.name)

private partial def calleeClosure (byName : Std.HashMap String Node) (name : String)
    (seen : Std.HashSet String) : Std.HashSet String :=
  if seen.contains name then seen
  else
    let seen := seen.insert name
    match byName[name]? with
    | none => seen
    | some node => (Verify.callees node).foldl (init := seen) fun seen callee =>
      if byName.contains callee then calleeClosure byName callee seen else seen

private def discoverFile (root : FilePath) (command : CompileCommand) (extra : Array String)
    (blocks : Array Block) (modelSource : String) : IO (Array ModelFunction) := do
  let file := command.file
  let ast ← dump command extra
  let source ← IO.FS.readBinFile file
  let relative := FilePath.mk ((file.toString.drop (root.toString.length + 1)).toString)
  let defs := ast.children.filter fun n =>
    n.kind == "FunctionDecl" && n.children.any (·.kind == "CompoundStmt") &&
      absolute command.directory n.location.file == file
  let byName : Std.HashMap String Node := defs.foldl (init := {}) fun m n => m.insert (n.string "name") n
  let macros ← predefined command extra
  let target := Verify.targetProblem macros
  let float := Verify.floatProblem command.flags macros
  let output := Verify.translate ast file command.directory target float
  let translated : Std.HashMap String Verify.Function :=
    output.functions.foldl (init := {}) fun m fn => m.insert fn.name fn
  let records := ast.walk.filter fun n =>
    (n.kind == "RecordDecl" || n.kind == "EnumDecl") &&
      (!(annotations n "lean").isEmpty || !(annotations n "struct").isEmpty)
  let recordJson := records.map (normalize ·.json)
  let relativeTo := fun (path : FilePath) =>
    FilePath.mk ((path.toString.drop (root.toString.length + 1)).toString)
  let localBlocks := blocks.filter (·.file == relative)
  let mut result := #[]
  for node in defs do
    let attrs := annotations node "model"
    if attrs.isEmpty then continue
    let written := (node.children.find? fun attr => (annotation attr).any (·[0]? == some "model")).map
      fun attr => relativeTo (absolute command.directory attr.location.file)
    let localBlocks := blocks.filter (·.file == written.getD relative)
    let name := node.string "name"
    let line := lineOf source node.location.offset
    let column := node.location.column
    let base : ModelFunction := {
      name, block := "", file := relative, line, column, isStatic := node.string "storageClass" == "static"}
    let parsed : Except String _ := do
      if attrs.size != 1 then throw "expected one LF_MODEL on the function definition"
      let (spec, requires, checks) ← parseModel attrs[0]!
      let block ← match spec with
        | some spec =>
          unless blocks.any (·.name == spec) do throw s!"LF_MODEL refers to unknown Lean block '{spec}'"
          pure spec
        | none =>
          let #[block] := localBlocks | throw "LF_MODEL needs spec=<block> unless the file has exactly one Lean block"
          pure block.name
      return (block, requires, checks)
    let model ← match parsed with
      | .error message =>
        let home := match localBlocks with
          | #[block] => block.name
          | _ => ""
        pure {base with home, error := some {file := relative, line, column, message}}
      | .ok (block, requires, checks) =>
        let model := {base with block, requires, checks}
        match translated[name]? with
        | some _ =>
          let names := calleeClosure byName name {}
          let closure := output.functions.filter (names.contains ·.name)
          let callees := closure.foldl (init := {}) fun m fn =>
            m.insert fn.name ((byName[fn.name]?.map Verify.callees).getD #[] |>.filter (names.contains ·))
          pure {model with closure, callees}
        | none =>
          let reason := (output.unextracted.find? (·.1 == name)).map fun (_, problem) =>
            ({file := relative, line := lineOf source problem.location.offset
              column := problem.location.column, message := problem.reason} : ModelError)
          pure {model with error := some (reason.getD {file := relative, line, column, message := "not translated"})}
    let names := calleeClosure byName name {}
    let closureDefs := defs.filter (names.contains <| ·.string "name")
    let asts := closureDefs.map (normalize ·.json)
    let enumerators : Std.HashSet String := closureDefs.foldl (init := {}) fun acc fn =>
      fn.walk.foldl (init := acc) fun acc n => Id.run do
        let some decl := n.get? "referencedDecl" | return acc
        unless (decl.getObjValAs? String "kind").toOption == some "EnumConstantDecl" do return acc
        let some id := (decl.getObjValAs? String "id").toOption | return acc
        return acc.insert id
    let enumJson := ast.walk.filter (fun n => n.kind == "EnumDecl" &&
      n.children.any fun c => c.kind == "EnumConstantDecl" && enumerators.contains (c.string "id"))
      |>.map (normalize ·.json)
    let asts := asts ++ enumJson
    let specBlocks := if model.block.isEmpty then #[] else blockClosure blocks model.block
    let hash ← sha256 (Json.compress (Lean.toJson #[
      Json.str (Json.compress (Lean.toJson (attrs.map Lean.toJson))), Json.arr asts, Json.arr recordJson,
      Lean.toJson (specBlocks.map fun b => (b.name, b.imports, b.source)), Json.str modelSource,
      Lean.toJson target, Lean.toJson (float.filter fun _ => closureDefs.any Verify.usesDouble)]))
    result := result.push {model with hash}
  for node in ast.children do
    unless node.kind == "FunctionDecl" && !node.children.any (·.kind == "CompoundStmt") &&
        absolute command.directory node.location.file == file do continue
    let attrs := node.children.filterMap fun attr =>
      if (attr.get? "inherited") == some (.bool true) then none else annotation attr
    let attrs := attrs.filter (·[0]? == some "model")
    if attrs.isEmpty then continue
    let name := node.string "name"
    let line := lineOf source node.location.offset
    let checks := match parseModel (attrs[0]!.extract 1 attrs[0]!.size) with
      | .ok (_, _, checks) => checks
      | .error _ => #[]
    let block := match parseModel (attrs[0]!.extract 1 attrs[0]!.size) with
      | .ok (some spec, _, _) => spec
      | _ => (localBlocks[0]?.map (·.name)).getD ""
    let hash ← sha256 (Json.compress (Lean.toJson #[Lean.toJson name, Lean.toJson attrs]))
    let error : ModelError := {
      file := relative, line := line, column := node.location.column
      message := "LF_MODEL function has no definition in the configured sources"}
    result := result.push {
      name, block, file := relative, line, column := node.location.column, checks, hash, declaration := true
      error := some error }
  return result

def discoverModels (root : FilePath) (config : Config) (blocks : Array Block) (sources : Array FilePath)
    (modelSource : String) (headers : FilePath) : IO (Array ModelFunction) := do
  if sources.isEmpty then return #[]
  let clang ← (IO.Process.output {cmd := "clang", args := #["--version"]}).toBaseIO
  unless clang.toOption.any (·.exitCode == 0) do
    throw <| IO.userError s!"LF_MODEL requires clang on PATH"
  let db ← readDatabase root
  IO.FS.withTempDir fun tmp => do
    IO.FS.writeFile (tmp / "leanfran.h") supportHeader
    let extra := #["-I", tmp.toString, "-I", headers.toString]
    let mut paths := sources
    if sources.any (·.extension != some "c") then
      for path in ← sourceFiles root config do
        if path.extension == some "c" && !paths.contains path then paths := paths.push path
    let mut models := #[]
    for path in paths do
      let command ← commandFor db config root path extra
      models := models ++ (← discoverFile root command (extra ++ #["-x", "c"]) blocks modelSource)
    let defined := models.filter (!·.declaration) |>.map (·.name)
    let mut seen : Std.HashSet String := {}
    let mut result := #[]
    for m in models do
      if m.declaration then
        if defined.contains m.name || seen.contains m.name then continue
        seen := seen.insert m.name
      result := result.push m
    let mut files : Std.HashMap (String × String) (Array FilePath) := {}
    for m in result do
      if m.declaration || m.block.isEmpty then continue
      for name in (m.closure.map (·.name)).push m.name do
        let known := files[(m.block, name)]?.getD #[]
        unless known.contains m.file do files := files.insert (m.block, name) (known.push m.file)
    let clashes := fun (m : ModelFunction) (name : String) => (files[(m.block, name)]?.getD #[]).size > 1
    return result.map fun m =>
      if m.declaration || m.block.isEmpty then m
      else {m with
        scope := if clashes m m.name then fileIdent m.file else ""
        fileScoped := m.closure.map (·.name) |>.filter (clashes m ·)}

private def qualified (name : String) : String :=
  "_root_." ++ ".".intercalate ((name.splitOn ".").map leanIdent)

private def obligations (m : ModelFunction) (fn : Verify.Function) : String := Id.run do
  let params := fn.params.filterMap fun p =>
    match p.kind with
    | .value => some (p.lean, p.boundary)
    | .array _ boundary _ => some (p.lean, s!"Array {boundary}")
    | _ => none
  let args := String.join (params.toList.map (" " ++ ·.1))
  let binders := " ".intercalate (params.toList.map fun (n, t) => s!"({n} : {t})")
  let quantified := if params.isEmpty then "" else s!"∀ {binders}, "
  let sizes := String.join (fn.params.toList.filterMap fun p =>
    match p.kind, p.ty with
    | .length array, .int _ signed width => some s!"{array}.size < 2 ^ {if signed then width - 1 else width} → "
    | _, _ => none)
  let quantified := quantified ++ sizes
  let requires := match m.requires with
    | some name => s!"{qualified name}{args} = true → "
    | none => ""
  let call := s!"{fn.lean}{args}"
  let mut out := ""
  for check in m.checks do
    let predicate := qualified check.predicate
    let prop :=
      if check.label == "refines" then
        if fn.fallible then s!"{call} = Except.ok ({predicate}{args})" else s!"{call} = {predicate}{args}"
      else if fn.fallible then s!"∃ r, {call} = Except.ok r ∧ {predicate}{args} r = true"
      else s!"{predicate}{args} ({call}) = true"
    out := out ++ s!"abbrev {fn.lean}.obligation.{leanIdent check.label} : Prop :=\n  {quantified}{requires}{prop}\n"
  return out

private def modulePath (name : String) : String :=
  "/".intercalate (name.splitOn ".") ++ ".lean"

private def functionModule (m : ModelFunction) (name : String) : String :=
  s!"LeanCModel.{m.block}.{fileIdent m.file}.Fn_{name}"

def translation (models : Array ModelFunction) (hasModels : Bool) : Leanfran.Embed.Translation := Id.run do
  let mut modules : Array Leanfran.Embed.ModelModule := #[]
  let mut byBlock : Array (String × Array String) := #[]
  let addBlock := fun (byBlock : Array (String × Array String)) (block : String) (mod : Option String) =>
    if block.isEmpty then byBlock
    else match byBlock.findIdx? (·.1 == block) with
      | some i => byBlock.modify i fun (b, mods) =>
        (b, match mod with
          | some mod => if mods.contains mod then mods else mods.push mod
          | none => mods)
      | none => byBlock.push (block, match mod with | some mod => #[mod] | none => #[])
  let mut functions := #[]
  for m in models do
    functions := functions.push ({
      id := m.id, model := m.model
      error := m.error.map fun e => {file := e.file.toString, line := e.line, column := e.column, message := e.message}
      } : Leanfran.Embed.TranslatedFunction)
    if m.error.isSome then
      byBlock := addBlock byBlock (if m.block.isEmpty then m.home else m.block) none
      continue
    for fn in m.closure do
      let mod := functionModule m fn.name
      let callees := m.callees[fn.name]?.getD #[]
      let deps := callees.map (functionModule m)
      let imports := #["LeanCLib.C", Block.moduleName m.block] ++
        (if hasModels then #["LeanfranModels"] else #[]) ++ deps
      let blockNs := s!"LeanCModel.{leanIdent m.block}"
      let fileNs := s!"{blockNs}.{fileIdent m.file}"
      let ns := if m.fileScoped.contains fn.name then fileNs else blockNs
      let opens := if ns == blockNs && callees.any m.fileScoped.contains then s!"open {fileNs}\n\n" else ""
      let main := fn.name == m.name
      let checks := if main then obligations m fn else ""
      let text := String.join (imports.toList.map (s!"import {·}\n")) ++
        s!"\nnamespace {ns}\n\n{opens}{fn.source}\n{checks}\nend {ns}\n"
      let entry : Leanfran.Embed.ModelModule := {
        module := mod, path := modulePath mod, text, functions := if main then #[m.id] else #[]}
      match modules.findIdx? (·.module == mod) with
      | some i => if main then modules := modules.set! i entry
      | none => modules := modules.push entry
      byBlock := addBlock byBlock m.block (some mod)
  let aggregates := (byBlock.qsort (·.1 < ·.1)).map fun (block, mods) =>
    let mod := s!"LeanCModel.{block}"
    ({module := mod, path := modulePath mod, text := String.join (mods.toList.map (s!"import {·}\n"))} :
      Leanfran.Embed.ModelModule)
  return {modules, aggregates, functions}

end LeanC.Embed
