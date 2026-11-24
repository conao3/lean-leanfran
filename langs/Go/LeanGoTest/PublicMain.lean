import LeanGoTest.Public
import LeanGoTest.Json

def main : IO Unit := do
  IO.println (LeanGoTest.Public.total [1200, 800] (.percent 10 (by decide)))
  for line in LeanGoTest.Json.lines do
    IO.println line
