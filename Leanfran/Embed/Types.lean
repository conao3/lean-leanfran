import Lean.Data.Json

open Lean System

namespace Leanfran.Embed

inductive ColumnUnit where
  | byte
  | utf16
  | codePoint
  deriving BEq, Inhabited

structure Context where
  lang : String
  root : FilePath
  dir : FilePath
  state : FilePath
  workspace : FilePath
  app : FilePath
  lake : String
  verbose : Bool
  deriving Inhabited

structure Failure where
  code : UInt32
  message : String
  deriving Inhabited

def Failure.content (message : String) : Failure := {code := 254, message}

def Failure.environment (message : String) : Failure := {code := 255, message}

def sha256 (text : String) : IO String := do
  let args : IO.Process.SpawnArgs := if Platform.isOSX then
    {cmd := "shasum", args := #["-a", "256"]}
  else {cmd := "sha256sum"}
  let output ← IO.Process.run args (some text)
  return (output.splitOn " ").head!

private def field? [FromJson α] (j : Json) (key : String) : Except String (Option α) :=
  match j.getObjVal? key with
  | .ok .null => pure none
  | .ok value => some <$> fromJson? value
  | .error _ => pure none

private def fieldD [FromJson α] (j : Json) (key : String) (default : α) : Except String α :=
  return (← field? j key).getD default

private def withOptional (fields : List (String × Json)) (optional : List (String × Option Json)) : Json :=
  Json.mkObj (fields ++ optional.filterMap fun (key, value) => value.map (key, ·))

structure Origin where
  file : String
  line : Nat
  column : Nat
  deriving FromJson, ToJson, Inhabited, BEq

structure SourceError where
  file : String
  line : Nat
  column : Nat
  message : String
  deriving FromJson, ToJson, Inhabited

structure MapEntry where
  offset : Nat
  line : Nat
  column : Nat
  deriving Inhabited

instance : ToJson MapEntry where
  toJson e := Json.arr #[toJson e.offset, toJson e.line, toJson e.column]

instance : FromJson MapEntry where
  fromJson? j := do
    let #[offset, line, column] ← j.getArr? | throw "expected [offset, line, column]"
    return {offset := ← fromJson? offset, line := ← fromJson? line, column := ← fromJson? column}

inductive Output where
  | dir (path : String)
  | file (path : String)
  deriving Inhabited

instance : ToJson Output where
  toJson
    | .dir path => Json.mkObj [("dir", toJson path)]
    | .file path => Json.mkObj [("file", toJson path)]

instance : FromJson Output where
  fromJson? j := do
    if let some path ← field? j "dir" then return .dir path
    if let some path ← field? j "file" then return .file path
    throw "expected {\"dir\": ...} or {\"file\": ...}"

def Output.dirPath : Output → String
  | .dir path => path
  | .file path => match (FilePath.mk path).parent with
    | some parent => parent.toString
    | none => "."

structure Block where
  name : String
  module : String
  path : String
  prelude : String
  text : String
  postlude : String
  map : Array MapEntry
  origin : Origin
  uses : Array String
  hash : String
  job : Json
  output : Output
  deriving FromJson, ToJson, Inhabited

structure WorkspaceFile where
  path : String
  text : String
  origin : Option Origin := none
  deriving Inhabited

instance : ToJson WorkspaceFile where
  toJson f := withOptional [("path", toJson f.path), ("text", toJson f.text)] [("origin", f.origin.map toJson)]

instance : FromJson WorkspaceFile where
  fromJson? j := return {
    path := ← j.getObjValAs? String "path", text := ← j.getObjValAs? String "text", origin := ← field? j "origin"}

structure ProjectFile where
  path : String
  text : String := ""
  block : Option String := none
  source : Option FilePath := none
  deriving Inhabited

instance : ToJson ProjectFile where
  toJson f := withOptional [("path", toJson f.path), ("text", toJson f.text)] [("block", f.block.map toJson)]

instance : FromJson ProjectFile where
  fromJson? j := return {
    path := ← j.getObjValAs? String "path", text := ← j.getObjValAs? String "text", block := ← field? j "block"}

structure Function where
  id : String
  labels : Array String
  hash : String
  origin : Origin
  data : Json := Json.mkObj []
  deriving Inhabited

instance : ToJson Function where
  toJson f := Json.mkObj [("id", toJson f.id), ("labels", toJson f.labels), ("hash", toJson f.hash),
    ("origin", toJson f.origin), ("data", f.data)]

instance : FromJson Function where
  fromJson? j := return {
    id := ← j.getObjValAs? String "id", labels := ← j.getObjValAs? (Array String) "labels"
    hash := ← j.getObjValAs? String "hash", origin := ← j.getObjValAs? Origin "origin"
    data := ← fieldD j "data" (Json.mkObj [])}

structure Scan where
  scope : Array String := #["."]
  require : Array Json := #[]
  inputs : String := ""
  blocks : Array Block := #[]
  workspace : Array WorkspaceFile := #[]
  files : Array ProjectFile := #[]
  stray : Array String := #[]
  functions : Array Function := #[]
  functionsError : Option SourceError := none
  proofInputs : String := ""
  deriving Inhabited

instance : ToJson Scan where
  toJson s := withOptional [("format", toJson (1 : Nat)), ("scope", toJson s.scope), ("require", toJson s.require),
    ("inputs", toJson s.inputs), ("blocks", toJson s.blocks), ("workspace", toJson s.workspace),
    ("files", toJson s.files), ("stray", toJson s.stray), ("functions", toJson s.functions),
    ("proof_inputs", toJson s.proofInputs)] [("functions_error", s.functionsError.map toJson)]

instance : FromJson Scan where
  fromJson? j := do
    unless (← j.getObjValAs? Nat "format") == 1 do throw "expected format 1"
    return {
      scope := ← j.getObjValAs? (Array String) "scope", require := ← j.getObjValAs? (Array Json) "require"
      inputs := ← j.getObjValAs? String "inputs", blocks := ← j.getObjValAs? (Array Block) "blocks"
      workspace := ← j.getObjValAs? (Array WorkspaceFile) "workspace"
      files := ← j.getObjValAs? (Array ProjectFile) "files", stray := ← j.getObjValAs? (Array String) "stray"
      functions := ← j.getObjValAs? (Array Function) "functions"
      functionsError := ← field? j "functions_error"
      proofInputs := ← j.getObjValAs? String "proof_inputs"}

structure Generated where
  block : String
  stage : FilePath
  files : Array String
  summary : Json := Json.mkObj []
  deriving Inhabited

abbrev Summaries := Array (String × Json)

structure TranslateBlock where
  module : String
  files : Array String
  summary : Json
  deriving ToJson, FromJson

structure TranslateInput where
  workspace : FilePath
  scan : Scan
  blocks : Array (String × TranslateBlock)
  deriving Inhabited

instance : ToJson TranslateInput where
  toJson i := Json.mkObj [("format", toJson (1 : Nat)), ("workspace", toJson i.workspace.toString),
    ("scan", toJson i.scan), ("blocks", Json.mkObj (i.blocks.toList.map fun (name, b) => (name, toJson b)))]

structure ModelModule where
  module : String
  path : String
  text : String
  functions : Array String := #[]
  deriving Inhabited

instance : ToJson ModelModule where
  toJson m := Json.mkObj [("module", toJson m.module), ("path", toJson m.path), ("text", toJson m.text),
    ("functions", toJson m.functions)]

instance : FromJson ModelModule where
  fromJson? j := return {
    module := ← j.getObjValAs? String "module", path := ← j.getObjValAs? String "path"
    text := ← j.getObjValAs? String "text", functions := ← fieldD j "functions" #[]}

structure TranslatedFunction where
  id : String
  model : String
  dependencies : Array String := #[]
  error : Option SourceError := none
  data : Json := Json.mkObj []
  deriving Inhabited

instance : FromJson TranslatedFunction where
  fromJson? j := return {
    id := ← j.getObjValAs? String "id", model := ← j.getObjValAs? String "model"
    dependencies := ← fieldD j "dependencies" #[], error := ← field? j "error"
    data := ← fieldD j "data" (Json.mkObj [])}

structure Translation where
  modules : Array ModelModule := #[]
  aggregates : Array ModelModule := #[]
  functions : Array TranslatedFunction := #[]
  deriving Inhabited

instance : FromJson Translation where
  fromJson? j := do
    unless (← j.getObjValAs? Nat "format") == 1 do throw "expected format 1"
    return {
      modules := ← j.getObjValAs? (Array ModelModule) "modules"
      aggregates := ← j.getObjValAs? (Array ModelModule) "aggregates"
      functions := ← j.getObjValAs? (Array TranslatedFunction) "functions"}

structure LockObligation where
  label : String
  status : String
  detail : String := ""
  axioms : Array String := #[]
  file : String := ""
  line : Nat := 0
  deriving Inhabited, BEq

structure LockFunction where
  id : String
  hash : String
  model : String
  dependencies : Array String := #[]
  obligations : Array LockObligation := #[]
  data : Json := Json.mkObj []
  deriving Inhabited

structure LockInputs where
  compiler : String := ""
  library : String := ""
  host : String := ""
  proofs : String := ""
  deriving Inhabited, BEq

structure LockSection where
  inputs : LockInputs := {}
  functions : Array LockFunction := #[]
  deriving Inhabited

inductive Doc where
  | json (value : Json)
  | arr (items : Array Doc)
  | obj (fields : List (String × Doc))
  deriving Inhabited

private def quote (text : String) : String := (Json.str text).compress

def objFields : Json → Array (String × Json)
  | .obj fields => fields.foldl (init := #[]) fun acc k v => acc.push (k, v)
  | _ => #[]

partial def Doc.ofJson : Json → Doc
  | .arr items => .arr (items.map Doc.ofJson)
  | .obj fields => .obj ((objFields (.obj fields)).toList.map fun (k, v) => (k, Doc.ofJson v))
  | value => .json value

partial def Doc.render (doc : Doc) (indent : String := "") : String :=
  let inner := indent ++ "  "
  match doc with
  | .json (.arr items) => Doc.render (.arr (items.map Doc.ofJson)) indent
  | .json (.obj fields) => Doc.render (Doc.ofJson (.obj fields)) indent
  | .json value => value.compress
  | .arr items =>
    let scalar := items.all fun
      | .json (.arr _) | .json (.obj _) | .arr _ | .obj _ => false
      | .json _ => true
    if items.isEmpty then "[]"
    else if scalar then "[" ++ ", ".intercalate (items.toList.map (·.render inner)) ++ "]"
    else "[\n" ++ ",\n".intercalate (items.toList.map fun item => inner ++ item.render inner) ++ "\n" ++ indent ++ "]"
  | .obj fields =>
    if fields.isEmpty then "{}"
    else "{\n" ++ ",\n".intercalate (fields.map fun (k, v) => s!"{inner}{quote k}: {v.render inner}") ++
      "\n" ++ indent ++ "}"

def writeChanged (path : FilePath) (text : String) : IO Bool := do
  if (← (IO.FS.readFile path).toBaseIO).toOption == some text then return false
  if let some parent := path.parent then IO.FS.createDirAll parent
  IO.FS.writeFile path text
  return true

def relativeTo (base path : FilePath) : Option String :=
  if path == base then some "."
  else
    let pre := base.toString ++ "/"
    if path.toString.startsWith pre then some (path.toString.drop pre.length).toString else none

def display (root : FilePath) (file : String) : IO String := do
  let path := if (FilePath.mk file).isAbsolute then FilePath.mk file else root / file
  let cwd ← IO.currentDir
  let cwd := (← (IO.FS.realPath cwd).toBaseIO).toOption.getD cwd
  return (relativeTo cwd path).getD path.toString

def inScope (scope : Array String) (path : String) : Bool :=
  scope.any fun s => s == "." || path == s || path.startsWith (s ++ "/")

end Leanfran.Embed
