import LeanGoTest.Public
import LeanGoTest.Json
import LeanGoTest.Allocations

def main : IO Unit := do
  IO.println (LeanGoTest.Public.total [1200, 800] (.percent 10 (by decide)))
  for line in LeanGoTest.Json.lines do
    IO.println line
  for n in [0, 2^63 - 1, 2^63, 2^64 + 1] do
    IO.println (LeanGoTest.Allocations.natEcho n)
  for n in [-(2^63) - 1, -(2^63), -1, 0, 2^63 - 1, 2^63] do
    IO.println (LeanGoTest.Allocations.intEcho n)
