import LeanPhpTest.Public
import LeanPhpTest.Json

open LeanPhpTest.Public

def main (args : List String) : IO Unit := do
  if args == ["json"] then
    for line in LeanPhpTest.Json.lines do IO.println line
  else
    IO.println (total [1200, 800] (.percent 10 (by decide)))
    IO.println (total [42] (.fixed 19))
    IO.println (total [5, 3] .none)
    IO.println (rangeWidth ⟨1, 3, by decide⟩)
    IO.println (small ⟨9, by decide⟩)
    IO.println (← ioEcho "hello")
