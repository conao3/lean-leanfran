import Std.Data.HashSet
namespace dedup

def dedup (xs : List String) : List String := Id.run do
  let mut seen : Std.HashSet String := {}
  let mut out := #[]
  for x in xs do
    unless seen.contains x do
      seen := seen.insert x
      out := out.push x
  return out.toList

def duplicates (xs : List String) : List String := Id.run do
  let mut seen : Std.HashSet String := {}
  let mut dups : Std.HashSet String := {}
  for x in xs do
    if seen.contains x then dups := dups.insert x else seen := seen.insert x
  return xs.filter dups.contains |> dedup

end dedup
