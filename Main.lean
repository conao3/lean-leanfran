import LeanRust.Cli
import LeanPython.Cli
import LeanTs.Cli
import LeanClj.Cli
import LeanPhp.Cli
import LeanGo.Cli
import LeanC.Cli

def usage : String := "usage: leanfran --lang <rust|python|typescript|clojure|php|go|c> <command> [parameters]
       leanfran --version

--lang selects the language to generate. `leanfran --lang <language>` without a command prints
the commands of that language."

def takeLang : List String → Option (String × List String)
  | [] => none
  | "--lang" :: lang :: rest => some (lang, rest)
  | arg :: rest => (takeLang rest).map fun (lang, rest) => (lang, arg :: rest)

unsafe def main (args : List String) : IO UInt32 := do
  if args == ["--version"] then
    IO.println s!"leanfran {LeanRust.Cli.version}"
    return 0
  let some (lang, rest) := takeLang args
    | IO.eprintln usage; return 252
  match lang with
  | "rust" => LeanRust.Cli.main rest
  | "python" => LeanPython.Cli.main rest
  | "typescript" => LeanTs.Cli.main rest
  | "clojure" => LeanClj.Cli.main rest
  | "php" => LeanPhp.Cli.main rest
  | "go" => LeanGo.Cli.main rest
  | "c" => LeanC.Cli.main rest
  | _ => IO.eprintln s!"leanfran: unknown --lang '{lang}'\n{usage}"; return 252
