import Leanfran.Embed.Types

open Lean System

namespace Leanfran.Embed.Host

abbrev Launch := Context → IO (Except Failure (String × Array String))

def environment (ctx : Context) (version generatorVersion : String) : Array (String × Option String) := #[
  ("LEANFRAN_CLI", some ctx.app.toString), ("LEANFRAN_VERSION", some version),
  ("LEANFRAN_GENERATOR_VERSION", some generatorVersion), ("LEANFRAN_LEAN_VERSION", some Lean.versionString),
  ("LEANFRAN_PYTHON_AUTO_SYNC", some "0"), ("LEANFRAN_TS_AUTO_SYNC", some "0"),
  ("PYTHONDONTWRITEBYTECODE", some "1")]

def call [FromJson α] (launch : Launch) (version generatorVersion : String) (ctx : Context) (command : String)
    (args : Array String) (input : Option String) : IO (Except Failure α) := do
  let (cmd, prefixArgs) ← match ← launch ctx with
    | .ok launch => pure launch
    | .error failure => return .error failure
  let spawned ← (IO.Process.spawn {
    cmd, args := prefixArgs ++ #[command] ++ args, cwd := some ctx.root
    env := environment ctx version generatorVersion
    stdin := .piped, stdout := .piped, stderr := .piped}).toBaseIO
  let child ← match spawned with
    | .ok child => pure child
    | .error error => return .error (.environment s!"could not start {cmd}: {error}")
  let (stdin, child) ← child.takeStdin
  stdin.putStr (input.getD "")
  stdin.flush
  let stdout ← IO.asTask child.stdout.readToEnd Task.Priority.dedicated
  let stderr ← child.stderr.readToEnd
  let stdout ← IO.ofExcept stdout.get
  let code ← child.wait
  let name := s!"{cmd} {command}"
  match code with
  | 0 =>
    match Json.parse stdout >>= fromJson? with
    | .ok value =>
      unless stderr.isEmpty do IO.eprint stderr
      return .ok value
    | .error message => return .error (.environment s!"{stderr}{name} printed output that leanfran cannot read: {message}")
  | 254 => return .error (.content stderr.trimAsciiEnd.toString)
  | 255 => return .error (.environment stderr.trimAsciiEnd.toString)
  | code => return .error (.environment s!"{stderr}{name} exited with {code}")

def scan (launch : Launch) (version generatorVersion : String) (ctx : Context) :
    IO (Except Failure (Scan × Unit)) := do
  return (·, ()) <$> (← call launch version generatorVersion ctx "scan"
    #["--root", ctx.root.toString, "--dir", ctx.dir.toString] none)

def translate (launch : Launch) (version generatorVersion : String) (ctx : Context) (_ : Unit)
    (input : TranslateInput) : IO (Except Failure Translation) :=
  call launch version generatorVersion ctx "translate" #["--root", ctx.root.toString] (some (toJson input).compress)

end Leanfran.Embed.Host
