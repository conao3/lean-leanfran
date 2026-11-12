import Std.Data.HashMap
namespace counts

open Std in
def tally (words : List String) : List (String × Nat) :=
  let m : HashMap String Nat := words.foldl (fun m w => m.insert w (m.getD w 0 + 1)) {}
  (m.toList.mergeSort (fun a b => a.1 < b.1 || (a.1 == b.1 && a.2 ≤ b.2)))

end counts
