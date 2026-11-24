def main (args : List String) : IO UInt32 := do
  match args with
  | [name] =>
    IO.println s!"Hello, {name}!"
    return 0
  | _ =>
    IO.eprintln "usage: greet-cli NAME"
    return 2
