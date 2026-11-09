
namespace LeanPythonEmbed.step07.code.m


def countLines (path : String) : IO Nat := do
  let s ← IO.FS.readFile path
  return (s.splitOn "\n").length - 1

def appendLine (path line : String) : IO Unit := do
  let h ← IO.FS.Handle.mk path .append
  h.putStrLn line

def runEcho (msg : String) : IO String := do
  let out ← IO.Process.output { cmd := "echo", args := #[msg] }
  return out.stdout.trimAsciiEnd.toString


end LeanPythonEmbed.step07.code.m
