import LeanGoModel.B666978747572652e746573742f7472616e736c617465

open LeanGoModel.B666978747572652e746573742f7472616e736c617465

def showPair (p : Int64 × Int64) : IO Unit :=
  IO.println s!"{p.1} {p.2}"

def main : IO Unit := do
  for n in [-1, 0, 1, 2, 3, 6, 9223372036854775807] do
    let (a, b, c) := Arithmetic n 2
    IO.println s!"{a} {b} {c}"
    showPair (Pair n)
    IO.println (Choose n)
    IO.println s!"{(Safe n 0).toOption.get!} {(Safe n 2).toOption.get!}"
    IO.println ((Steps n).toOption.get!)
  showPair ((Divide (-9223372036854775808) (-1)).toOption.get!)
  showPair ((Divide (-7) 3).toOption.get!)
  IO.println ((Divide 3 0).isOk == false)
  for s in [0, 7, 8, 256, 65535] do
    IO.println (Bits 131 s)
  IO.println (Sum #[4, -5, 7])
  IO.println (Bytes "aé" "🙂")
  IO.println (Compare ⟨"猫", 18⟩ "猫" 18)
  IO.println (Compare ⟨"猫", 18⟩ "猫" 19)
  IO.println ((Half (Float.ofBits 9223372036854775808)).toBits == 9223372036854775808)
  IO.println ((First #[-8]).toOption.get!)
  IO.println ((First #[]).isOk == false)
  let xs := (Change (-4)).toOption.get!
  showPair (xs[0]!, xs[1]!)
  IO.println s!"{(Positive 8).toOption.get!} <nil>"
  match Positive (-8) with
  | .error (.error message) => IO.println message
  | _ => IO.println "expected Go error"
  IO.println (WithCall 100)
  IO.println (Narrow (-257))
  IO.println s!"{TrySwitch 0} {TrySwitch 1} {TrySwitch (-1)}"
  IO.println s!"{Count (-1)} {Count 0} {Count 5}"
  IO.println ((Message 1).toOption.get!)
  IO.println ((Message 0).isOk == false)
  IO.println (ReadTagged ⟨0⟩)
  IO.println s!"{FlavorOk .plain} {FlavorOk .robust}"
