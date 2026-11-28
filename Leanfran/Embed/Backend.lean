import Leanfran.Embed.Types

open Lean System

namespace Leanfran.Embed

structure Backend where
  lang : String
  version : String
  generatorVersion : String
  dirOption : String
  dirRequired : Bool
  State : Type
  root : FilePath → IO (Except Failure FilePath)
  scan : Context → IO (Except Failure (Scan × State))
  translate : Context → State → TranslateInput → IO (Except Failure Translation)
  lakefile : String
  supportFiles : Array WorkspaceFile
  ownedDirs : Array FilePath
  verificationDir : FilePath
  generatedHeaders : Array String
  columnUnit : ColumnUnit
  job : Block → FilePath → Json
  generateArgs : Array String
  generate : Context → State → Scan → Array Block → IO (Except Failure (Array Generated))
  supportModules : LockSection → Scan → Array WorkspaceFile
  extraOutputs : Context → State → Scan → Summaries → IO (Except Failure (Array ProjectFile))

def Backend.compiler (backend : Backend) : String :=
  s!"{backend.generatorVersion}/{Lean.versionString}"

end Leanfran.Embed
