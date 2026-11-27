import LeanC.Cli

unsafe def main (args : List String) : IO UInt32 :=
  LeanC.Cli.main (match args with | "--lang" :: "c" :: rest => rest | _ => args)
