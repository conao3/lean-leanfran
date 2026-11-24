import Kernel

open Kernel

private def parseLine (line : String) : IO (Actor × Command) := do
  let [permission, tenant, op, arg] := line.trimAscii.toString.splitOn " "
    | throw (IO.userError s!"invalid command: {line}")
  let some tenant := tenant.toNat? | throw (IO.userError "invalid tenant")
  let some arg := arg.toNat? | throw (IO.userError "invalid argument")
  let command ← match op with
    | "read" => pure Command.read
    | "add" => pure (.add arg.toUInt64)
    | "set" => pure (.set arg.toUInt64)
    | "limit" => pure (.limit (some arg.toUInt64))
    | "unlimit" => pure (.limit none)
    | "pause" => pure .pause
    | _ => throw (IO.userError s!"invalid operation: {op}")
  return (⟨tenant.toUInt64, permission == "1"⟩, command)

def main : IO Unit := do
  let input ← IO.getStdin
  let output ← IO.getStdout
  let mut snapshot := initial 100
  repeat
    let line ← input.getLine
    if line.isEmpty then break
    let (actor, command) ← parseLine line
    match transition actor snapshot command with
    | .ok (writes, reply) =>
      snapshot := apply snapshot writes
      output.putStrLn s!"ok {reply}"
    | .error err => output.putStrLn s!"error {err.render}"
  output.putStrLn (renderSnapshot snapshot)
